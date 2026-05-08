<div align="center">

<img src="docs/assets/question-to-mastery-banner.png" alt="Question-to-Mastery banner" width="100%">

# Question-to-Mastery

<img src="https://img.shields.io/badge/version-v0.1_MVP-blue.svg" alt="Version v0.1 MVP">
<img src="https://img.shields.io/badge/Status-Active-success.svg" alt="Status Active">
<img src="https://img.shields.io/badge/Architecture-Multi--agent-8a2be2" alt="Architecture Multi-agent">
<a href="https://x.com/CaoYuhaoCarl"><img src="https://img.shields.io/badge/follow-%40CaoYuhaoCarl-000000?logo=x&logoColor=white" alt="Follow on X"></a>

🇺🇸 **English** · <a href="README.zh-CN.md">🇨🇳 简体中文</a> · <a href="README.ja.md">🇯🇵 日本語</a>

</div>

A multi-agent learning path generation system: give it a learning question, and it produces an independently evaluated, directly executable path toward mastery.

```text
Learning question
  ↓
question-planner  Creates the Learning Contract and design guide
  ↓
mastery-builder   Generates learning artifacts task by task
  ↓
learning-evaluator  Independently evaluates PASS/FAIL
  ↓
On FAIL, resume the same Builder for fixes and the same Evaluator for re-checks
(up to 2 repair rounds)
```

By default, the system is not bound to any specific user, industry, profession, or application scenario. Personalization comes only from the background, goals, and constraints explicitly written in the input file.

---

## Quick Start

### Slash trigger (recommended)

Just type into Claude Code:

```text
+ask <your learning question body>
```

A `UserPromptSubmit` hook will:
- Save the question body to `input/questions/question-<timestamp>.md`
- Inject the path and launch instruction so the orchestrator starts immediately
- Open Harness Visualizer in the background and wait for this run's `events.jsonl` + `state.json`

Project name and output directory are auto-derived from the filename — nothing else to fill in.

### Strict isolation modes (for sensitive questions)

When the question contains PII, trade secrets, or you want to maximize "main agent never sees the body":

| Trigger | Behavior | UX |
|---|---|---|
| `+ask` (copy the body to clipboard first; no inline body) | Read via `pbpaste`, save, and launch | 1 step |
| `+ask-strict <body>` | Save and block the original message; orchestrator only starts after you send `+start` | 2 steps |
| `+start [path]` | Launch with explicit path, or the most recent question file | — |

Clipboard and strict modes have the same isolation strength — the body never enters the main agent's context. They differ only in UX. See [CLAUDE.md §1.2](CLAUDE.md) for the isolation contract.

### Manual launch (advanced)

If you want to override the project name or output directory, the legacy prompt still works:

```text
Learning question path: {WORKSPACE_DIR}/input/questions/{question-file}.md
Project name: {project-name}
Output directory: {WORKSPACE_DIR}/output/{project-name}

Please strictly follow the CLAUDE.md in the current workspace:
- Current workspace: {WORKSPACE_DIR}
- The learning question path is input only; do not set the output directory to the input file's folder
- Write all generated artifacts to the output directory
- Keep the default perspective as a general learner; only background, goals, scenarios, and constraints explicitly provided by the input file may enter the learning contract and artifacts
- After initialization, create run-log.md, events.jsonl, and state.json, then start the question-planner subagent
```

Example input files are available in `input/questions/`.

---

## Run Output

A complete run generates the following under `output/{project-name}/`:

```text
output/{project-name}/
├── learning-plan.md           # Execution plan
├── learning-contract.md       # Learning contract, shared by Builder and Evaluator
├── learning-design-guide.md   # Design guide
├── question-brief.md          # Question brief
├── domain-map.md              # Domain map
├── learning-path.md           # Learning path
├── exercises.md               # Exercises
├── checkpoints.md             # Checkpoints
├── application-plan.md        # Application plan
├── transfer-plan.md           # Transfer plan
├── project-lessons.md         # Cross-task lessons
├── run-log.md                 # Human-readable run log
├── events.jsonl               # Event stream for the visualization panel
├── state.json                 # Current state snapshot
└── review-reports/
    ├── task01-evaluation.md
    ├── task02-evaluation.md
    └── task03-evaluation.md
```

