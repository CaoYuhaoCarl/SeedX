# SeedX Rename Migration Todo

This todo tracks the migration from `Question-to-Mastery` / `question-to-mastery`
to `SeedX`, while keeping `qtm` as a supported legacy trigger for existing users.

## Scope

- New public name: `SeedX`
- New repository name: `CaoYuhaoCarl/SeedX`
- Legacy public name: `Question-to-Mastery`
- Legacy trigger that must keep working: `qtm` in any casing
- Primary trigger families to support:
  - `seedx` in any casing: `seedx`, `SeedX`, `seedX`, `Seedx`, `SEEDX`
  - `seed` in any casing: `seed`, `Seed`, `SEED`
  - `sx` in any casing: `sx`, `SX`, `Sx`, `sX`
  - legacy `qtm` in any casing: `qtm`, `QTM`, `qTm`
- Optional legacy alias to consider: `q2m` / `Q2M`, because hook comments already use
  "Q2M trigger" wording even though the current implementation does not accept it.

## Non-Goals

- Do not rewrite historical `input/questions/` files.
- Do not rewrite historical `output/` run artifacts.
- Do not remove `qtm` compatibility.
- Do not rename the `.claude/` compatibility surface only for aesthetics.
- Do not change task semantics, output layout, or builder/evaluator protocols in the
  same change as the brand rename unless a test proves it is required.

## Phase 0 - Repository Identity

- [x] Rename GitHub repo from `CaoYuhaoCarl/question-to-mastery` to `CaoYuhaoCarl/SeedX`.
- [x] Update local `origin` remote to `https://github.com/CaoYuhaoCarl/SeedX.git`.
- [ ] Decide whether the local checkout folder should remain
  `harness_question-to-mastery` for continuity or be renamed manually outside the
  repo after all open work is clean.
- [ ] Update repository description if the public positioning should mention SeedX
  explicitly.
- [ ] Check external references that may not follow GitHub redirects:
  bookmarks, docs links, README badges, package metadata, Vercel/GitHub Pages
  settings, and any automation secrets that include repo URLs.

## Phase 1 - Add Compatibility Tests Before Changing Triggers

- [x] Create a small hook test script, for example
  `tools/test-intake-triggers.sh`, that feeds JSON into
  `.claude/hooks/intake-question.sh`.
- [x] Test legacy launchers:
  - `qtm <body>`
  - `QTM <body>`
  - `用 qtm 调研问题：<body>`
  - `用 QTM 研究问题:<body>`
- [x] Test new SeedX launchers:
  - `seedx <body>`
  - `SeedX <body>`
  - `seedX <body>`
  - `Seedx <body>`
  - `SEEDX <body>`
  - `seed <body>`
  - `Seed <body>`
  - `SEED <body>`
  - `sx <body>`
  - `SX <body>`
  - `Sx <body>`
  - `sX <body>`
  - `用 seedx 调研问题：<body>`
  - `用 SeedX 研究问题:<body>`
  - `用 seed 学习问题：<body>`
  - `用 sx 分析问题：<body>`
- [ ] Test strict and clipboard-safe launchers remain unchanged:
  - `+ask`
  - `+ask <body>`
  - `+ask:<body>`
  - `+ask：<body>`
  - `+ask-strict <body>`
  - `+start <path>`
- [x] Test pass-through prompts that must not trigger:
  - ordinary messages containing `seedx`, `seed`, `sx`, or `qtm` mid-sentence
  - `seed` as a noun in the middle of a normal question
  - empty launcher prompts such as `seedx`, `seed`, `sx`, and `qtm`
- [x] Acceptance check: every launch event still includes only a source path in
  `HARNESS_LAUNCH_TRIGGER`, never the source body.

## Phase 2 - Refactor Trigger Parsing

- [x] In `.claude/hooks/intake-question.sh`, replace
  `extract_natural_qtm_body` with an alias-based parser such as
  `extract_natural_launcher_body`.
- [x] Define one canonical alias regex, case-insensitive:
  `qtm|seedx|seed|sx`.
- [ ] Consider adding `q2m` to the alias regex only if the compatibility test list
  and README explicitly document it as legacy.
- [x] Keep direct launch patterns anchored to the beginning of the prompt.
- [x] Keep natural-language launch patterns anchored and require the `问题`
  keyword plus `:` or `：`, so ordinary mentions do not launch accidentally.
- [x] For the `seed` alias, decide whether `seed <body>` is acceptable despite the
  higher false-positive risk. If not, support `seed:` and `用 seed ...问题：`
  while recommending `seedx` / `sx` for one-word launch.
- [x] Update hook comments to say "SeedX intake hook" and list both new and legacy
  launchers.
- [ ] Update block messages to recommend `SeedX` language while keeping `+ask` and
  `qtm` examples available for old users.
- [x] Run hook tests and inspect only protocol-level output.

## Phase 3 - Update Agent Protocol Entrypoints

- [x] Update `AGENTS.md` trigger rule to include:
  `+ask`, `+start`, `qtm`, `seedx`, `seed`, `sx`, and natural Chinese forms such
  as `用 seedx ...问题：`.
