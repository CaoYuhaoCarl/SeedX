#!/usr/bin/env bash
# Question-to-Mastery intake hook
#
# Routes UserPromptSubmit prompts into the Question-to-Mastery flow:
#   +ask                 → read clipboard via pbpaste, save, launch (one-step strict)
#   +ask <body>          → save body, BLOCK original prompt, await +start
#   +ask:<body>          → same as +ask <body>
#   +ask：<body>         → same as +ask <body> (Chinese full-width colon)
#   +ask-strict <body>   → same as inline +ask body
#   +start [path]        → launch from given path, or most recent question file
#
# Anything else is passed through untouched.
#
# Note: '+' was chosen over '/' because Claude Code reserves '/' for slash
# commands and would intercept '/ask' before this hook fires. '[+]' in the
# regex patterns below is a literal-match char class (since '+' is an ERE
# quantifier).
#
# See CLAUDE.md §1.2 for the isolation contract this hook implements.

set -uo pipefail

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""')

if [[ -z "$CWD" ]]; then
  CWD="${CLAUDE_PROJECT_DIR:-$(pwd)}"
fi

QUESTIONS_DIR="$CWD/input/questions"

derive_project_name() {
  local rel_path="$1"
  local base name
  base="${rel_path##*/}"
  name="${base%.md}"
  name="${name#question-source-}"
  name="${name#question-}"
  printf '%s' "$name"
}

launch_visualizer() {
  local rel_path="$1"
  local project port
  project=$(derive_project_name "$rel_path")
  port="${Q2M_VISUALIZER_PORT:-8765}"

  if [[ "${Q2M_VISUALIZER_AUTO_OPEN:-1}" == "0" ]]; then
    return 0
  fi
  if [[ -z "$project" || ! -x "$CWD/tools/open-visualizer.sh" ]]; then
    return 0
  fi

  (
    "$CWD/tools/open-visualizer.sh" "$project" "$port" \
      > /tmp/q2m-harness-visualizer.log 2>&1 < /dev/null &
  ) || true
}

emit_launch() {
  local rel_path="$1"
  launch_visualizer "$rel_path"
  jq -n --arg p "$rel_path" --arg cwd "$CWD" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: ("HARNESS_LAUNCH_TRIGGER\n学习问题路径：\($p)\n\n请严格按当前工作区 CLAUDE.md 执行：\n- 当前用户消息是 harness 触发器，不是普通问答请求；不要直接回答、总结或解决原始学习问题\n- 当前工作区：\($cwd)\n- 立即进入 Question-to-Mastery 编排流程；主 Agent 只初始化、调度、记录状态，不生产学习产物\n- 学习问题路径作为输入；handoff prompt 必须使用 §7 模板，严禁在 subagent prompt 中复述、改写或引用问题正文\n- 不得把输出目录设置为输入文件所在文件夹\n- 默认保持通用学习者视角；只有输入文件显式提供的背景、目标、场景和约束才能进入 learning-contract 与产物\n- 初始化后创建 README.md、_run/run-log.md、_run/events.jsonl、_run/state.json，然后启动 question-planner subagent")
    }
  }'
}

emit_block() {
  local reason="$1"
  jq -n --arg r "$reason" '{decision:"block", reason:$r}'
}

save_body() {
  local body="$1"
  mkdir -p "$QUESTIONS_DIR"
  local ts
  ts=$(date +%y%m%d-%H%M%S)
  local file="$QUESTIONS_DIR/question-$ts.md"
  printf '%s\n' "$body" > "$file"
  printf '%s' "input/questions/question-$ts.md"
}

# Strip a literal prefix from PROMPT, plus following whitespace and/or colons.
# Accepts '+ask <body>', '+ask: <body>', '+ask:<body>', and '+ask：<body>'.
# perl \Q...\E escapes regex specials in prefix.
# Note: char class [\s:：] avoids '|' alternation which would clash with perl's
# s|...|...| delimiter.
strip_prefix() {
  local prefix="$1"
  printf '%s' "$PROMPT" | perl -0777 -pe "s|^\\Q${prefix}\\E[\\s:：]+||"
}

