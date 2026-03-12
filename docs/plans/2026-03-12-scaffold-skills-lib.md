# Skills-Lib Scaffold Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Scaffold `alxjrvs/skills-lib` as a valid Claude Code plugin marketplace with one local plugin (`claude-tmux-status`) and a `CLAUDE.md`.

**Architecture:** A GitHub-hosted marketplace with `.claude-plugin/marketplace.json` as the catalog. Local plugins live as root-level folders, each self-contained with their own `plugin.json` (strict mode). External plugins are referenced by GitHub source in the catalog only.

**Tech Stack:** Claude Code plugin format, JSON, Markdown

---

### Task 1: Initialize the repo

**Files:**
- Create: `README.md`
- Create: `.gitignore`

**Step 1: Initialize git**

```bash
cd /Users/jarvis/Code/JrvsSkills
git init
git branch -m main
```

Expected: `Initialized empty Git repository in .../JrvsSkills/.git/`

**Step 2: Create `.gitignore`**

```
.DS_Store
```

**Step 3: Create `README.md`**

```markdown
# skills-lib

Personal Claude Code plugin marketplace.

## Install

```
/plugin marketplace add alxjrvs/skills-lib
```

## Install a plugin

```
/plugin install <plugin-name>@jrvs-skills
```
```

**Step 4: Commit**

```bash
git add .gitignore README.md
git commit -m "chore: init repo"
```

---

### Task 2: Create the marketplace catalog

**Files:**
- Create: `.claude-plugin/marketplace.json`

**Step 1: Create the directory and file**

```bash
mkdir -p .claude-plugin
```

`.claude-plugin/marketplace.json`:

```json
{
  "name": "jrvs-skills",
  "owner": {
    "name": "alxjrvs"
  },
  "metadata": {
    "description": "alxjrvs personal Claude Code plugin marketplace"
  },
  "plugins": []
}
```

**Step 2: Validate the marketplace**

```bash
claude plugin validate .
```

Expected: validation passes with a warning about no plugins defined (that's fine for now).

**Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: add marketplace catalog"
```

---

### Task 3: Scaffold the `claude-tmux-status` plugin

**Files:**
- Create: `claude-tmux-status/.claude-plugin/plugin.json`
- Create: `claude-tmux-status/skills/claude-tmux-status/SKILL.md`

**Step 1: Create the plugin directory structure**

```bash
mkdir -p claude-tmux-status/.claude-plugin
mkdir -p claude-tmux-status/skills/claude-tmux-status
```

**Step 2: Create `plugin.json`**

`claude-tmux-status/.claude-plugin/plugin.json`:

```json
{
  "name": "claude-tmux-status",
  "version": "1.0.0",
  "description": "Tmux status bar integration for Claude Code"
}
```

**Step 3: Create the skill stub**

`claude-tmux-status/skills/claude-tmux-status/SKILL.md`:

```markdown
---
description: Configure Claude Code tmux status bar integration
---

TODO: implement skill content.
```

**Step 4: Validate the plugin**

```bash
claude plugin validate ./claude-tmux-status
```

Expected: passes validation.

**Step 5: Commit**

```bash
git add claude-tmux-status/
git commit -m "feat: scaffold claude-tmux-status plugin"
```

---

### Task 4: Register `claude-tmux-status` in the marketplace

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Add the plugin entry**

Update `.claude-plugin/marketplace.json`:

```json
{
  "name": "jrvs-skills",
  "owner": {
    "name": "alxjrvs"
  },
  "metadata": {
    "description": "alxjrvs personal Claude Code plugin marketplace"
  },
  "plugins": [
    {
      "name": "claude-tmux-status",
      "source": "./claude-tmux-status",
      "description": "Tmux status bar integration for Claude Code"
    }
  ]
}
```

**Step 2: Validate the full marketplace**

```bash
claude plugin validate .
```

Expected: passes with no warnings.

**Step 3: Test install locally**

```bash
/plugin marketplace add ./
/plugin install claude-tmux-status@jrvs-skills
```

Expected: plugin installs successfully.

**Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: register claude-tmux-status in marketplace"
```

---

### Task 5: Create CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

**Step 1: Create `CLAUDE.md`**

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal Claude Code plugin marketplace hosted at `alxjrvs/skills-lib`. Users install via:

```
/plugin marketplace add alxjrvs/skills-lib
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
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md"
```

---

### Task 6: Push to GitHub

**Step 1: Create the repo and push**

```bash
gh repo create alxjrvs/skills-lib --public --source=. --remote=origin --push
```

Expected: repo created at `https://github.com/alxjrvs/skills-lib`

**Step 2: Verify marketplace is installable**

```bash
/plugin marketplace add alxjrvs/skills-lib
```

Expected: marketplace added successfully.