- [x] Update `CLAUDE.md` with the same trigger rule.
- [x] Rename protocol headings from `Question-to-Mastery` to `SeedX` where the
  heading is public-facing.
- [x] Keep a compatibility note near the top:
  "`qtm` remains a legacy trigger and is intentionally supported."
- [x] Update `HARNESS_LAUNCH_TRIGGER` additional context in the hook to say
  `SeedX` while retaining the same path-only isolation requirements.
- [ ] Do not change subagent type names unless there is a separate compatibility
  plan for existing Claude/Codex agent configuration.

## Phase 4 - Public Documentation Rename

- [x] Update `README.md`, `README.zh-CN.md`, and `README.ja.md`:
  - title becomes `SeedX`
  - first paragraph introduces SeedX
  - trigger table shows SeedX aliases first
  - `qtm` row is labeled "legacy compatible"
  - `+ask` / `+start` instructions stay unchanged
- [x] Keep old-name discoverability in one short line:
  "Formerly Question-to-Mastery."
- [x] Add `docs/assets/seedx-banner.png` and update README references. Keep
  `docs/assets/question-to-mastery-banner.png` as a compatibility asset for old
  links because the image itself has no old-name text.
- [x] Update image references and alt text in all READMEs.
- [x] Update architecture docs:
  - `docs/adr/0001-question-to-mastery-architecture.md`
  - `docs/plans/harness-observability-visualization-plan.md`
  - `docs/specs/run-log-format.md`
  - `docs/specs/harness-observability-events.md`
  - `docs/roadmap/ROADMAP.md`
- [x] Decide whether to rename ADR filenames. Decision: keep existing ADR
  filenames for stable links and put SeedX in the document title/body.

## Phase 5 - Internal Naming Pass

- [x] Update tool comments in:
  - `tools/derive-project-name.py`
  - `tools/open-visualizer.sh`
- [x] Review `.claude/hooks/intake-question.sh` comments. Current `qtm`
  mentions are intentional legacy-trigger examples, not stale product naming.
- [x] Update `.claude/agents/*.md` and `.claude/skills/*.md` descriptions from
  Question-to-Mastery to SeedX where they describe the product.
- [x] Update `.agents/skills/*.md` copies in the same way, if they are meant to
  stay mirrored.
- [x] Keep task IDs and artifact paths unchanged:
  `task01`, `task02`, `task03`, `deliverables/`, `_agent/`, `_run/`.
- [x] Keep generated run titles stable unless a deliberate output-format version
  bump is planned. If changed, update docs and visualizer assumptions together.

## Phase 6 - Runtime Output Compatibility

- [x] Decide whether new runs should say
  `# SeedX Output - {PROJECT_NAME}` and `# SeedX Run Log - {PROJECT_NAME}`.
- [x] If changing run headings, update:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `docs/specs/run-log-format.md`
  - any visualizer parsing assumptions
- [x] Verify the visualizer reads `_run/events.jsonl` and `_run/state.json`
  without depending on old run-log headings.
- [x] Keep old output folders readable; do not migrate historical run logs.

## Phase 7 - Release Notes And User Migration

- [x] Add a short migration note:
  - "The project is now SeedX."
  - "`qtm` continues to work."
  - "Recommended new triggers: `seedx`, `seed`, `sx`, or `+ask`."
  - "Existing generated outputs and old links remain valid."
- [x] Add examples for old users:
  - old: `qtm <question>`
  - new: `seedx <question>`
  - safe one-step: copy question, then send `+ask`
  - path launch: `+start input/questions/...md`
- [ ] If a release tag is cut, use a compatibility-oriented title such as
  `SeedX rename with qtm compatibility`.

## Phase 8 - Verification Checklist

- [ ] Run `rg -n --hidden -g '!/.git/**' -g '!input/questions/**' -g '!output/**'`
  for old names and inspect intentional leftovers.
- [ ] Run the hook trigger tests.
- [ ] Start one disposable harness run with `seedx <body>` and verify:
  - question file is created under `input/questions/`
  - output goes under `output/{PROJECT_NAME}/`
  - `_run/events.jsonl` contains protocol fields only
  - `_run/state.json` contains paths and statuses only
  - visualizer starts or logs a non-blocking failure
- [ ] Start one disposable harness run with `qtm <body>` and verify the same
  behavior.
- [ ] Confirm `git remote -v` points to `CaoYuhaoCarl/SeedX`.
- [ ] Confirm `gh repo view CaoYuhaoCarl/SeedX` resolves.
- [ ] Confirm README examples match the actual hook behavior.

## Suggested Implementation Order

1. Land tests for the current `qtm` behavior.
2. Add SeedX aliases in the hook.
3. Update AGENTS/CLAUDE trigger rules.
4. Update READMEs and migration note.
5. Update internal comments and skill descriptions.
6. Update docs and assets.
7. Run full compatibility verification.
8. Make a small release commit and tag after both `seedx` and `qtm` launch paths
   are proven.
