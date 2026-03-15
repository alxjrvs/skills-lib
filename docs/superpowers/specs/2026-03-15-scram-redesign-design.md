# SCRAM Redesign — Stream-Based Parallel Development

**Date:** 2026-03-15
**Status:** Approved

## Overview

Redesign the `dev-team` plugin into `scram` — a stream-based parallel development orchestrator. Key changes: full rename, integration branch strategy, concurrent streams replacing sequential phases, external tracker integration, tight story sizing for context management, model scaling, and explicit failure/recovery protocols.

## 1. Plugin Rename & Structure

Rename `dev-team/` to `scram/`. All references update.

```
scram/
├── .claude-plugin/
│   └── plugin.json       # name: "scram"
├── agents/
│   ├── developer.md
│   ├── doc-specialist.md
│   ├── merge-master.md
│   └── senior-developer.md
├── skills/
│   └── scram/
│       └── SKILL.md
└── scripts/
```

The `scripts/` directory is reserved for future use (e.g., worktree cleanup helpers). Omit if not needed.

Marketplace entry:
```json
{
  "name": "scram",
  "source": "./scram",
  "description": "SCRAM — Structured Collaborative Review and Merge with stream-based parallel development"
}
```

The skill remains invocable as `/scram`. Agent filenames stay the same.

### Migration

This is a breaking rename. Update `marketplace.json` to replace the `dev-team` entry with `scram`. Delete the old `dev-team/` directory. Users who installed `dev-team` must reinstall as `scram`.

## 2. Integration Branch Strategy

Before any agent work, the merge masters create an integration branch during G0:

```
scram/<feature-name>
```

### Rules

- Created from `main` (or current branch) during G0
- ALL dev agent worktrees branch off the integration branch, not `main`
- Each dev agent's worktree gets a sub-branch: `scram/<feature-name>/<story-slug>`
- Merge masters merge completed work INTO the integration branch continuously
- After each merge, merge masters run the full test suite
- When all work is done and final review passes, the integration branch is merged/PR'd to `main`

### Why This Solves Divergence

- All agents share a common base — the integration branch tip at dispatch time
- Merge conflicts are contained to the integration branch
- Later-dispatched agents can branch from the latest integration branch tip
- `main` stays clean until everything is verified

### Recovery on Conflict

- Merge master resolves trivial conflicts (import ordering, adjacent edits) in the integration branch
- Substantive conflicts (competing logic): merge master pauses the conflicting story. All non-conflicting work merges first. Orchestrator then redispatches the conflicting story against the updated integration branch with a fresh context brief reflecting merged changes.
- If a merge breaks tests: merge master reverts, story goes back to dev with failure details

## 3. Stream-Based Flow

Replace the 8-phase sequential model with **4 gates + 3 concurrent streams**.

**The orchestrator** is the top-level Claude Code conversation running the `/scram` skill. It is not a subagent. It coordinates gates, dispatches agents, and manages the backlog.

### Gates (sequential checkpoints)

| Gate | What Happens | Who |
|------|-------------|-----|
| **G0: Environment** | `bun install`, `fix:all`, `build`, `test`, clean git status. Create integration branch. | Merge masters |
| **G1: Doc-as-Spec** | Gather requirements, break down features, doc specialists write docs + ADRs in worktrees. Senior devs + merge masters review. Merge approved docs into integration branch. Orchestrator asks about external tracker (see Section 4). | All |
| **G2: Story Breakdown** | Derive stories from approved docs. Size small (Section 5). Tag complexity (simple/moderate/complex). Prioritize P0-P3. If tracker provided, create/link issues. Present backlog for user approval. | Orchestrator + senior devs |
| **G3: Final Review** | After all streams complete: orchestrator reviews every commit, consistency, regressions, doc accuracy. Integration branch merged/PR'd to main. Close remaining tracker issues. | Orchestrator |

### Streams (concurrent, run after G2)

**Dev Stream** — Dev agents pull stories from the backlog, implement with TDD in worktrees branched from the integration branch. Each agent works one story at a time. Dev agents are dispatched via the `Agent` tool with `isolation: "worktree"`. When complete, the agent returns its result to the orchestrator, which then triggers merge stream review.

**Merge Stream** — Merge masters run continuously. As each dev completes, they review the diff, verify tests, merge into the integration branch (one atomic commit per story), run full test suite, and update the tracker if configured. If a merge breaks something, they revert and redispatch. For **simple** stories, a single merge master may approve. For **moderate** and **complex** stories, both merge masters must independently approve. This prevents dual-approval from bottlenecking throughput on straightforward work.

**Doc Refinement Stream** — The orchestrator dispatches a doc specialist after each batch of merges (every 2-3 stories, or after significant architectural stories merge). The doc specialist receives a list of merged stories and their commit hashes. They reconcile docs with actual implementation, amend ADRs if architectural decisions changed. Stream completes after the last story merges and all docs are reconciled.

All three streams overlap. A dev implements story 4 while merge masters review story 2 while doc specialists refine docs based on merged story 1.

## 4. Tracker Integration

During G1, the orchestrator asks:

> "Do you have an external tracker for this work? (GitHub Projects, Linear, Jira, etc.) If so, provide the project/board reference and I'll keep it updated as work progresses."

### If No Tracker

SCRAM skips all tracker concerns. No workflow change.

### If Tracker Provided

The user supplies:
- Tracker type (GitHub Issues/Projects, Linear, Jira)
- Project/board identifier
- Optionally, mapping of existing issues to stories

