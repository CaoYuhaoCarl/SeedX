# Run Log Format

> `run-log.md` is the human-readable run log for Question-to-Mastery Harness. Machine-readable workflow data belongs in `events.jsonl` and `state.json`.

---

## Goals

`run-log.md` should help the user quickly answer:

1. What project ran?
2. What input path and output directory were used?
3. Which phase/task is done?
4. Which Builder/Evaluator instance handled each task?
5. Did each task PASS, FAIL, or require repair?
6. Where are the output files and reports?

It should not be a raw event dump. That is what `events.jsonl` is for.

---

## Rules

1. Use normal Markdown headings, tables, and short bullets.
2. Keep each timeline entry to 3-6 bullets.
3. Record only paths, status, agent IDs, judgments, and next step.
4. Do not paste learning source body.
5. Do not paste builder deliverable body.
6. Do not paste full evaluation reports.
7. Do not write hidden reasoning.

---

## Recommended Structure

```markdown
# Question-to-Mastery Run Log — {PROJECT_NAME}

## Run Metadata

| Field | Value |
|---|---|
| Started | {yymmdd hhmm} |
| Source | `{LEARNING_SOURCE_FILE}` |
| Workspace | `{WORKSPACE_DIR}` |
| Output | `{OUTPUT_DIR}` |
| Mode | fixed task01 → task02 → task03 |

## Timeline

### {yymmdd hhmm} — Project Started

- Status: initialized
- Next: start `question-planner`

### {yymmdd hhmm} — Planning Started

- Agent: `question-planner`
- Input: source path only
- Expected outputs: `learning-plan.md`, `learning-contract.md`, `learning-design-guide.md`, `project-lessons.md`

### {yymmdd hhmm} — Planning Completed

- Status: planned
- Outputs:
  - `learning-plan.md`
  - `learning-contract.md`
  - `learning-design-guide.md`
  - `project-lessons.md`
- Next: start `task01`

### {yymmdd hhmm} — task01 Framing: Build Started

- Status: 🔄 building
- Builder: new `mastery-builder` instance
- Outputs expected: `question-brief.md`, `domain-map.md`

### {yymmdd hhmm} — task01 Framing: Build Completed

- Builder ID: `{BUILDER_ID_TASK01}`
- Outputs written:
  - `question-brief.md`
  - `domain-map.md`
- Next: evaluate task01

### {yymmdd hhmm} — task01 Framing: Evaluation Completed

- Evaluator ID: `{EVALUATOR_ID_TASK01}`
- Judgment: **PASS**
- Report: `review-reports/task01-evaluation.md`
- Round: 0

### {yymmdd hhmm} — task01 Framing: Task Completed

- Final status: ✅
- Final judgment: **PASS**
- Iterations: 0
- Next: `task02`

## Final Summary

| Field | Value |
|---|---|
| Project status | PASS |
| Started | {START_TIME} |
| Finished | {END_TIME} |
| Duration | {DURATION} |
| Tasks completed | 3 / 3 |

## Iteration Summary

| Category | Count |
|---|---:|
| 1-pass tasks | {X} |
| 2-pass tasks | {Y} |
| 3-pass tasks | {Z} |
| Low-quality passes | {W} |

## Output

- Output directory: `{OUTPUT_DIR}`
```

---

## Relationship to Observability Files

| File | Reader | Purpose |
|---|---|---|
| `run-log.md` | Human | clear run narrative |
| `events.jsonl` | Machine / visualizer | append-only event stream |
| `state.json` | Machine / visualizer | current state snapshot |

If the same information appears in both files, prefer:

- `run-log.md`: readable summary
- `events.jsonl`: structured event
- `state.json`: latest snapshot
