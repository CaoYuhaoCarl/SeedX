# ADR 0001: Question-to-Mastery Harness Architecture

- Status: Accepted
- Date: 2026-05-07
- Project: Question-to-Mastery Harness
- Related roadmap: `docs/roadmap/ROADMAP.md`
- Reference: https://www.anthropic.com/engineering/harness-design-long-running-apps

---

## Context

Question-to-Mastery is a multi-agent harness that converts a learning question into an independently evaluated, directly executable learning path.

The core harness pattern:

1. The main agent receives a source document path but does not read the source content.
2. The main agent passes the path to a planning subagent.
3. The planner reads the source and writes plan artifacts to disk.
4. The main agent reads only task status and path-level artifacts, not the full source or generated content.
5. For each task, the main agent starts a builder subagent.
6. The builder writes output files to disk and returns only paths and status.
7. The main agent passes output file paths to an evaluator subagent.
8. The evaluator writes a local report and returns only PASS/FAIL and the report path.
9. If the task fails, the main agent resumes the same builder instance to fix the task.
10. The same evaluator instance then re-checks the fix.
11. If the task passes, the main agent moves to the next task and starts fresh builder/evaluator instances.

This architecture keeps the main agent context clean, preserves task-local builder/evaluator context during repair, and makes work resumable through files.

---

## Decision

Use a **Question-to-Mastery MVP architecture** with:

```text
3 agent types:
- question-planner
- mastery-builder
- learning-evaluator

2 skills:
- designing-mastery-paths
- reviewing-mastery-paths
```

Runtime uses **task-level agent instances**, not a single monolithic run:

```text
Task 1:
  mastery-builder instance A
  learning-evaluator instance A

Task 2:
  mastery-builder instance B
  learning-evaluator instance B

Task 3:
  mastery-builder instance C
  learning-evaluator instance C
```

If Task 1 fails:

```text
resume mastery-builder instance A
resume learning-evaluator instance A
```

Do not start a new builder/evaluator for the same failed task.

---

## Fixed MVP Task Units

The MVP uses three fixed task units:

```text
Task 1: Framing
- deliverables/question-brief.md
- deliverables/domain-map.md

Task 2: Mastery Path
- deliverables/learning-path.md
- deliverables/exercises.md
- deliverables/checkpoints.md

Task 3: Application
- deliverables/application-plan.md
- deliverables/transfer-plan.md
```

Each task has its own evaluation report:

```text
_agent/review-reports/task01-evaluation.md
_agent/review-reports/task02-evaluation.md
_agent/review-reports/task03-evaluation.md
```

The main agent only extracts:

```markdown
### 判定：PASS
```

or:

```markdown
### 判定：FAIL
```

It must not read full reports or generated learning deliverables.

---

## Why 3 Agent Types

Learning-path quality can be evaluated across multiple dimensions using a single structured rubric:

```text
Question Quality
Coverage
Clarity
Actionability
User Context Fit
Transferability
```

The MVP starts with one evaluator agent that covers all dimensions. Splitting into multiple specialized evaluator types is deferred until smoke tests show a specific dimension cannot be reliably handled by one evaluator.

This follows the principle from Anthropic's harness design article:

> Every harness component represents a hypothesis about what the model cannot reliably do on its own. That hypothesis should be pressure-tested; non-load-bearing components should be removed.

---

## Why Keep Task-Level Builder/Evaluator Instances

Although the project uses only three agent types, task-level instance isolation is a core invariant:

```text
new task → new builder/evaluator instances
same failed task → resume same builder/evaluator instances
```

Reasons:

1. **Repair context matters**: the builder that produced the task has local context about its own decisions.
2. **Evaluator continuity matters**: the evaluator that found the issue knows what it meant by the failure.
3. **Main context hygiene matters**: the main agent should not absorb full content or reports.
4. **Cross-task isolation matters**: new tasks should not inherit stale reasoning from earlier tasks.
5. **File-based memory matters**: durable state lives in markdown artifacts, not in main-agent chat context.

---

## Why Add `_agent/learning-contract.md`

The harness introduces a central artifact:

```text
_agent/learning-contract.md
```

It defines:

- original question
- problem type
- learner context
- final learning goals
- must-answer questions
- must-cover concepts
- non-goals
- fixed task units
- acceptance criteria

This plays a role similar to a sprint contract in long-running harness design: it anchors builder and evaluator around the same definition of done.

Without a contract, the builder may generate a polished but generic article. With a contract, output is judged against explicit mastery goals.

---

## Preserved Harness Invariants

The following rules are non-negotiable:

1. The main agent does not read the learning source text.
2. The main agent does not write learning deliverables.
3. The main agent does not read builder deliverables.
4. The main agent does not read full evaluator reports.
5. Planner reads the source and writes planning artifacts.
6. Builder writes deliverables to files and returns paths/status only.
7. Evaluator writes reports to files and returns PASS/FAIL plus path only.
8. Same-task failure resumes the same builder.
9. Same-task re-evaluation resumes the same evaluator.
10. New tasks use fresh builder/evaluator instances.
11. Output stays under `output/{PROJECT_NAME}/`.
12. Public learning artifacts are written under `deliverables/`; agent work files under `_agent/`; runtime logs/state under `_run/`.
13. Logs are written to `_run/run-log.md` using `yymmdd hhmm` format.

---

## Consequences

### Benefits

- Keeps main agent context small and clean.
- Structured repair loop with same-instance resume semantics.
- Low MVP complexity with clear extension paths.
- Evaluator rubric is independently tunable.
- Produces durable learning artifacts, not transient chat answers.

### Tradeoffs

- A single evaluator may be too broad in early versions.
- The rubric must be strong; otherwise generic outputs may pass.
- Fixed three-task MVP may not fit every future learning use case.
- Source-augmented learning and knowledge-base integration are postponed.

### Mitigations

- Tune `reviewing-mastery-paths` first if evaluator is too loose.
- Tune `designing-mastery-paths` and `_agent/learning-contract.md` if builder output is too generic.
- Add new agent types only after smoke tests show a component is truly load-bearing.
- Track future expansions in `docs/roadmap/ROADMAP.md`.

---

## Alternatives Considered

### Alternative A: Single-agent learning-path generator

Rejected.

Reason: a single agent tends to under-scope, self-approve, and produce polished but generic summaries. The planner/builder/evaluator separation is load-bearing for this use case.

### Alternative B: Whole-package build and evaluation only

Rejected.

Reason: whole-package evaluation weakens repair semantics. Task-level processing with same-task resume is load-bearing for quality improvement loops.

---

## When to Revisit

Revisit this decision if smoke tests show:

1. The single evaluator repeatedly misses specific dimensions.
2. Question quality needs a dedicated coaching stage.
3. Long source documents require a separate source reader.
4. Transfer planning becomes important enough to need its own agent.
5. Knowledge-base integration becomes a stable requirement.

Possible future agent types:

```text
question-coach
source-reader
knowledge-curator
transfer-transformer
```

But each must be justified as load-bearing before being added.