**Orchestrator at G2:** Creates issues for each story (or links existing ones). Includes description, acceptance criteria, priority.

**Merge masters in Merge Stream:** After each merge, update corresponding issue — comment with commit hash, mark as "Done"/"Merged". On revert, update back to "In Progress" with details.

**Orchestrator at G3:** Close remaining open issues, add summary comment linking to final PR/merge.

### Tool Access

Relies on available MCP tools or CLI tools (`gh`, Linear MCP, etc.). If tracker tools aren't available, orchestrator warns user and falls back to manual tracking suggestions.

### Tracker Unavailable Mid-Workflow

If tracker API calls fail, merge masters log what they would have updated and continue. At G3, orchestrator presents missed updates for user to apply manually.

## 5. Story Sizing & Context Management

### Story Sizing Rules (enforced at G2)

- Touch **no more than 3-5 files** (excluding test files)
- Completable in a **single focused session** — if you can't describe implementation in a short paragraph, split it
- Prefer **vertical slices** (one narrow feature end-to-end) over horizontal slices
- Stories requiring shared interfaces/types prioritized earlier (P0) so later stories build on them

### Context Briefs

Each story assignment includes a context brief:
- Relevant file paths
- Key type/interface signatures
- Dependencies on already-merged stories
- Summary of relevant architecture

This prevents agents from burning context on exploration.

### Splitting Heuristic

Orchestrator and senior devs review each story against sizing criteria at G2. **If in doubt, split.**

### Agent Dispatch Guidance

- Max **5 concurrent dev agents** to avoid context thrashing and merge bottleneck
- Each agent works **one story at a time** — complete, report, pull next
- If context is getting tight, agent reports back with progress so far rather than pushing through

## 6. Model Scaling

Models are assigned per-agent at dispatch time based on story/task complexity.

| Role | Default | Flex To | Notes |
|------|---------|---------|-------|
| **Developer** | haiku | sonnet, opus | Promote based on story complexity tag |
| **Senior Developer** | opus | sonnet | Sonnet for straightforward review or well-patterned stories |
| **Merge Master** | opus | (fixed) | Non-negotiable — high-stakes decisions |
| **Doc Specialist** | sonnet | (fixed) | Consistent middle ground for writing |

### Complexity Tags (assigned at G2)

- **Simple** → haiku dev (clear pattern, few files, context brief covers everything)
- **Moderate** → sonnet dev (some judgment needed, moderate file scope)
- **Complex** → opus senior dev (cross-cutting, architectural judgment, ambiguous requirements)

Failed stories escalate: haiku → sonnet → opus → user.

## 7. Failure & Recovery Protocols

### Dev Agent Failure (context exhaustion, crash, bad output)

1. Merge master identifies failure during review
2. Story marked "failed," returned to backlog
3. Orchestrator redispatches to fresh agent with original context brief + failure notes
4. Same story fails twice → escalate to user

### Merge Breaks Tests

1. Merge master reverts the merge from integration branch immediately
2. Story returns to dev agent (or new one) with test failure details
3. No further merges until integration branch is green

### Merge Conflicts

- **Trivial** (import ordering, adjacent edits): merge master resolves in integration branch
- **Substantive** (competing logic): merge master pauses the story. Non-conflicting work merges first. Orchestrator redispatches against updated integration branch with fresh context brief.

### Doc-Code Divergence

1. Doc specialist flags significant deviation to orchestrator
2. Orchestrator decides: update doc to match reality, or file follow-up story

### Orchestrator Context Limits

If the orchestrator approaches context limits while managing a large feature, it checkpoints state (current backlog, stream status, integration branch name, merged/pending stories) and presents it to the user for continuation in a fresh session.

### Tracker Unavailable

1. Merge masters log missed updates, continue work
2. At G3, orchestrator presents summary for user to apply manually

## 8. Agent Updates

All agents that perform code changes (developer, senior-developer, doc-specialist) are dispatched with `isolation: "worktree"`. Merge masters operate directly on the integration branch without worktree isolation.

### developer.md (default: haiku)

- Model default haiku, scalable to sonnet/opus based on story complexity
- Dispatched with `isolation: "worktree"`
- Receives context brief with each story
- Branches from integration branch
- If context tight, report progress rather than pushing through
- No doc review responsibilities

### senior-developer.md (default: opus)

- Model default opus, scalable to sonnet
- Dispatched with `isolation: "worktree"` when implementing
- Participates in G2 story breakdown and sizing
- Branches from integration branch
- Escalation target for failed stories
- Provides context briefs during G2

### merge-master.md (opus, fixed)

- No worktree isolation — operates on integration branch directly
- Creates and maintains integration branch
- Runs full test suite after every merge
- Single approval for simple stories, dual approval for moderate/complex
- Tracker update responsibilities (if configured)
- Revert-and-redispatch on test failure
- Conflict resolution (trivial vs. substantive)
- Blocks further merges until integration branch green

### doc-specialist.md (sonnet, fixed)

- Model changes from opus to sonnet
- Dispatched with `isolation: "worktree"`
- Begins refinement incrementally as stories merge (dispatched per batch)
- Flags significant doc-code divergence to orchestrator

## 9. Team & Naming Convention

Jack Kirby New Gods characters (unchanged):

- **Senior Devs:** Orion, Barda, Scott, Lightray, Bekka
- **Devs:** Forager, Bug, Serifan, Vykin, Fastbak
- **Merge Masters:** Metron, Highfather
- **Doc Specialists:** Beautiful Dreamer, Mark Moonrider, Jezebelle

Scale team to task complexity. Not every role needs to be filled for every task.
