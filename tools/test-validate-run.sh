#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VALIDATOR="$ROOT_DIR/tools/validate-run.py"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/seedx-validate-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- Fixture 1: a clean run that should pass ---------------------------------
GOOD="$TEST_DIR/good/_run"
mkdir -p "$GOOD"
cat > "$GOOD/state.json" <<'JSON'
{
  "project": "smoke-260514-000000",
  "source": "input/q.md",
  "output": "output/smoke-260514-000000",
  "phase": "task_loop",
  "current_task": "task02",
  "updated_at": "260514 000000",
  "tasks": {
    "task01": {"title":"Framing","status":"✅","builder_id":"abc","evaluator_id":"def","iterations":1,"judgment":"PASS","outputs":["deliverables/question-brief.md"],"report":"_agent/review-reports/task01-evaluation.md"},
    "task02": {"title":"Mastery Path","status":"✏️","builder_id":"ghi","evaluator_id":null,"iterations":0,"judgment":null,"outputs":["deliverables/learning-path.md"],"report":"_agent/review-reports/task02-evaluation.md"},
    "task03": {"title":"Application & Transfer","status":"📋","builder_id":null,"evaluator_id":null,"iterations":0,"judgment":null,"outputs":["deliverables/application-plan.md"],"report":"_agent/review-reports/task03-evaluation.md"}
  },
  "discipline": {
    "main_read_source_body": false,
    "main_read_builder_deliverables": false,
    "main_read_full_evaluation_reports": false,
    "same_task_builder_resume_required": true,
    "same_task_evaluator_resume_required": true,
    "personalization_source": "explicit_input_only"
  }
}
JSON
cat > "$GOOD/events.jsonl" <<'JSONL'
{"ts":"260514 000000","type":"project_started","project":"smoke-260514-000000","source":"input/q.md","output":"output/smoke-260514-000000"}
{"ts":"260514 000010","type":"agent_started","role":"question-planner","task":"planning"}
{"ts":"260514 000100","type":"agent_finished","role":"question-planner","task":"planning","outputs":["_agent/learning-plan.md"]}
{"ts":"260514 000200","type":"agent_started","role":"mastery-builder","task":"task01"}
{"ts":"260514 000300","type":"agent_finished","role":"mastery-builder","task":"task01","instance_id":"abc","outputs":["deliverables/question-brief.md"]}
{"ts":"260514 000400","type":"agent_started","role":"learning-evaluator","task":"task01"}
{"ts":"260514 000500","type":"evaluation_finished","role":"learning-evaluator","task":"task01","instance_id":"def","report":"_agent/review-reports/task01-evaluation.md","judgment":"PASS","round":0}
JSONL

if ! python3 "$VALIDATOR" "$TEST_DIR/good" >/dev/null; then
  python3 "$VALIDATOR" "$TEST_DIR/good" >&2 || true
  fail "validator rejected a clean run"
fi

# --- Fixture 2: drop a required field; expect non-zero exit ------------------
BAD="$TEST_DIR/bad/_run"
mkdir -p "$BAD"
cp "$GOOD/events.jsonl" "$BAD/events.jsonl"
# state.json without `current_task` (required by schema)
python3 -c "
import json, sys
s = json.load(open('$GOOD/state.json'))
del s['current_task']
json.dump(s, open('$BAD/state.json', 'w'))
"

if python3 "$VALIDATOR" "$TEST_DIR/bad" >/dev/null; then
  fail "validator did not reject state.json missing required field"
fi
out=$(python3 "$VALIDATOR" "$TEST_DIR/bad" 2>&1 || true)
[[ "$out" == *"current_task"* ]] || fail "error did not mention the missing 'current_task' field; got:\n$out"

# --- Fixture 3: orphan evaluation_finished; expect protocol error ------------
ORPHAN="$TEST_DIR/orphan/_run"
mkdir -p "$ORPHAN"
cp "$GOOD/state.json" "$ORPHAN/state.json"
cat > "$ORPHAN/events.jsonl" <<'JSONL'
{"ts":"260514 000000","type":"project_started","project":"smoke","source":"input/q.md","output":"output/smoke"}
{"ts":"260514 000500","type":"evaluation_finished","role":"learning-evaluator","task":"task01","instance_id":"def","report":"r.md","judgment":"PASS","round":0}
JSONL

if python3 "$VALIDATOR" "$TEST_DIR/orphan" >/dev/null; then
  fail "validator did not catch orphan evaluation_finished"
fi
out=$(python3 "$VALIDATOR" "$TEST_DIR/orphan" 2>&1 || true)
[[ "$out" == *"no prior agent_started"* ]] || fail "error did not mention missing agent_started; got:\n$out"

echo "OK: validator passes clean run, rejects missing field + orphan event"