---

## Fixed Task Units

| Task | Name | Builder outputs | Evaluation report |
|---|---|---|---|
| task01 | Framing | `question-brief.md`, `domain-map.md` | `review-reports/task01-evaluation.md` |
| task02 | Mastery Path | `learning-path.md`, `exercises.md`, `checkpoints.md` | `review-reports/task02-evaluation.md` |
| task03 | Application & Transfer | `application-plan.md`, `transfer-plan.md` | `review-reports/task03-evaluation.md` |

Tasks run in the fixed order `task01 → task02 → task03`. Each task is built first, then evaluated. PASS moves to the next task; FAIL enters a repair loop for up to 2 rounds.

---

## Repository Structure

```text
.
├── CLAUDE.md                        # Main agent orchestration protocol
├── README.md                        # English README, default
├── README.zh-CN.md                  # Simplified Chinese README
├── README.ja.md                     # Japanese README
├── input/questions/                 # Learning question input files
├── output/{project-name}/           # Run outputs, isolated by project
├── docs/
│   ├── assets/                      # README and documentation assets
│   ├── plans/                       # Implementation plans
│   ├── roadmap/                     # Version roadmap
│   ├── adr/                         # Architecture Decision Records
│   └── specs/                       # Event protocol and log format specs
├── tools/
│   ├── harness-visualizer.html      # Single-file visualization panel
│   └── open-visualizer.sh           # One-command panel launcher
└── .claude/
    ├── agents/
    │   ├── question-planner.md
    │   ├── mastery-builder.md
    │   └── learning-evaluator.md
    └── skills/
        ├── designing-mastery-paths/
        └── reviewing-mastery-paths/
```

---

## Observability Visualization

v0.2 adds a lightweight observability layer: it does not read learning artifact bodies, only run state. When you start with `+ask` / `+start`, the intake hook opens the panel in the background; the panel waits for and polls this run's `events.jsonl` + `state.json`.

```bash
# Open the panel and load events.jsonl + state.json for a project, refreshing every 2 seconds
./tools/open-visualizer.sh {project-name}

# Without a project name, automatically choose the newest project under output/
./tools/open-visualizer.sh
```

See [docs/specs/harness-observability-events.md](docs/specs/harness-observability-events.md) for the event protocol and [docs/specs/run-log-format.md](docs/specs/run-log-format.md) for the log format.

---

## Evaluation Criteria

`learning-evaluator` uses a 6-dimension rubric, scored from 1 to 5:

| Dimension | Description |
|---|---|
| Question Quality | Whether the question is correctly understood and focused |
| Coverage | Whether the domain coverage is sufficient |
| Clarity | Whether the output is clear and understandable |
| Actionability | Whether the output can be executed directly |
| User Context Fit | Whether personalization strictly comes from the input file |
| Transferability | Whether the knowledge can transfer to new scenarios |

All dimensions must score at least 4/5 to PASS. Extra hard gate: if an artifact introduces personal, industry, or professional background not provided by the input file, it FAILS.

---

## Tuning Guide

**If artifacts are too generic:**
1. Tune the `reviewing-mastery-paths` skill first so the Evaluator becomes stricter.
2. Then tune the `designing-mastery-paths` skill so the Builder receives sharper generation goals.
3. Only then consider adding a new Agent or splitting the Reviewer.

**If artifacts incorrectly assume a specific user or industry:**
1. Check whether the input file actually provides that background.
2. Check the "learner background and application scenario" section in `learning-contract.md`.
3. Then tune the `User Context Fit` hard gate in `reviewing-mastery-paths`.

Every component must prove it is load-bearing before the system adds more complexity.

---

## Design Decision

See [docs/adr/0001-question-to-mastery-architecture.md](docs/adr/0001-question-to-mastery-architecture.md).
