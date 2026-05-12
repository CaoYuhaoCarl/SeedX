#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT_DIR/.claude/hooks/intake-question.sh"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/seedx-intake-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/input/questions" "$TEST_DIR/tools" "$TEST_DIR/.claude/hooks"
cp "$ROOT_DIR/tools/derive-project-name.py" "$TEST_DIR/tools/derive-project-name.py"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

run_hook() {
  local prompt="$1"
  jq -n --arg prompt "$prompt" --arg cwd "$TEST_DIR" '{prompt:$prompt,cwd:$cwd}' | "$HOOK"
}

assert_launch() {
  local prompt="$1"
  local body="$2"
  local output context rel_path saved

  output=$(run_hook "$prompt")
  context=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext // empty')
  [[ "$context" == *"HARNESS_LAUNCH_TRIGGER"* ]] || fail "expected launch for: $prompt"
  [[ "$context" != *"$body"* ]] || fail "launch context leaked body for: $prompt"

  rel_path=$(printf '%s' "$context" | awk -F'：' '/学习问题路径/ {print $2; exit}')
  [[ -n "$rel_path" ]] || fail "missing source path for: $prompt"
  [[ -f "$TEST_DIR/$rel_path" ]] || fail "source file not created for: $prompt"

  saved=$(cat "$TEST_DIR/$rel_path")
  [[ "$saved" == "$body" ]] || fail "saved body mismatch for: $prompt"
}

assert_block() {
  local prompt="$1"
  local output decision

  output=$(run_hook "$prompt")
  decision=$(printf '%s' "$output" | jq -r '.decision // empty')
  [[ "$decision" == "block" ]] || fail "expected block for: $prompt"
}

assert_pass_through() {
  local prompt="$1"
  local output

  output=$(run_hook "$prompt")
  [[ -z "$output" ]] || fail "expected pass-through for: $prompt"
}

assert_start_path() {
  local source_path="input/questions/existing-seedx-question.md"
  local output context

  printf 'existing body\n' > "$TEST_DIR/$source_path"
  output=$(run_hook "+start $source_path")
  context=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext // empty')
  [[ "$context" == *"HARNESS_LAUNCH_TRIGGER"* ]] || fail "expected +start launch"
  [[ "$context" == *"$source_path"* ]] || fail "expected +start source path"
}

assert_pending_ask_launch() {
  local body="pending ask body"
  local output context

  assert_block "+ask $body"
  output=$(run_hook "+ask")
  context=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext // empty')
  [[ "$context" == *"HARNESS_LAUNCH_TRIGGER"* ]] || fail "expected pending +ask launch"
  [[ "$context" != *"$body"* ]] || fail "pending +ask context leaked body"
}

assert_launch "qtm legacy body" "legacy body"
assert_launch "QTM uppercase legacy body" "uppercase legacy body"
assert_launch "用 qtm 调研问题：legacy natural body" "legacy natural body"
assert_launch "用 QTM 研究问题:legacy uppercase natural body" "legacy uppercase natural body"

assert_launch "seedx direct body" "direct body"
assert_launch "SeedX camel body" "camel body"
assert_launch "seedX mixed body" "mixed body"
assert_launch "Seedx variant body" "variant body"
assert_launch "SEEDX loud body" "loud body"
assert_launch "seed short body" "short body"
assert_launch "Seed title body" "title body"
assert_launch "SEED upper body" "upper body"
assert_launch "sx compact body" "compact body"
assert_launch "SX compact upper body" "compact upper body"
assert_launch "Sx compact title body" "compact title body"
assert_launch "sX compact mixed body" "compact mixed body"
assert_launch "用 seedx 调研问题：seedx natural body" "seedx natural body"
assert_launch "用 SeedX 研究问题:seedx title natural body" "seedx title natural body"
assert_launch "用 seed 学习问题：seed natural body" "seed natural body"
assert_launch "用 sx 分析问题：sx natural body" "sx natural body"

assert_block "+ask-strict strict body"
assert_block "+ask:inline body"
assert_block "+ask：fullwidth body"
assert_pending_ask_launch
assert_start_path

assert_pass_through "I want to discuss seedx naming"
assert_pass_through "How should I plant a seed for this project?"
assert_pass_through "This mentions sx in the middle"
assert_pass_through "qtm"
assert_pass_through "seedx"
assert_pass_through "seed"
assert_pass_through "sx"

printf 'PASS: intake trigger compatibility\n'