# ---------------------------------------------------------------------------
# +ask-strict <body>  — save then BLOCK; user must follow up with +start.
# ---------------------------------------------------------------------------
if [[ "$PROMPT" =~ ^[+]ask-strict([[:space:]:：]|$) ]]; then
  if [[ "$PROMPT" =~ ^[+]ask-strict[:：]?[[:space:]]*$ ]]; then
    emit_block "❌ \`+ask-strict\` 需要附带问题正文：\`+ask-strict <问题正文>\`"
    exit 0
  fi
  body=$(strip_prefix "+ask-strict")
  rel=$(save_body "$body")
  emit_block "✅ 问题已落盘到 \`$rel\`，原始消息已被 block，正文未进入主 Agent context。

下一步：发送 \`+start $rel\` 启动编排器。"
  exit 0
fi

# ---------------------------------------------------------------------------
# +ask [body]
#   no body    → clipboard mode: pbpaste + save + launch in the same turn.
#   with body  → save + block. Inline body is visible to the main agent, so
#                same-turn launch is deliberately disabled to avoid Q&A drift.
# ---------------------------------------------------------------------------
if [[ "$PROMPT" =~ ^[+]ask([[:space:]:：]|$) ]]; then
  if [[ "$PROMPT" =~ ^[+]ask[:：]?[[:space:]]*$ ]]; then
    if ! command -v pbpaste >/dev/null 2>&1; then
      emit_block "❌ 剪贴板模式需要 \`pbpaste\`（macOS）。请用 \`+ask <问题正文>\` 先落盘，再发送 \`+start\`。"
      exit 0
    fi
    body=$(pbpaste)
    if [[ -z "${body//[[:space:]]/}" ]]; then
      emit_block "❌ 剪贴板为空。请先复制问题正文，再发送 \`+ask\`。"
      exit 0
    fi
    rel=$(save_body "$body")
    emit_launch "$rel"
    exit 0
  else
    body=$(strip_prefix "+ask")
  fi
  rel=$(save_body "$body")
  emit_block "✅ 问题已落盘到 \`$rel\`。

为避免主 Agent 把 inline 正文当作普通问答直接回答，本消息已被 block。

下一步：发送 \`+start $rel\` 启动编排器。

想要一键启动：先复制问题正文到剪贴板，然后只发送 \`+ask\`。"
  exit 0
fi

# ---------------------------------------------------------------------------
# +start [path]  — explicit launch from given path or most recent
# ---------------------------------------------------------------------------
if [[ "$PROMPT" =~ ^[+]start([[:space:]:：]|$) ]]; then
  path_arg=""
  if [[ "$PROMPT" =~ ^[+]start[[:space:]:：]+(.+)$ ]]; then
    path_arg="${BASH_REMATCH[1]}"
    path_arg="${path_arg%"${path_arg##*[![:space:]]}"}"
  fi
  if [[ -z "$path_arg" ]]; then
    if [[ ! -d "$QUESTIONS_DIR" ]]; then
      emit_block "❌ 不存在 \`input/questions/\` 目录。先复制问题正文后发送 \`+ask\`，或用 \`+ask <body>\` 落盘问题。"
      exit 0
    fi
    latest=$(ls -t "$QUESTIONS_DIR"/*.md 2>/dev/null | head -1 || true)
    if [[ -z "$latest" ]]; then
      emit_block "❌ \`input/questions/\` 中没有问题文件。先复制问题正文后发送 \`+ask\`，或用 \`+ask <body>\` 落盘问题。"
      exit 0
    fi
    path_arg="${latest#$CWD/}"
  fi
  emit_launch "$path_arg"
  exit 0
fi

# Not a Q2M trigger — pass through unchanged.
exit 0
