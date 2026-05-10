#!/usr/bin/env bash
# Question-to-Mastery intake hook
#
# Routes UserPromptSubmit prompts into the Question-to-Mastery flow:
#   +ask                 → launch pending inline question, or read clipboard/save/launch
#   +ask <body>          → save body, BLOCK original prompt, await bare +ask
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
PENDING_ASK_FILE="$CWD/.claude/hooks/.pending-ask"

derive_project_name() {
  local rel_path="$1"
  local derived source_path
  if [[ -f "$CWD/tools/derive-project-name.py" ]] && command -v python3 >/dev/null 2>&1; then
    source_path="$rel_path"
    if [[ "$source_path" != /* ]]; then
      source_path="$CWD/$source_path"
    fi
    derived=$(python3 "$CWD/tools/derive-project-name.py" "$source_path" 2>/dev/null || true)
    if [[ -n "$derived" ]]; then
      printf '%s' "$derived"
      return 0
    fi
  fi

  local base name
  base="${rel_path##*/}"
  name="${base%.md}"
  name="${name#question-source-}"
  name="${name#question-}"
  printf '%s' "$name"
}

emit_launch() {
  local rel_path="$1"
  jq -n --arg p "$rel_path" --arg cwd "$CWD" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: ("HARNESS_LAUNCH_TRIGGER\n学习问题路径：\($p)\n\n请严格按当前工作区 CLAUDE.md 执行：\n- 当前用户消息是 harness 触发器，不是普通问答请求；不要直接回答、总结或解决原始学习问题\n- 当前工作区：\($cwd)\n- 立即进入 Question-to-Mastery 编排流程；主 Agent 只初始化、调度、记录状态，不生产学习产物\n- 学习问题路径作为输入；handoff prompt 必须使用 §7 模板，严禁在 subagent prompt 中复述、改写或引用问题正文\n- 不得把输出目录设置为输入文件所在文件夹\n- 默认保持通用学习者视角；只有输入文件显式提供的背景、目标、场景和约束才能进入 learning-contract 与产物\n- 初始化后创建 README.md、_run/run-log.md、_run/events.jsonl、_run/state.json，由主 Agent 启动 Harness Visualizer 并记录 visualizer_started，然后启动 question-planner subagent")
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

  local rel project target
  rel="input/questions/question-$ts.md"
  project=$(derive_project_name "$rel")
  if [[ -n "$project" ]]; then
    target="$QUESTIONS_DIR/question-source-$project.md"
    if [[ "$target" != "$file" && ! -e "$target" ]]; then
      mv "$file" "$target"
      rel="input/questions/question-source-$project.md"
    fi
  fi

  printf '%s' "$rel"
}

mark_pending_ask() {
  local rel_path="$1"
  mkdir -p "${PENDING_ASK_FILE%/*}"
  printf '%s' "$rel_path" > "$PENDING_ASK_FILE"
}

consume_pending_ask() {
  local rel_path
  if [[ ! -f "$PENDING_ASK_FILE" ]]; then
    return 0
  fi

  rel_path=$(cat "$PENDING_ASK_FILE")
  rm -f "$PENDING_ASK_FILE"
  if [[ -n "$rel_path" && -f "$CWD/$rel_path" ]]; then
    printf '%s' "$rel_path"
  fi
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
#   no body    → launch pending inline question, or clipboard save + launch.
#   with body  → save + block. Inline body is visible to the main agent, so
#                the next bare +ask launches from the saved file.
# ---------------------------------------------------------------------------
if [[ "$PROMPT" =~ ^[+]ask([[:space:]:：]|$) ]]; then
  if [[ "$PROMPT" =~ ^[+]ask[:：]?[[:space:]]*$ ]]; then
    pending_rel=$(consume_pending_ask)
    if [[ -n "$pending_rel" ]]; then
      emit_launch "$pending_rel"
      exit 0
    fi

    if ! command -v pbpaste >/dev/null 2>&1; then
      emit_block "❌ 剪贴板模式需要 \`pbpaste\`（macOS）。请用 \`+ask <问题正文>\` 先保存，再发送 \`+ask\` 启动。"
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
  mark_pending_ask "$rel"
  emit_block "😊 提示：这是正常拦截。下次想一键启动，先复制问题正文，再只发送 \`+ask\`。

✅ 问题已保存：\`$rel\`

----
开始，请发送：\`+ask\`
----

"
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
