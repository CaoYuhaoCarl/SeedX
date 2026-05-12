# Run Log Format

> `_run/run-log.md` is the human-readable run log for SeedX, formerly Question-to-Mastery. Machine-readable workflow data belongs in `_run/events.jsonl` and `_run/state.json`.

---

## Goals

`_run/run-log.md` should help the operator quickly answer:

1. What project ran?
2. What input path and output directory were used?
3. Which phase/task is done?
4. Which Builder/Evaluator instance handled each task?
5. Did each task PASS, FAIL, or require repair?
6. Where are the output files and reports?

It should not be the learner-facing package. The question asker should read `README.md` and `deliverables/` first. It should also not be a raw event dump; that is what `_run/events.jsonl` is for.

Historical run logs may still use `# Question-to-Mastery Run Log — {PROJECT_NAME}`. New runs should use `# SeedX Run Log — {PROJECT_NAME}`; readers and visualizers should rely on `_run/events.jsonl` and `_run/state.json` for machine-readable state instead of parsing the brand text in this heading.

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
# SeedX Run Log — {PROJECT_NAME}

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
- Expected outputs: `_agent/learning-plan.md`, `_agent/learning-contract.md`, `_agent/learning-design-guide.md`, `_agent/project-lessons.md`

### {yymmdd hhmm} — Planning Completed

- Status: planned
- Outputs:
  - `_agent/learning-plan.md`
  - `_agent/learning-contract.md`
  - `_agent/learning-design-guide.md`
  - `_agent/project-lessons.md`
- Next: start `task01`

### {yymmdd hhmm} — task01 Framing: Build Started

- Status: 🔄 building
- Builder: new `mastery-builder` instance
- Outputs expected: `deliverables/question-brief.md`, `deliverables/domain-map.md`

### {yymmdd hhmm} — task01 Framing: Build Completed

- Builder ID: `{BUILDER_ID_TASK01}`
- Outputs written:
  - `deliverables/question-brief.md`
  - `deliverables/domain-map.md`
- Next: evaluate task01

### {yymmdd hhmm} — task01 Framing: Evaluation Completed

- Evaluator ID: `{EVALUATOR_ID_TASK01}`
- Judgment: **PASS**
- Report: `_agent/review-reports/task01-evaluation.md`
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
| `README.md` | Human | path-only entrypoint to public and internal files |
| `deliverables/` | Question asker / learner | final learning package |
| `_agent/` | Agents / evaluator | contract, design guide, lessons, reports |
| `_run/run-log.md` | Operator | clear run narrative |
| `_run/events.jsonl` | Machine / visualizer | append-only event stream |
| `_run/state.json` | Machine / visualizer | current state snapshot |

If the same information appears in both files, prefer:

- `_run/run-log.md`: readable summary
- `_run/events.jsonl`: structured event
- `_run/state.json`: latest snapshot
