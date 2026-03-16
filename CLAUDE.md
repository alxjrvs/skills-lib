# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal Claude Code plugin marketplace hosted at `alxjrvs/skills`. Users install via:

```
/plugin marketplace add alxjrvs/skills
/plugin install <plugin-name>@jrvs-skills
```

## Validation

Validate the full marketplace:
```bash
claude plugin validate .
```

Validate a single plugin:
```bash
claude plugin validate ./<plugin-name>
```

## Adding a Local Plugin

1. Create a root-level folder: `<plugin-name>/`
2. Add `.claude-plugin/plugin.json` with `name`, `version`, `description`
3. Add plugin content (`skills/`, `agents/`, `hooks/`, `scripts/` as needed)
4. Register in `.claude-plugin/marketplace.json` under `plugins` with `"source": "./<plugin-name>"`
5. Run `claude plugin validate .` to confirm

## Adding an External Plugin

Add an entry to `.claude-plugin/marketplace.json` with a GitHub source — no local folder needed:

```json
{
  "name": "plugin-name",
  "source": { "source": "github", "repo": "alxjrvs/plugin-repo" }
}
```

## Plugin Structure

Each local plugin folder mirrors a standalone plugin repo (strict mode):

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json       # name, version, description — versioning lives here only
├── skills/
│   └── skill-name/
│       └── SKILL.md
├── agents/               # if needed
├── hooks/                # if needed
└── scripts/              # if needed
```

Key constraints:
- No shared utilities between plugins (cache-copy breaks cross-plugin paths)
- Version set in `plugin.json` only, never duplicated in `marketplace.json`
- Plugin folders must be self-contained
- Hook scripts reference plugin files via `${CLAUDE_PLUGIN_ROOT}/scripts/`
