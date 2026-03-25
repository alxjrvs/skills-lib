---
name: scram-brief
description: Context brief format reference for SCRAM — brief template, complexity tagging, resolution modes, prioritization table, and backlog format.
user_invocable: false
---

# SCRAM Brief Format Reference

This sub-skill is the canonical reference for context brief authoring in SCRAM. It is used by `scram:developer-breakdown` agents and referenced by the orchestrator during G3 story breakdown. It can also be used standalone for non-SCRAM brief generation.

## Context Brief Format

For each story, write a brief to `SCRAM_WORKSPACE/briefs/<story-slug>.md`:

> The canonical brief template is at `${CLAUDE_PLUGIN_ROOT}/refs/brief-template.md`. Agents and orchestrators read the template from disk when authoring briefs.

**Brief review rule:** Reject briefs that contain line-number locators. They must use content-anchored references only. Never use locators of the form `line \d+`, `:\d+$`, or `L\d+`.

## Story Sizing

Each story should touch **no more than 3-5 files** (excluding tests), completable in a single focused session. Prefer **vertical slices** over horizontal slices. Stories must be independent — minimize cross-story dependencies. **If in doubt, split.**

## Complexity Tagging

Each story gets a complexity tag that determines the agent model:

| Complexity | Model | When |
|-----------|-------|------|
| Simple | sonnet | Clear pattern, few files, context brief covers everything |
| Moderate | sonnet | Some judgment needed, moderate file scope |
| Complex | opus | Cross-cutting, architectural judgment, ambiguous requirements |

## Resolution Mode Tagging

Each story gets a resolution mode:

| Mode | When | Handling |
|------|------|----------|
| `commit` | Story produces code/doc changes | Normal dev dispatch with worktree isolation |
| `verify-only` | Story requires only verifying acceptance criteria are already met | Orchestrator handles directly — no dev dispatch, no worktree. Check criteria, update tracker, record in backlog with no commit hash. |
| `conditional` | Story may or may not require changes depending on current state | Dev dispatched to investigate; may resolve as `verify-only` if criteria already met |

## UI/UX Story Tagging (when designer is active)

If a designer is on the team, flag any story that touches user-facing elements (GUI, TUI, CLI output, interactive prompts). These stories require designer approval during the merge stream in addition to standard maintainer approval(s). The designer also contributes design context to these stories' context briefs.

## Prioritization Table

| Priority | Meaning |
|----------|---------|
| P0 — Critical | Blocks other stories, touches shared interfaces/types; do first |
| P1 — High | Core feature work; pick next |
| P2 — Normal | Independent work, no blockers |
| P3 — Low | Nice-to-have, polish, edge cases |

**P0 stories run first as a separate wave** with a quality gate before P1+ begins. This gates complex work on a proven baseline.

## Backlog File Format

Write the backlog to `SCRAM_WORKSPACE/backlog.md`:

```markdown
# SCRAM Backlog — <feature-name>

| # | Story | Priority | Complexity | Resolution | Depends On | UI/UX | Status | Agent | Commit |
|---|-------|----------|------------|------------|------------|-------|--------|-------|--------|
| 1 | Story A | P0 | simple | commit | — | no | pending | — | — |
| 2 | Story B | P0 | complex | commit | — | no | pending | — | — |
| 3 | Story C | P1 | moderate | commit | 1, 2 | yes | pending | — | — |
| 4 | Story D | P2 | simple | verify-only | — | no | pending | — | — |
```

**Status values:** `pending` → `in_progress` → `in_review` → `merged` | `failed` → `escalated` → `in_progress`

Maintainers update this file as stories progress.
