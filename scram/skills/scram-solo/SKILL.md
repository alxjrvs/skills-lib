---
name: scram-solo
description: Lightweight single-story SCRAM flow — one dev, one reviewer, no integration branch. Use for 1 story with no shared state changes.
user_invocable: true
---

# SCRAM Solo

You are the **Orchestrator**. Solo is a lightweight single-story SCRAM flow -- one dev, one reviewer, no integration branch, no workspace ceremony. For multi-story work or shared state changes, use `/scram-sprint`.

Solo uses the same team (New Gods characters) and the same quality discipline (TDD, code review, worktree isolation) as sprint, but strips away everything a single story doesn't need.

---

## Flow

```
Assess --> Brief --> Implement --> Review --> Merge
```

Each step completes before the next begins. No concurrent streams, no gates, no persistent maintainer team.

---

## Solo Workspace

Solo creates a minimal temp workspace for hook compatibility:

```bash
SCRAM_WORKSPACE=$(mktemp -d)/scram-solo-<story-slug>
mkdir -p "$SCRAM_WORKSPACE/briefs"
```

This directory holds only the context brief file. No `session.md`, no `backlog.md`, no `events/`. The orchestrator cleans up after merge: `rm -rf "$SCRAM_WORKSPACE"`.

This ensures all hooks that guard on `SCRAM_WORKSPACE` being set continue to function (halt-check, isolation-check, brief-lint).

---

## Step 1: Assess

Confirm the work fits solo scope. All four conditions must hold:

- **Single story** -- one deliverable, one commit
- **<=5 files** modified (excluding tests)
- **No shared state or package changes** -- no new dependencies, no schema migrations, no config changes that affect other features
- **No new architectural decisions** -- if an ADR would be warranted, use sprint

If any condition fails, recommend `/scram-sprint` instead and stop.

Ask the user to confirm the story description and scope. Gather:

- What to implement (with enough detail for acceptance criteria)
- Which files are involved
- Any constraints or dependencies

---

## Step 2: Brief

The orchestrator writes the context brief directly -- no breakdown agent dispatch.

Read the canonical brief template from `${CLAUDE_PLUGIN_ROOT}/refs/brief-template.md` and write the brief to `$SCRAM_WORKSPACE/briefs/<story-slug>.md`. Fill in every applicable section. For solo, the following sections may be left blank: `Dependencies`, `Scope Fence`, `Hook Constraint Check` (solo stories have no sibling stories to conflict with).

Present the brief to the user with acceptance criteria. Use `AskUserQuestion` to confirm:

```
AskUserQuestion:
  questions:
    - question: "Does this brief and acceptance criteria look right?"
      header: "Brief"
      options:
        - label: "Approved"
          description: "Proceed to implementation"
        - label: "Adjust"
          description: "I want to modify the acceptance criteria"
      multiSelect: false
```

If the user selects "Adjust," incorporate their feedback and re-present until approved.

Tag complexity to determine the dev agent model:

- **simple** -- sonnet (straightforward changes, clear patterns to follow)
- **moderate** -- sonnet (some judgment calls, but bounded scope)
- **complex** -- opus (novel logic, tricky edge cases, or unfamiliar patterns)

---

## Step 3: Implement

Dispatch one `scram:developer-impl` with `isolation: "worktree"`.

Solo bypasses `worktree-init.sh`. The orchestrator creates the worktree and branch directly:

```bash
git worktree add .claude/worktrees/<story-slug> -b scram/solo/<story-slug>
```

Pass to the agent:

- Story ID and slug
- SCRAM workspace path (absolute)
- Context brief file path (`$SCRAM_WORKSPACE/briefs/<story-slug>.md`)
- Source branch name (the branch to merge back into)
- Model matching the complexity tag

The agent follows TDD discipline per `${CLAUDE_PLUGIN_ROOT}/refs/tdd-discipline.md` and returns a structured Story Report per `${CLAUDE_PLUGIN_ROOT}/refs/report-formats.md`.

If the agent returns `status: failed`, assess the failure reason before deciding next steps (see Escape Hatch below).

---

## Step 4: Review

Dispatch Metron (`scram:merge-maintainer`) as a **one-shot** reviewer. Single-approval only -- no dual-maintainer, no persistent team.

Metron reads `${CLAUDE_PLUGIN_ROOT}/refs/review-checklist.md` and reviews the diff between the worktree branch and the source branch. Pass:

- Story Report from the dev agent
- Context brief file path
- Worktree branch name
- Source branch name

If **approved**, proceed to merge.

If **rejected**, redispatch the dev agent with Metron's feedback appended to the brief. The dev agent gets one retry. If the second attempt is also rejected, escalate to the user.

---

## Step 5: Merge

Metron merges to the source branch following `${CLAUDE_PLUGIN_ROOT}/refs/merge-protocol.md`:

1. Copy files from worktree to source branch working directory
2. Stage specific files only (no `git add -A`)
3. Commit with format from `${CLAUDE_PLUGIN_ROOT}/refs/commit-format.md`
4. Run full test suite
5. Remove the worktree: `git worktree remove .claude/worktrees/<story-slug>`

If tests fail after commit, revert the commit and escalate to the user.

Clean up the workspace: `rm -rf "$SCRAM_WORKSPACE"`

Report completion to the user with a summary: files changed, tests passing, commit SHA.

---

## Escape Hatch

If the dev discovers scope exceeds solo capacity mid-implementation, they report `failure_reason: scope_exceeded` in their Story Report. The orchestrator:

1. Preserves the brief and any completed work in the worktree
2. Offers to upgrade to `/scram-sprint` via `AskUserQuestion`:

```
AskUserQuestion:
  questions:
    - question: "This story exceeds solo scope. Upgrade to a full sprint?"
      header: "Scope Exceeded"
      options:
        - label: "Upgrade to sprint"
          description: "The brief becomes the first story in the sprint backlog"
        - label: "Adjust scope"
          description: "I want to narrow the story to fit solo"
        - label: "Abort"
          description: "Cancel the run entirely"
      multiSelect: false
```

3. If upgrading, the existing brief is copied into the sprint workspace as the first backlog entry. The worktree is cleaned up (sprint will create its own).

---

## Constraints

- **Worktree isolation is non-negotiable** -- even for simple stories. Never work directly on the source branch.
- **TDD discipline applies** -- read `${CLAUDE_PLUGIN_ROOT}/refs/tdd-discipline.md`. Tests before implementation.
- **Code review always required** -- a SCRAM run without review is not a SCRAM run.
- **Never skip hooks or force-push.**
- **New commits only** -- never amend.
- **One atomic commit per story.**
