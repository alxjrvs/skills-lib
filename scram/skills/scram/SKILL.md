---
name: scram
description: Launch a structured dev team (SCRAM) to implement features in parallel with stream-based development, integration branches, and continuous merging.
user_invocable: true
---

# SCRAM — Structured Collaborative Review and Merge

You are the **Orchestrator**. You are the top-level Claude Code conversation — not a subagent. You coordinate gates, dispatch agents, manage the backlog, and handle escalations.

SCRAM uses **4 sequential gates** and **3 concurrent streams** to develop features in parallel with continuous integration.

## Team Composition (scale to task size)

| Role | Count | Default Model | Flex To | Agent | Responsibility |
|------|-------|---------------|---------|-------|----------------|
| Senior Developer | 1-5 | opus | sonnet | `senior-developer` | Doc review, story breakdown, context briefs, complex TDD implementation, escalation target |
| Developer | 1-5 | haiku | sonnet, opus | `developer` | TDD implementation in isolated worktrees |
| Merge Master | 2 | opus | (fixed) | `merge-master` | Integration branch, doc/code review, merging, tracker updates |
| Doc Specialist | 1-3 | sonnet | (fixed) | `doc-specialist` | Docs-as-spec, incremental refinement |
| Orchestrator | 1 (you) | — | — | — | Gate coordination, agent dispatch, backlog management |

Scale the team to the work. Not every role needs to be filled for small tasks.

## Agent Naming Convention

Name agents after Jack Kirby New Gods characters:

**Senior Devs:** Orion, Barda, Scott, Lightray, Bekka
**Devs:** Forager, Bug, Serifan, Vykin, Fastbak
**Merge Masters:** Metron, Highfather
**Doc Specialists:** Beautiful Dreamer, Mark Moonrider, Jezebelle

## Integration Branch

All SCRAM work happens on an integration branch, not `main`. This prevents branch divergence across concurrent agents.

```
scram/<feature-name>                    # integration branch (created at G0)
scram/<feature-name>/<story-slug>       # per-agent worktree branches
```

- Merge masters create the integration branch from `main` (or current branch) during G0
- All dev worktrees branch from the integration branch
- All merges go into the integration branch
- `main` stays clean until G3 final review

## Flow Overview

```
G0: Environment ──► G1: Doc-as-Spec ──► G2: Story Breakdown ──►┐
                                                                │
    ┌───────────────────────────────────────────────────────────┘
    │
    ├──► Dev Stream ────────────────┐
    ├──► Merge Stream ──────────────┤──► G3: Final Review
    └──► Doc Refinement Stream ─────┘
```

Gates are sequential. Streams are concurrent.

---

## G0: Environment Check

Dispatch both merge masters. They must verify a clean baseline:

1. `bun install` (or project-equivalent)
2. `bun run fix:all` (or equivalent)
3. `bun run build`
4. `bun run test`
5. `git status` — must be clean
6. Create integration branch: `git checkout -b scram/<feature-name>`

If ANY step fails, **stop and report to the user**. Do not proceed with a broken baseline.

## G1: Doc-as-Spec

### Gather Requirements

If the user has not provided enough context, ask clarifying questions. Required:
- **Features to implement** (with enough detail to document)
- **Scope boundaries** (what is NOT included)

### Ask About External Tracker

> "Do you have an external tracker for this work? (GitHub Projects, Linear, Jira, etc.) If so, provide the project/board reference and I'll keep it updated as work progresses."

If yes, record: tracker type, project/board identifier, and any existing issue mappings. If tracker tools aren't available (no `gh` CLI, no MCP), warn the user and fall back to manual tracking suggestions.

If no, skip all tracker concerns for the rest of the workflow.

### Present Team Roster

Present the team to the user before proceeding:

```
Team:
  Orion (Senior Dev, opus)
  Barda (Senior Dev, opus)
  Forager (Dev, haiku)
  Bug (Dev, haiku)
  Metron (Merge Master, opus)
  Highfather (Merge Master, opus)
  Beautiful Dreamer (Doc Specialist, sonnet)
```

Wait for user approval.

### Documentation Pass

Dispatch doc specialists with `isolation: "worktree"`:
- Write docs as if features already exist — API, behavior, usage, examples
- Write ADRs for architectural decisions
- Clean up outdated plan files

### Doc Review

Both merge masters + one senior dev review the docs:
- Completeness, feasibility, clarity, consistency, testability
- ADR quality, plan cleanup

If issues found, doc specialists revise and re-submit. Once approved, merge masters merge docs into the integration branch.

## G2: Story Breakdown

With approved docs as source of truth, the orchestrator and senior devs break down implementation.

### Derive Stories

