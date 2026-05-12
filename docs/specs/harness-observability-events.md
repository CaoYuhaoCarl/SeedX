# Harness Observability Events Schema

> v0.2-observability: lightweight event stream and state snapshot for SeedX Harness.

This schema is intentionally limited to workflow metadata. It must not contain learning source body, builder deliverable body, full evaluation reports, or internal agent reasoning.

---

## Files

Each run output directory should contain:

```text
output/{PROJECT_NAME}/
└── _run/
    ├── run-log.md   # human-readable log
    ├── events.jsonl # append-only machine-readable event stream
    └── state.json   # current state snapshot
```

Optional project-level viewer:

```text
tools/harness-visualizer.html
```

---

## Event Stream: `_run/events.jsonl`

Each line is one JSON object.

Required common fields:

```json
{
  "ts": "260507 181455",
  "type": "event_type"
}
```

Recommended optional common fields:

```json
{
  "project": "ai-agent-memory-260507-181455",
  "task": "task01",
  "role": "mastery-builder",
  "instance_id": "abc123"
}
```

---

## Event Types

### `project_started`

```json
{"ts":"260507 181455","type":"project_started","project":"ai-agent-memory-260507-181455","source":"input/questions/question-source-ai-agent-memory-260507-181455.md","output":"output/ai-agent-memory-260507-181455"}
```

### `agent_started`

```json
{"ts":"260507 181500","type":"agent_started","role":"question-planner","task":"planning","instruction":"学习问题路径：input/questions/question-source-ai-agent-memory-260507-181455.md\n输出目录：output/ai-agent-memory-260507-181455\n\n请读取学习问题和 designing-mastery-paths skill，按 explicit-input-only 个性化原则产出 _agent/learning-plan.md、_agent/learning-contract.md、_agent/learning-design-guide.md、_agent/project-lessons.md，并创建 _agent/review-reports/。完成后只返回文件路径列表。"}
```

`instruction` is the exact handoff prompt sent to the subagent after substituting paths/task fields. It may contain protocol instructions and paths, but never source bodies, deliverable bodies, full reports, hidden reasoning, or credentials.

### `agent_finished`

```json
{"ts":"260507 181812","type":"agent_finished","role":"question-planner","task":"planning","outputs":["_agent/learning-plan.md","_agent/learning-contract.md","_agent/learning-design-guide.md","_agent/project-lessons.md"]}
```

### `task_status_changed`

```json
{"ts":"260507 181900","type":"task_status_changed","task":"task01","from":"📋","to":"✏️"}
```

### `evaluation_finished`

```json
{"ts":"260507 182630","type":"evaluation_finished","role":"learning-evaluator","task":"task01","instance_id":"def456","report":"_agent/review-reports/task01-evaluation.md","judgment":"FAIL","round":0}
```

### `agent_resumed`

```json
{"ts":"260507 182700","type":"agent_resumed","role":"mastery-builder","task":"task01","instance_id":"abc123","reason":"evaluation_failed","round":1,"instruction":"当前任务：task01 (Framing)\n评估报告：output/ai-agent-memory-260507-181455/_agent/review-reports/task01-evaluation.md\n相关产物：output/ai-agent-memory-260507-181455/deliverables/question-brief.md, output/ai-agent-memory-260507-181455/deliverables/domain-map.md\nproject-lessons: output/ai-agent-memory-260507-181455/_agent/project-lessons.md\n\n请读取评估报告，修正所有必须修复的问题，并更新 project-lessons.md。不得引入输入文件未明确给出的个人/行业背景。完成后只返回简短确认和已更新路径。"}
```

### `visualizer_started`

```json
{"ts":"260507 181456","type":"visualizer_started","project":"ai-agent-memory-260507-181455","url":"http://127.0.0.1:8765/tools/harness-visualizer.html?project=ai-agent-memory-260507-181455","status":"ok","log":"/tmp/harness-visualizer-8765.log"}
```

If launch fails, use `"status":"failed"` and include `error` and/or `log`. The core harness should continue after recording the failure.

### `project_finished`

```json
{"ts":"260507 184000","type":"project_finished","project":"ai-agent-memory-260507-181455","status":"PASS","duration":"26m"}
```

---

## State Snapshot: `_run/state.json`

`_run/state.json` is overwritten whenever a meaningful state transition occurs.

Example:

```json
{
  "project": "ai-agent-memory-260507-181455",
  "source": "input/questions/question-source-ai-agent-memory-260507-181455.md",
  "output": "output/ai-agent-memory-260507-181455",
  "phase": "task_loop",
  "current_task": "task02",
  "updated_at": "260507 182700",
  "tasks": {
    "task01": {
      "title": "Framing",
      "status": "✅",
      "builder_id": "abc123",
      "evaluator_id": "def456",
      "iterations": 1,
      "judgment": "PASS",
      "outputs": ["deliverables/question-brief.md", "deliverables/domain-map.md"],
      "report": "_agent/review-reports/task01-evaluation.md"
    },
    "task02": {
      "title": "Mastery Path",
      "status": "✏️",
      "builder_id": "ghi789",
      "evaluator_id": null,
      "iterations": 0,
      "judgment": null,
      "outputs": ["deliverables/learning-path.md", "deliverables/exercises.md", "deliverables/checkpoints.md"],
      "report": "_agent/review-reports/task02-evaluation.md"
    },
    "task03": {
      "title": "Application & Transfer",
      "status": "📋",
      "builder_id": null,
      "evaluator_id": null,
      "iterations": 0,
      "judgment": null,
      "outputs": ["deliverables/application-plan.md", "deliverables/transfer-plan.md"],
      "report": "_agent/review-reports/task03-evaluation.md"
    }
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
```

---

## Discipline Rules

Never put these into `_run/events.jsonl` or `_run/state.json`:

- learning source body
- builder deliverable body
- full evaluation report body
- hidden chain-of-thought or internal reasoning
- private credentials
- user profile or personal background unless represented only as an input path or explicit metadata field required by the run

Allowed metadata:

- file paths
- task IDs
- agent roles
- agent instance IDs
- status symbols
- PASS/FAIL judgments
- iteration counts
- timestamps
- exact subagent handoff instruction text, provided it contains only paths/protocol instructions and no source or deliverable bodies

---

## Viewer Requirements

`tools/harness-visualizer.html` must work without a backend. First version supports local file upload of:

- `_run/events.jsonl`
- optional `_run/state.json`

If opened via a local static server, it may optionally fetch files by URL, but must not require that mode.
