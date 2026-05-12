# Repository Hygiene

This repository keeps source, specs, prompts, and reusable tooling in Git. Local editor state, installed plugin bundles, generated run output, and machine-specific runtime files stay outside Git.

## Tracked Paths

- `.claude/agents/`, `.claude/hooks/`, `.claude/skills/`
- `.agents/skills/`
- `.github/agents/`
- `docs/`
- `input/questions/`
- `tools/`
- top-level project docs such as `README*.md`, `AGENTS.md`, and `CLAUDE.md`

## Local-Only Paths

- `.env`, `.env.*`
- `.obsidian/workspace*.json`
- `.obsidian/plugins/`
- `.obsidian/themes/`
- `.claudian/`
- `.claude/settings.local.json`
- `.claude/agent-memory/`
- `output/*`, except `output/.gitkeep`

## Commit Guard

Install the repository hooks once per clone:

```bash
./tools/install-git-hooks.sh
```

The pre-commit hook runs:

```bash
python3 tools/guard-private-config.py --staged
```

For a full tracked-file check, run:

```bash
python3 tools/guard-private-config.py --all
```
