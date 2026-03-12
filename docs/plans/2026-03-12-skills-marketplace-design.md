# Skills Marketplace Design

## Overview

`alxjrvs/skills-lib` is a personal Claude Code plugin marketplace hosted on GitHub. Users install it via `/plugin marketplace add alxjrvs/skills-lib` and install individual plugins with `/plugin install <name>@jrvs-skills`.

## Repository Structure

```
skills-lib/
├── .claude-plugin/
│   └── marketplace.json          # marketplace catalog
├── claude-tmux-status/           # example local plugin
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── skills/
│       └── claude-tmux-status/
│           └── SKILL.md
└── docs/
    └── plans/
```

Local plugins live as root-level folders. External plugins are referenced in `marketplace.json` only — no folder in this repo.

## Marketplace Catalog

`.claude-plugin/marketplace.json`:

```json
{
  "name": "jrvs-skills",
  "owner": { "name": "alxjrvs" },
  "plugins": [
    {
      "name": "claude-tmux-status",
      "source": "./claude-tmux-status"
    }
  ]
}
```

External plugin entry format:

```json
{
  "name": "some-external-plugin",
  "source": { "source": "github", "repo": "alxjrvs/some-external-plugin" }
}
```

## Plugin Conventions

Each local plugin folder mirrors a standalone plugin repo (strict mode — each has its own `plugin.json`):

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json       # name, version, description
├── skills/               # if plugin has skills
│   └── skill-name/
│       └── SKILL.md
├── agents/               # if plugin has agents
├── hooks/                # if plugin has hooks
└── scripts/              # if plugin has runnable scripts
```

- Versioning lives in `plugin.json` only (not duplicated in `marketplace.json`)
- No shared utilities between plugins (cache-copy mechanism makes cross-plugin paths unreliable)
- Plugin folders are self-contained and could be independently published as standalone repos
