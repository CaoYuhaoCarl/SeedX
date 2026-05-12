# SeedX Rename With qtm Compatibility

Date: 2026-05-12

Question-to-Mastery is now SeedX. This is a name and trigger compatibility
release; the harness output layout, task IDs, `_run` observability files, and
Builder / Evaluator workflow remain unchanged.

## What Changed

- New project name: `SeedX`.
- New repository name: `CaoYuhaoCarl/SeedX`.
- Recommended direct triggers: `seedx <question>`, `seed <question>`, and
  `sx <question>`.
- Recommended private one-step flow: copy the question body, then send `+ask`.

## Compatibility

- `qtm <question>` continues to work as a legacy trigger.
- Natural legacy forms such as `用 qtm 调研问题：<question>` continue to work.
- `+ask`, `+ask-strict`, and `+start <path>` continue to work.
- Existing generated `output/` folders and old run logs remain valid.
- Existing architecture links keep using
  `docs/adr/0001-question-to-mastery-architecture.md` for stable-link
  compatibility.
- The legacy banner asset path is retained for old links; new docs use
  `docs/assets/seedx-banner.png`.

## Examples

| Before | After |
|---|---|
| `qtm <question>` | `seedx <question>` |
| `用 qtm 调研问题：<question>` | `用 seedx 调研问题：<question>` |
| Copy question, then send `+ask` | Unchanged |
| `+start input/questions/example.md` | Unchanged |
