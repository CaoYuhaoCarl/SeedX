# Output Artifact Layout

> This spec separates the learner-facing package from agent work files and runtime telemetry. Keep the layout small: one public entrypoint, one public artifact folder, and two internal folders.

---

## Design Goal

Each run should make two questions obvious:

1. What should the question asker read?
2. What files exist only so agents, evaluators, the controller, or the visualizer can do their jobs?

The output directory must not mix final learning artifacts with runtime traces at the same level.

---

## Layout

```text
output/{PROJECT_NAME}/
├── README.md
├── deliverables/
│   ├── question-brief.md
│   ├── domain-map.md
│   ├── learning-path.md
│   ├── exercises.md
│   ├── checkpoints.md
│   ├── application-plan.md
│   └── transfer-plan.md
├── _agent/
│   ├── learning-plan.md
│   ├── learning-contract.md
│   ├── learning-design-guide.md
│   ├── project-lessons.md
│   └── review-reports/
│       ├── task01-evaluation.md
│       ├── task02-evaluation.md
│       └── task03-evaluation.md
└── _run/
    ├── run-log.md
    ├── events.jsonl
    └── state.json
```

`README.md` is a path-only index. It may list the learning package files and internal diagnostic files, but it must not duplicate the learning content.

---

## Reader Classes

| Class | Directory | Reader | Purpose |
|---|---|---|---|
| Public learning package | `deliverables/` | Question asker / learner | The actual answer: framing, path, exercises, checkpoints, application, transfer |
| Agent workspace | `_agent/` | Planner, Builder, Evaluator, future controller | Contract, design instructions, project lessons, evaluation reports |
| Runtime telemetry | `_run/` | Main agent, controller, visualizer, operator | Current state, event stream, human-readable run narrative |
| Entry index | `README.md` | Everyone | Lightweight table of contents and status pointers |

---

## Classification

### Public Learning Package

These are the files the question asker should open first:

- `deliverables/question-brief.md`
- `deliverables/domain-map.md`
- `deliverables/learning-path.md`
- `deliverables/exercises.md`
- `deliverables/checkpoints.md`
- `deliverables/application-plan.md`
- `deliverables/transfer-plan.md`

### Agent Workspace

These files are useful for continuation, repair, evaluation, and protocol discipline. They are not the default reading path for the learner:

- `_agent/learning-plan.md`
- `_agent/learning-contract.md`
- `_agent/learning-design-guide.md`
- `_agent/project-lessons.md`
- `_agent/review-reports/task01-evaluation.md`
- `_agent/review-reports/task02-evaluation.md`
- `_agent/review-reports/task03-evaluation.md`

### Runtime Telemetry

These files exist to make the run observable and resumable:

- `_run/run-log.md`
- `_run/events.jsonl`
- `_run/state.json`

---

## Rules

1. Builder outputs always go under `deliverables/`.
2. Planner contract and design outputs always go under `_agent/`.
3. Evaluator reports always go under `_agent/review-reports/`.
4. Runtime state, event streams, and logs always go under `_run/`.
5. Main agent may create or update `README.md` only as an index of paths and statuses. It must not write learning content.
6. Events and state must store relative paths using this layout.
7. Legacy flat output directories may still be read by tools during migration, but new runs should write the grouped layout.