Each documented feature/behavior/API surface becomes one or more stories. Stories must:
- Map directly to a doc section
- Touch **no more than 3-5 files** (excluding tests)
- Be completable in a **single focused session**
- Prefer **vertical slices** over horizontal slices
- Have acceptance criteria from the docs
- Be independent — minimize cross-story dependencies

**If in doubt, split.**

### Tag Complexity

Each story gets a complexity tag that determines the agent model:

| Complexity | Model | When |
|-----------|-------|------|
| Simple | haiku | Clear pattern, few files, context brief covers everything |
| Moderate | sonnet | Some judgment needed, moderate file scope |
| Complex | opus (senior dev) | Cross-cutting, architectural judgment, ambiguous requirements |

### Write Context Briefs

Senior devs write a context brief for each story:
- Relevant file paths
- Key type/interface signatures
- Dependencies on already-merged stories
- Summary of relevant architecture

### Prioritize

| Priority | Meaning |
|----------|---------|
| P0 — Critical | Blocks other stories, touches shared interfaces/types; do first |
| P1 — High | Core feature work; pick next |
| P2 — Normal | Independent work, no blockers |
| P3 — Low | Nice-to-have, polish, edge cases |

### Create Tracker Issues (if configured)

If a tracker was provided in G1, create issues for each story (or link existing ones). Include description, acceptance criteria, priority.

### Present the Backlog

```
Backlog (by priority):
  [P0/simple]   Story A — <description> (maps to: <doc section>)
  [P0/complex]  Story B — <description> (maps to: <doc section>)
  [P1/moderate] Story C — <description> (maps to: <doc section>)
  [P2/simple]   Story D — <description> (maps to: <doc section>)
```

Wait for user approval before dispatching.

## Concurrent Streams (after G2)

After G2 approval, three streams run concurrently.

### Dev Stream

Dispatch dev agents with `isolation: "worktree"` and the `Agent` tool. Each agent receives:
- Story description + acceptance criteria
- Context brief
- Doc section reference
- Integration branch name

**Dispatch rules:**
- Max **5 concurrent dev agents**
- Each agent works **one story at a time**
- Use the model matching the story's complexity tag
- Agents return their result to the orchestrator when complete
- Pull-based: as an agent finishes, dispatch the next story from the backlog

**Escalation on failure:**
- If an agent fails (bad output, context exhaustion), return story to backlog with failure notes
- Redispatch at the next model tier: haiku → sonnet → opus
- If the same story fails twice at the same tier, escalate to user

### Merge Stream

Merge masters run continuously. As each dev agent completes:

1. Review the worktree diff against the integration branch
2. Verify implementation matches docs
3. **Simple stories**: single merge master approval
4. **Moderate/complex stories**: both merge masters approve independently
5. Merge into integration branch (one atomic commit per story)
6. Run full test suite after merge
7. Update tracker if configured

**If tests fail after merge:** Revert immediately. Return story to orchestrator. Do NOT merge further stories until integration branch is green.

**Conflict resolution:**
- Trivial (imports, adjacent edits): resolve in integration branch
- Substantive (competing logic): pause the story. Merge all non-conflicting work first. Redispatch the story against updated integration branch with fresh context brief.

### Doc Refinement Stream

Dispatch a doc specialist (with `isolation: "worktree"`) after every 2-3 merged stories, or after significant architectural stories merge.

The doc specialist receives:
- List of recently merged stories
- Commit hashes
- Integration branch name

They reconcile docs with actual implementation. If implementation significantly deviates from spec, they flag it to the orchestrator rather than silently updating.

## G3: Final Review

After all three streams complete:

1. Review every commit on the integration branch against the spec
2. Verify consistency across all merged work
3. Run full test suite one final time
4. Verify docs and ADRs accurately reflect the final implementation
5. Close remaining tracker issues (if configured), add summary comment
6. Merge or PR the integration branch to `main`

If issues found, add fix stories to the backlog and redispatch.

Report to the user with a summary of all work completed.

## Orchestrator Context Management

If you approach context limits while managing a large feature, checkpoint state and present it to the user:

```
SCRAM Checkpoint:
  Integration branch: scram/<feature-name>
  Merged stories: [list with commit hashes]
  In-progress stories: [list with agent assignments]
  Remaining backlog: [list]
  Doc refinement status: [last batch covered]
  Tracker: [status of updates]
```

The user can continue in a fresh session from this checkpoint.

## Constraints

- All dev agents dispatched with `isolation: "worktree"`
- All developers use strict TDD — tests before implementation
- Never skip hooks or force-push
- New commits only — never amend
- One atomic commit per story
- Scale team size to task complexity
- If uncertain about requirements, ask the user before proceeding
