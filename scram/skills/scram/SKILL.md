---
name: scram
description: Launch a structured dev team (SCRAM) to implement features in parallel with stream-based development, integration branches, and continuous merging.
user_invocable: true
---

# SCRAM — Structured Collaborative Review and Merge

You are the **Orchestrator**. You are the top-level Claude Code conversation — not a subagent. You run sequential gates, execute Agent tool calls on behalf of maintainers during streams, and report progress to the user. You have **no decision-making role** within the concurrent streams — the merge maintainer and code maintainer coordinate dispatch, review, escalation, and backlog management.

SCRAM uses **5 sequential gates** (plus an optional retrospective) and **3 concurrent streams** to develop features in parallel with continuous integration. The dev stream enforces strict **Red-Green-Refactor** TDD discipline.

## Team Composition (scale to task size)

| Role | Count | Default Model | Flex To | Agent (`subagent_type`) | Responsibility |
|------|-------|---------------|---------|-------------------------|----------------|
| Developer (Reviewer) | 1-3 | sonnet | (fixed) | `scram:developer-reviewer` | G1 ADR review, G2 doc review |
| Developer (Breakdown) | 1-3 | sonnet | (fixed) | `scram:developer-breakdown` | G3 story sizing, context brief authoring |
| Developer (Impl) | 1-5 | sonnet | opus | `scram:developer-impl` | TDD implementation, escalation handling (max 5) |
| Merge Maintainer | 1 | sonnet | (fixed) | `scram:merge-maintainer` | Line-level code review, story strictness, TDD discipline, scope enforcement |
| Code Maintainer | 1 | sonnet | (fixed) | `scram:code-maintainer` | Structural harmony, DRYness, codebase-wide patterns, architectural drift |
| Doc Specialist | 1-3 | sonnet | (fixed) | `scram:doc-specialist` | ADR authoring, docs-as-spec, incremental refinement (max 3, spun up as needed) |
| Designer | 0-3 | sonnet | opus | `scram:designer` | Design ADRs, required UI/UX merge approver (optional, max 3, spun up as needed) |
| Dev Tooling Maintainer | 0-1 | sonnet | (fixed) | `scram:dev-tooling-maintainer` | CI/CD, build systems, agentic integrations, DX (optional role) |
| Orchestrator | 1 (you) | — | — | — | Gate coordination, agent dispatch on behalf of merge maintainers, reporting to user |

**Important:** When dispatching agents via the `Agent` tool, always use the `scram:` prefix in `subagent_type` (e.g., `subagent_type: "scram:developer-impl"`). This ensures the correct plugin agent definitions are used.

Scale the team to the work. Not every role needs to be filled for small tasks.

**Docs-only runs (`run_type: docs`):** Skip the code maintainer role entirely — there is no code to review for structural harmony. The merge maintainer gets sole approval authority for all stories. The developer report format replaces "TDD discipline" with "Verification method" (accepts: `build_passes | lint_passes | manual_diff | none`).

## Agent Naming Convention

Name agents after Jack Kirby New Gods characters:

**Devs (impl):** Orion, Barda, Scott, Lightray, Bekka, Forager, Bug, Serifan, Vykin, Fastbak
**Devs (reviewer):** Use the same name pool — a reviewer is a developer in a different mode
**Devs (breakdown):** Use the same name pool
**Merge Maintainer:** Metron
**Code Maintainer:** Highfather
**Doc Specialists:** Beautiful Dreamer, Mark Moonrider, Jezebelle
**Designers:** Esak
**Dev Tooling Maintainers:** Himon

## Integration Branch

All SCRAM work happens on an integration branch, not `main`. This prevents branch divergence across concurrent agents.

```
scram/<feature-name>                    # integration branch (created at G0)
scram/<feature-name>/<story-slug>       # per-agent worktree branches
```

- Merge maintainers create the integration branch from `main` (or current branch) during G0
- All dev worktrees branch from the integration branch
- All merges go into the integration branch
- `main` stays clean until G4 final review

## SCRAM Workspace

SCRAM persists state in a **global workspace directory** outside the project repo, ensuring zero contamination of the project's git history. Workspaces are **isolated per invocation** to prevent context bleed between concurrent SCRAM runs.

```
~/.scram/
└── <project-dir>--<feature-name>--<invocation-id>/
    ├── session.md              # session manifest — resume state
    ├── backlog.md              # tracked backlog with story status
    ├── briefs/
    │   └── <story-slug>.md     # context brief per story
    ├── retro/                  # retrospective artifacts (G5, if enabled)
    │   ├── in-flight.md        # appended during streams; read by retro facilitator at G5
    │   ├── tickets/
    │   │   ├── metron.md
    │   │   └── highfather.md
    │   └── discussions/
    │       └── <topic-slug>.md # consensus discussion outputs
    └── events/
    │   └── stream.log          # checkpoint event log — one JSON line per Stop hook invocation
```

**Workspace path construction** (at G0):
1. `<project-dir>` — the basename of the project's working directory (e.g., `my-app`)
2. `<feature-name>` — the feature name from the integration branch (e.g., `auth-system`)
3. `<invocation-id>` — a short timestamp: `YYYYMMDD-HHMMSS` (e.g., `20260316-143022`)

Example: `~/.scram/my-app--auth-system--20260316-143022/`

The workspace path is determined at G0 and passed to all agents as an **absolute path**. Refer to it as `SCRAM_WORKSPACE` throughout this document.

- **Backlog** (`SCRAM_WORKSPACE/backlog.md`) — the single source of truth for story status. Created at G3, updated by maintainers as stories complete, fail, or escalate. Survives context limits.
- **Context briefs** (`SCRAM_WORKSPACE/briefs/<story-slug>.md`) — written by devs at G3. Dev agents read these from disk rather than receiving them inline. Persistent across retries and escalation.
- **Retro** (`SCRAM_WORKSPACE/retro/`) — retrospective artifacts, created at G5 if enabled.
- **Session manifest** (`SCRAM_WORKSPACE/session.md`) — all state needed to resume a SCRAM run in a new conversation. Updated after every gate transition and after every story merge.

The workspace is cleaned up at the user's discretion after the SCRAM run. The orchestrator reports the workspace path in the final summary.

**Resuming a session:** Read `session.md` to restore state. Also read the last 5 lines of `events/stream.log` (if it exists) to understand the most recent activity before context was lost. This gives a mechanical checkpoint trace that supplements the prose state in `session.md`.

### Session Manifest

The session manifest (`SCRAM_WORKSPACE/session.md`) is the single file needed to resume a SCRAM run. It is written at G0 and **updated after every gate transition and every story merge**. Format:

```markdown
---
project: <absolute project path>
feature: <feature-name>
integration_branch: scram/<feature-name>
workspace: <absolute SCRAM_WORKSPACE path>
current_gate: G0 | G1 | G2 | G3 | streams | G4 | G5 | complete
run_type: code | docs | mixed
retrospective: pending | true | false
# retrospective transitions: set to "pending" at G0; resolve to "true" (opted in) or "false" (opted out) at G4 after the user prompt; never resolve during the stream phase
prior_brainstorm: <absolute path to brainstorm workspace, or "none">
scram_version: <semver string read from scram/.claude-plugin/plugin.json at G0, e.g. "6.1.0">
compressed_gates: <comma-separated list of skipped gates, e.g. "G1, G2", or "none">
tracker: <tracker config or "none">
created: <YYYY-MM-DD HH:MM:SS>
updated: <YYYY-MM-DD HH:MM:SS>
---

# SCRAM Session — <feature-name>

## Team

| Name | Role | Agent | Model |
|------|------|-------|-------|
| <name> | <role> | <agent type> | <model> |

Example:
| Name | Role | Agent | Model |
|------|------|-------|-------|
| Orion | Dev | developer | sonnet |
| Barda | Dev | developer | sonnet |
| Forager | Dev | developer | sonnet |
| Bug | Dev | developer | sonnet |
| Metron | Merge Maintainer | merge-maintainer | sonnet |
| Highfather | Code Maintainer | code-maintainer | sonnet |
| Beautiful Dreamer | Doc Specialist | doc-specialist | sonnet |
| Mark Moonrider | Doc Specialist | doc-specialist | sonnet |
| Esak | Designer | designer | sonnet |

Record the exact team as approved by the user. On resume, redispatch agents with the same names, roles, and models.

## Current State
<what has been completed, what is in progress, what remains>

## Merged Stories
- <commit hash> — <story title>

## In-Progress Stories
- <story title> — <agent name> (<status>)

## Escalations
- <story title> — <failure reason> — <current tier>

## Notes
<any context the next orchestrator session needs>
```

### Saving Memory References

After writing or updating the session manifest, **save a memory reference** so future conversations can discover it:

Write a memory file to the project's memory directory with type `project`:

```markdown
---
name: scram-session-<feature-name>
description: Active SCRAM session for <feature-name> — workspace at <SCRAM_WORKSPACE path>
type: project
---

Active SCRAM run for feature "<feature-name>".
**Workspace:** <SCRAM_WORKSPACE absolute path>
**Integration branch:** scram/<feature-name>
**Current gate:** <gate>
**Last updated:** <timestamp>

**How to apply:** When the user mentions resuming SCRAM work on this feature, read `session.md` from the workspace path above and resume from the recorded gate.
```

Update this memory each time the session manifest is updated. Remove it when the SCRAM run completes (G4/G5 done).

## Flow Overview

```
G0: Environment ──► G1: ADRs ──► G2: User-Facing Docs ──► G3: Story Breakdown ──►┐
                                                                                   │
    ┌──────────────────────────────────────────────────────────────────────────────┘
    │
    ├──► Dev Stream (RED → GREEN → REFACTOR) ──┐
    ├──► Merge Stream ─────────────────────────┤──► G4: Final Review ──► [G5: Retrospective]
    └──► Doc Refinement Stream ────────────────┘
```

Gates are sequential. Streams are concurrent. Dev work enforces Red-Green-Refactor per story. G5 is optional.

---

## G0: Environment Check

### Check for Existing Sessions

Before starting a new run, check for existing SCRAM workspaces for this project:

```bash
ls -d ~/.scram/$(basename "$PWD")--* 2>/dev/null
```

Also check memory for any `scram-session-*` references.

If existing workspaces are found, present them to the user:

```
Existing SCRAM sessions found for this project:
  1. ~/.scram/my-app--auth-system--20260315-100000/ (gate: streams, last updated: 2026-03-15 14:30)
  2. ~/.scram/my-app--api-routes--20260310-090000/ (gate: complete, last updated: 2026-03-12 16:00)

Resume an existing session, or start fresh?
```

**If resuming:** Read `session.md` from the selected workspace. Set `SCRAM_WORKSPACE` to that path. Check the integration branch still exists (`git branch --list`). Skip to the recorded `current_gate` — all prior gate work is already done. Update the session manifest's `updated` timestamp.

**If starting fresh:** Continue with the new session flow below.

### New Session Setup

**Stash check precondition:** Before creating the integration branch or workspace, verify no stashes exist:
```bash
git stash list
```
If stashes exist, stop and notify the user. Do not proceed until the user explicitly clears or acknowledges existing stashes. Starting a SCRAM run with stashes present risks accidental loss during G4 teardown.

Read `scram_version` from `scram/.claude-plugin/plugin.json` (the `"version"` field) and include it in the session manifest frontmatter.

Both maintainers run environment checks and create the integration branch per their agent definitions. The orchestrator creates the SCRAM workspace using `scram-init.sh` and writes the session manifest.

**Gate-boundary events:** Write a JSON event to `SCRAM_WORKSPACE/events/stream.log` at each gate transition:
```bash
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"gate\",\"gate\":\"G1\"}" >> "$SCRAM_WORKSPACE/events/stream.log"
```
The `session-checkpoint.sh` Stop hook appends checkpoint events automatically between gate transitions.

### Gather Requirements

If the user has not provided enough context, ask clarifying questions. Required:
- **Features to implement** (with enough detail to document)
- **Scope boundaries** (what is NOT included)

### Check for Prior Scramstorm

Use `AskUserQuestion` to determine if this session originated from a brainstorm:

```
AskUserQuestion:
  questions:
    - question: "Did this work come from a prior scramstorm?"
      header: "Scramstorm Handoff"
      options:
        - label: "Yes"
          description: "Import brainstorm results — may allow skipping G1/G2"
        - label: "No"
          description: "Start fresh — normal G0 flow"
      multiSelect: false
```

**If yes**, follow this numbered handoff processing sequence exactly:

1. **Read manifest** — Ask the user for the brainstorm workspace path (or scan `~/.scram/brainstorm--$(basename "$PWD")--*` for recent workspaces). Read `handoff.md` from the brainstorm workspace.
2. **Display gate eligibility** — Show the user which gates the brainstorm marked as skippable:
   ```
   Scramstorm handoff detected:
     Workspace: <brainstorm_workspace>
     Winning option: <winning_option or "exploration (no single winner)">
     G1 (ADRs) skip eligible: <yes/no>
     G2 (Docs) skip eligible: <yes/no>
     Briefs available: <count>
   ```
3. **Confirm each skip** — For each eligible gate, use `AskUserQuestion` to confirm the skip. Do not auto-skip; the user must approve each gate compression individually.
4. **Copy stub briefs** — If the manifest lists briefs, copy them into `SCRAM_WORKSPACE/briefs/`. These serve as starting points for G3 story breakdown — devs refine them, not rewrite from scratch.
5. **Set current_gate** — Advance `current_gate` in `session.md` to the first non-skipped gate.
6. **Record in session.md** — Add `prior_brainstorm` and `compressed_gates` to the session manifest frontmatter (see Session Manifest format below).

**If no**, continue with normal G0 flow.

### Ask About External Tracker

Use `AskUserQuestion` to gather tracker preference:

```
AskUserQuestion:
  questions:
    - question: "Do you have an external tracker for this work?"
      header: "Tracker"
      options:
        - label: "No tracker"
          description: "Track stories in the SCRAM backlog only"
        - label: "GitHub Issues"
          description: "Create and update issues on a GitHub repo"
        - label: "Linear"
          description: "Sync stories to a Linear project"
        - label: "Jira"
          description: "Sync stories to a Jira board"
      multiSelect: false
```

If tracker is selected, ask for the project/board reference. If tracker tools aren't available (no `gh` CLI, no MCP), warn the user and fall back to manual tracking suggestions.

### Assess Session Tier

Evaluate the scope to determine the session tier:

| Tier | Criteria | Team |
|------|----------|------|
| **Full** | 4+ stories, moderate/complex complexity, shared package changes, or new abstractions | Full team with persistent maintainer team |
| **Lightweight** | ≤3 stories, all simple or verify-only, no shared package changes, no new abstractions | Single maintainer, no persistent team needed |
| **Quick** | 1 story, verify-only or trivially isolated, no new files, no shared state changes | Orchestrator handles directly — no dev dispatch, no maintainer team |
| **Nano** | 1 story, ≤2 files modified, no new abstractions, no concurrent streams | Abbreviated flow: G0 preconditions + single one-shot dev + G4 review only |

**Quick tier:** The orchestrator directly verifies acceptance criteria (no dev dispatch). Record outcome in `session.md` with an inline checklist:
- [ ] Criteria verified: <specific AC>
- [ ] No changes required OR changes confirmed in-place
- [ ] Session manifest updated

**Nano tier:** G1/G2/G3 are skipped by default. Use `scram/nano/<story-slug>` as the feature branch (no separate integration branch). Dispatch a single `scram:developer-impl` one-shot. G4 review is always required (never skip). If scope exceeds ≤2 files mid-run, escalate to Lightweight — write the escalation to `session.md` and ask the user before continuing.

**Nano workspace:** `scram-init.sh --nano` (or manual) creates a minimal workspace: `session.md` and `events/` only. No `briefs/` or `retro/` directories needed for Nano.

For lightweight sessions, a single maintainer handles review. The orchestrator **must not merge directly** — even lightweight sessions require an explicit review checklist:
- [ ] Acceptance criteria checked against story brief
- [ ] Diff reviewed for scope compliance
- [ ] Tests/build passing after merge

Record the checklist outcome in `session.md`. A SCRAM run without a merge review is not a SCRAM run.

**Process discipline:** Gates and role assignments apply to all SCRAM runs regardless of content type, perceived simplicity, or time pressure. If full SCRAM is disproportionate for the scope, use a different process — not a degraded SCRAM.

### Gate-Skip Criteria

Gates may be skipped when their purpose is not served by the session scope. Skipping must be noted in `session.md` with a brief rationale — making it auditable.

| Gate | May Skip When |
|------|--------------|
| G1 (ADRs) | No new architectural decisions — no new dependencies, schema changes, or abstractions |
| G2 (Docs) | No user-facing documentation added or changed |
| G3 (Breakdown) | Stories are already defined with briefs (e.g., from a prior scramstorm or external tracker) |

**Never skip G0 or G4.** Environment validation and final review are always required.

### Present Team Roster

**Always display the team roster as plain text first**, then ask for confirmation. The user must see the full composition before approving.

```
Team:
  Orion (Dev, sonnet)
  Barda (Dev, sonnet)
  Forager (Dev, sonnet)
  Bug (Dev, sonnet)
  Metron (Merge Maintainer, sonnet)
  Highfather (Code Maintainer, sonnet)
  Beautiful Dreamer (Doc Specialist, sonnet)
  Mark Moonrider (Doc Specialist, sonnet)
  Esak (Designer, sonnet) [optional — include if feature has UI/UX]
  Himon (Dev Tooling, sonnet) [optional — include if feature touches CI/CD, build, or DX]
```

Then use `AskUserQuestion` to confirm:

```
AskUserQuestion:
  questions:
    - question: "Does this team roster look right?"
      header: "Team"
      options:
        - label: "Approved"
          description: "Proceed with this team"
        - label: "Adjust"
          description: "I want to change the team composition"
      multiSelect: false
```

## G1: ADRs

Architectural Decision Records come first. They establish the *why* before anyone writes the *what*.

Dispatch doc specialists and designer (if active) with `isolation: "worktree"`:
- **Doc specialists** write ADRs for architectural decisions (data models, API boundaries, integration patterns)
- **Designer** (if active) writes design-focused ADRs (visual hierarchy, interaction patterns, accessibility, consistency)

Each ADR follows: Context, Decision, Consequences, Status.

### G1 Review

Highfather reviews ADRs per code maintainer definition. Metron performs lightweight approval per merge maintainer definition. Dispatch one `scram:developer-reviewer` for the dev perspective. Once approved, code maintainer merges ADRs into the integration branch.

If designer is active: designer reviews design ADRs for feasibility and consistency.

If issues found, revise and re-submit.

## G2: User-Facing Docs

With approved ADRs as architectural foundation, doc specialists write the feature documentation.

Dispatch doc specialists with `isolation: "worktree"`:
- Write docs **as if features already exist** — API, behavior, usage, examples
- Docs must be grounded in the approved ADRs
- Clean up outdated plan files and consolidate scattered notes
- Be precise — types, function signatures, parameters, return values, and edge cases must be unambiguous enough for devs to write tests from

### G2 Review

Both maintainers + one `scram:developer-reviewer` review docs per their agent definitions. If designer is active: designer reviews for design ADR alignment. Once approved, maintainers merge docs into the integration branch.

If issues found, doc specialists revise and re-submit.

## G3: Story Breakdown

With approved ADRs and docs as source of truth, maintainers and devs break down implementation.

### Derive Stories

Each documented feature/behavior/API surface becomes one or more stories. Stories must:
- Map directly to a doc section
- Touch **no more than 3-5 files** (excluding tests)
- Be completable in a **single focused session**
- Prefer **vertical slices** over horizontal slices
- Have acceptance criteria derived from the docs
- Be independent — minimize cross-story dependencies

**If in doubt, split.**

### Tag Complexity

Each story gets a complexity tag that determines the agent model:

| Complexity | Model | When |
|-----------|-------|------|
| Simple | sonnet | Clear pattern, few files, context brief covers everything |
| Moderate | sonnet | Some judgment needed, moderate file scope |
| Complex | opus | Cross-cutting, architectural judgment, ambiguous requirements |

### Tag Resolution Mode

Each story gets a resolution mode:

| Mode | When | Handling |
|------|------|----------|
| `commit` | Story produces code/doc changes | Normal dev dispatch with worktree isolation |
| `verify-only` | Story requires only verifying acceptance criteria are already met | Orchestrator handles directly — no dev dispatch, no worktree. Check criteria, update tracker, record in backlog with no commit hash. |
| `conditional` | Story may or may not require changes depending on current state | Dev dispatched to investigate; may resolve as `verify-only` if criteria already met |

### Tag UI/UX Stories (when designer is active)

If a designer is on the team, flag any story that touches user-facing elements (GUI, TUI, CLI output, interactive prompts). These stories require designer approval during the merge stream in addition to standard maintainer approval(s). The designer also contributes design context to these stories' context briefs.

### Write Context Briefs (as files)

Dispatch `scram:developer-breakdown` without worktree isolation — Tier 2 dispatch. The agent reads docs-as-spec and writes context briefs to `SCRAM_WORKSPACE/briefs/`. No branch is created.

`scram:developer-breakdown` writes a context brief **file** for each story at `SCRAM_WORKSPACE/briefs/<story-slug>.md`:

```markdown
# <Story Title>

## Story
<description and acceptance criteria>

## Doc Section
<reference to the approved doc section this story maps to>

## Budget
`tight | standard | open`

## Scope Fence
<For contested-file stories: explicit declaration of which sections/files are OUT OF SCOPE. Leave blank if no contested files.>

## Files
- <file path> — <why it's relevant>

## Locators
Use content-stable grep anchors to identify locations in files. **Never use line numbers** — they go stale when earlier stories modify the same files.
- Good: "Find the sentence beginning with 'X' and change to..."
- Bad: "Line 42 of foo.ts"

## Types & Interfaces
- <key type/interface signatures>

## Dependencies
### Code dependencies
- <stories this depends on, and whether they're merged>

### Structural dependencies
- <brief-to-brief format dependencies; merge order constraints>

## Hook Constraint Check
Can this story pass pre-commit hooks independently? Yes / No — <explain if No>

## Architecture
<summary of relevant architecture and relevant ADRs from G1>

## Checklist
<Story-specific checklist items. Populate only the checklist(s) relevant to this story's domain.
If no special checklist applies, write "none". Available categories:
- Shared-state, Call-boundary, Async/lifecycle, Test-update (see developer-breakdown agent for item text)>

## UI/UX Context (if tagged)
<relevant design ADRs, existing UI patterns, component references>

## Deliverables
- [ ] <file> — <specific change>
- [ ] <file> — <specific change>
```

**Brief review rule (G3):** Reject briefs that contain line-number locators. They must use content-anchored references only.

These files live in the SCRAM workspace and are read by dev agents via absolute path.

### Prioritize

| Priority | Meaning |
|----------|---------|
| P0 — Critical | Blocks other stories, touches shared interfaces/types; do first |
| P1 — High | Core feature work; pick next |
| P2 — Normal | Independent work, no blockers |
| P3 — Low | Nice-to-have, polish, edge cases |

### Create Tracker Issues (if configured)

If a tracker was provided in G0, create issues for each story (or link existing ones). Include description, acceptance criteria, priority.

### Write the Backlog File

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

### Present the Backlog

Present the backlog table to the user. Use `AskUserQuestion` to confirm:

```
AskUserQuestion:
  questions:
    - question: "Ready to start the dev stream with this backlog?"
      header: "Backlog"
      options:
        - label: "Start streams"
          description: "Approve the backlog and begin dispatching stories"
        - label: "Adjust stories"
          description: "I want to modify stories, priorities, or dependencies"
      multiSelect: false
```

## Concurrent Streams (after G3)

After G3 approval, three streams run concurrently.

### Create Maintainer Team

Before dispatching any stories, the orchestrator creates a persistent team for the two maintainers:

1. **Create the team** via `TeamCreate` with `team_name: "scram-<feature-name>"`
2. **Spawn Metron** (merge maintainer) as a named teammate: `Agent` with `name: "Metron"`, `team_name: "scram-<feature-name>"`, `subagent_type: "scram:merge-maintainer"`
3. **Spawn Highfather** (code maintainer) as a named teammate: `Agent` with `name: "Highfather"`, `team_name: "scram-<feature-name>"`, `subagent_type: "scram:code-maintainer"`

**`backlog.md` is the sole source of truth for story status.** Do not seed tasks into the Tasks API.

> **ADR:** Tasks API dropped — `backlog.md` is sole source of truth. The Tasks API was not verified in use for real-time coordination and created silent sync drift between in-memory task state and the persistent file. Removing it eliminates that failure class and makes `backlog.md` → `session.md` the single recovery mechanism.

The maintainers stay alive as persistent teammates for the entire stream phase (G3 to G4). They coordinate dual-approval directly via `SendMessage` without the orchestrator as relay. They go idle between turns — this is normal. Sending a message wakes them.

**Files are authoritative, messages are transient.** Every decision the maintainers make must be written to `backlog.md` and `session.md`. SendMessage accelerates the decision; the file records it. If the team is destroyed and recreated, file state is the recovery mechanism.

### Emergency Halt

If the integration branch breaks after a merge (tests fail), the orchestrator writes a `HALT` file and immediately notifies the user:

```bash
echo "Tests failed after merge of <story-id> at $(date)" > "$SCRAM_WORKSPACE/HALT"
```

Then present the failure to the user with `AskUserQuestion`:

```
AskUserQuestion:
  questions:
    - question: "Integration branch is broken after merging <story-id>. How should we proceed?"
      header: "Emergency Halt"
      options:
        - label: "Revert the merge"
          description: "Revert the failing commit and redispatch the story"
        - label: "Apply a patch"
          description: "I will provide a fix to apply on the integration branch"
        - label: "Skip this story"
          description: "Revert and remove the story from the backlog"
      multiSelect: false
```

Every dispatch path checks for the `HALT` file before firing an Agent call. Do NOT dispatch further dev agents while `HALT` exists. Once the integration branch is fixed and the user's chosen resolution is applied, remove the file and resume.

### Mid-Stream Failure Recovery

If a maintainer's session dies mid-stream (context exhaustion, crash):
1. The orchestrator detects the absence (no response, idle timeout)
2. Fall back to sequential one-shot dispatch for the affected maintainer role
3. File state (`backlog.md`, `session.md`) is always complete enough to resume — the new one-shot agent reads the files to reconstruct context
4. If the team is fully lost, tear it down via `TeamDelete` and continue with one-shot dispatch for both maintainers (the pre-teams model)

### Dev Stream (Red-Green-Refactor)

`scram:developer-impl` agents are **always one-shot** with `isolation: "worktree"`. They are NOT team members. The orchestrator dispatches them directly via the `Agent` tool — on maintainer instruction via SendMessage or task state.

The dev agent runs `worktree-init.sh` per its agent definition (`scram/agents/developer-impl.md`). A `PostToolUse` hook on Agent provides a mechanical backstop — verifying worktree isolation after each dev dispatch and writing a HALT file if a violation is detected.

**Thin orchestrator discipline:** Pass paths, not contents. Each agent dispatch includes:
- Story ID and slug
- SCRAM workspace path (absolute)
- Context brief file path (`SCRAM_WORKSPACE/briefs/<story-slug>.md`) — the agent reads this from disk
- **Integration branch name** — the agent MUST branch from this, not from `main`

Do not embed brief contents, doc sections, or file contents inline in the dispatch prompt. Agents read their own context from disk. This prevents context bloat and ensures agents work from current disk state rather than stale embedded snapshots.

Dispatch `scram:developer-impl` with the context brief path — the agent follows its TDD discipline as defined in its agent file.

**Dispatch rules:**
- **P0 stories run first as a separate wave** with a quality gate before P1+ begins. This gates complex work on a proven baseline.
- Max **5 concurrent dev agents**
- Each agent works **one story at a time**, completing all three phases
- **Do not dispatch a story whose `Depends On` column has unmerged stories** — check backlog status first. Dependency must be merged into the integration branch before the dependent story is dispatched.
- **Verify branch name convention before dispatch** — the story slug must produce a branch name following `scram/<feature>/<story-slug>`. If the branch already exists (prior rejected attempt), do not reuse it — the dev agent will create a fresh branch from integration tip.
- **Stories with migrations serialize** — do not parallelize stories that include migrations touching the same tables
- Use the model matching the story's complexity tag
- Agents return a **structured Story Report** (including branch name and commit SHA) to the maintainers when complete
- Pull-based: as an agent finishes, maintainers dispatch the next story from the backlog

**Contested files:** During G3 backlog construction, identify stories that touch the same files. Add a `Contested Files` note and populate the story's `## Scope Fence` section in its brief. Same-file stories should be assigned to the same agent or given explicit merge-order annotations in the brief's `## Dependencies` section to avoid conflicts.

**Hook constraint audit (G3):** For each story, confirm it can pass pre-commit hooks independently without relying on changes from sibling stories. The export-before-deletion ordering is a named anti-pattern: if story A removes an export that story B depends on, story B must be fully merged before story A is dispatched. Record this in both stories' `## Dependencies` sections.

**Escalation on failure (using failure taxonomy):**

Agents report failures with a structured reason. Maintainers use the reason to decide next steps:

| Failure Reason | Action |
|---------------|--------|
| `context_exhaustion` | Redispatch with same model — agent ran out of context, not capability |
| `test_failure` | Review test output, redispatch at same or next tier |
| `build_error` | Check integration branch health before redispatching |
| `missing_dependency` | Verify dependency story is merged, update context brief, redispatch |
| `unclear_spec` | Flag to user for clarification, do not redispatch until resolved |
| `pre_flight_failure` | Investigate integration branch health before redispatching |

Default escalation path for capability failures: sonnet → opus. **If the same story fails review twice for the same root cause**, the orchestrator must write an escalation entry in `session.md`, diagnose the pattern, and adjust agent instructions before retrying. Do not blindly redispatch. If the same story fails twice at the same tier, maintainers escalate to user.

**Required escalation brief format:** When escalating to the user, use this structure so the user gets an actionable question, not a vague status update:

```markdown
## Escalation: <title>

**Attempted:** <what was tried>
**Failed because:** <root cause>
**Checkpoint type:** human-verify | decision | human-action
  - `human-verify` — read and confirm, no action required from you
  - `decision` — choose between the options below
  - `human-action` — you need to perform an action before the run can continue
**Decision needed:** <closed question with specific options>
**Options:**
1. <option A> — <consequence>
2. <option B> — <consequence>
3. <option C> — <consequence>
```

### Merge Stream

Both maintainers are persistent teammates. As each dev agent completes:

Dispatch Metron with the Story Report. Metron performs pre-review git health checks, dual-approval coordination, and merge execution per its agent definition.

**If tests or typecheck fail after merge:** Revert immediately. Write `HALT` file to SCRAM workspace. Update backlog status to `failed`. Do NOT merge further stories until integration branch is green and `HALT` is removed.

**Rejected branch lifecycle:** When a story is rejected, abandon the branch — do not amend it, cherry-pick from it, or redispatch into it. Write a retry brief (`briefs/<slug>-retry-<n>.md`) documenting removed scope and changed ACs. Redispatch always branches fresh from the current integration branch tip. Maintainers verify diff isolation during review: the story's diff must exactly match the brief's `## Deliverables` with no ancestry contamination from sibling branches.

**Cherry-Pick Fallback (last resort):**
When worktree isolation fails and an agent commits on the wrong branch, cherry-picking to the integration branch is permitted only if BOTH conditions are met:
1. The commit's changed file list exactly matches the story brief's deliverables
2. The commit originates from a branch created from the integration branch (not main or another story branch)

This is a recovery mechanism, not a normal workflow. If cherry-pick conditions are not met, redispatch the story.

**Conflict resolution:**
- Trivial (imports, adjacent edits): resolve in integration branch
- Substantive (competing logic): pause the story. Merge all non-conflicting work first. Redispatch the story against updated integration branch with fresh context brief.

### Doc Refinement Stream

Maintainers dispatch a doc specialist (with `isolation: "worktree"`) after every 2-3 merged stories, or after significant architectural stories merge.

The doc specialist receives:
- List of recently merged stories
- Commit hashes
- Integration branch name

They reconcile docs with actual implementation. If implementation significantly deviates from spec, they flag it to the maintainers rather than silently updating. ADRs are amended (not replaced) if decisions changed during implementation.

## G4: Final Review

After all three streams complete:

1. **Shut down the maintainer team** — send `SendMessage` with `message: {type: "shutdown_request"}` to both Metron and Highfather. Wait for shutdown responses. Then call `TeamDelete` to clean up the team.
2. Review every commit on the integration branch against the spec and ADRs (dispatch maintainers as one-shots for this review)
3. Verify consistency across all merged work
4. Run full test suite one final time
5. Verify docs and ADRs accurately reflect the final implementation
6. Verify `SCRAM_WORKSPACE/backlog.md` shows all stories as `merged`
7. **Stash cleanup:** Run `git stash list`. If any stashes exist, notify the user with stash details and offer to drop them. Do not silently drop stashes — they may contain user work.
8. Close remaining tracker issues (if configured), add summary comment
8. Ask the user about a retrospective now that they have seen the completed work:

```
AskUserQuestion:
  questions:
    - question: "All stories are merged and reviewed. Would you like a team retrospective?"
      header: "Retrospective"
      options:
        - label: "Yes (Recommended)"
          description: "Maintainers review how the run went and suggest SCRAM improvements"
        - label: "No"
          description: "Skip the retrospective"
      multiSelect: false
```

Record the answer. If yes, G5 runs after G4.

9. Merge or PR the integration branch to `main`
10. Update session manifest — set `current_gate` to `complete` (or `G5` if retrospective enabled)
11. If no retrospective: remove the `scram-session-*` memory reference (run is done)
12. **Workspace cleanup** — Offer to clean up session artifacts:

```
AskUserQuestion:
  questions:
    - question: "Clean up SCRAM workspace and worktree remnants?"
      header: "Cleanup"
      options:
        - label: "Keep everything"
          description: "Workspace stays at SCRAM_WORKSPACE for future reference"
        - label: "Delete workspace"
          description: "Remove SCRAM_WORKSPACE directory"
        - label: "Full cleanup"
          description: "Remove workspace + any .claude/worktrees/ remnants in project root"
      multiSelect: false
```

If "Delete workspace": `rm -rf "$SCRAM_WORKSPACE"`
If "Full cleanup": also `rm -rf .claude/worktrees/` if it exists in the project root

If issues found, add fix stories to the backlog and redispatch.

**Follow-up story sweep:** Before closing G4, sweep `session.md` for any items marked "partial," "deferred," or "ready for future wiring." Each must become either a new backlog story or an explicit decision that partial work is acceptable. Do not leave loose ends undocumented.

**Compressed gate tracking:** If G1/G2 were skipped (per gate-skip criteria), record in `session.md` under a "Compressed Gates" section: `G1/G2 compressed — ADR source: <scramstorm workspace path or external reference>`.

## G5: Retrospective (optional)

If the user opted in to a retrospective during G0, dispatch `scram:scram-retro` with:
- `SCRAM_WORKSPACE` — absolute path to the workspace
- `in_flight_path` — `SCRAM_WORKSPACE/retro/in-flight.md` (pass the path; skill checks if the file exists)
- `session_context` — `{ total_stories, escalations, halt_events, feature_name }`

The retro facilitator is self-contained. It reads workspace artifacts, dispatches maintainers as fresh one-shots, compiles results, and presents consensus changes to the user. After the retro completes, update session manifest to `complete` and remove the `scram-session-*` memory reference.

## Session State Updates

The session manifest MUST be kept current. Update `SCRAM_WORKSPACE/session.md` (and the corresponding memory reference) at these points:

| Event | Update |
|-------|--------|
| Gate transition (G0→G1, G1→G2, etc.) | Set `current_gate`, update `Current State` |
| Maintainer team created (G3) | Record team name in `Current State` |
| Story dispatched | Add to `In-Progress Stories` |
| Story merged | Move to `Merged Stories` with commit hash, remove from in-progress |
| Story failed/escalated | Add to `Escalations` with failure reason and tier |
| Doc refinement batch completed | Note in `Current State` |
| Maintainer team shut down (G4) | Note in `Current State` |
| Context limit approaching | Write full state to manifest before checkpointing |

### Context Limit Recovery

If you approach context limits, ensure the session manifest is fully up to date, then present the workspace path to the user:

```
Approaching context limits. Session state saved to:
  SCRAM_WORKSPACE/session.md

Resume in a new conversation — SCRAM will discover this session automatically.
```

The user can continue in a fresh session. The new orchestrator will find the workspace via the discovery flow at G0 (filesystem scan + memory reference) and resume from the recorded gate.

## Constraints

- `scram:developer-impl` and `scram:doc-specialist` dispatched with `isolation: "worktree"` (Tier 1 implementation) — non-negotiable even for simple stories. `scram:developer-reviewer` and `scram:developer-breakdown` are Tier 2 dispatch — no worktree isolation
- All developers use strict TDD — tests before implementation. For content-only stories (no executable tests), use the substitute discipline: (1) establish a schema or validation contract, (2) validate content against it, (3) human-readable diff review against prior version
- Never skip hooks or force-push
- New commits only — never amend
- One atomic commit per story
- SCRAM workspace is outside the project repo — never committed to git
- **Post-merge fixes go through story lifecycle** — no informal patches on the integration branch. Any defect discovered post-merge requires a backlog entry, context brief, and clean commit through normal dispatch. This preserves the one-commit-per-story invariant and ensures dual-approval is never bypassed.
- **G2 doc work MUST use `scram:doc-specialist` agents** — developers may not substitute for doc specialists at G2
- **External service work** — when agents update external services via API (not git-tracked files), use the staging pattern: write proposed content to local files in the worktree first, maintainers review those files as a diff, only after approval does a final step push to the external service. This preserves the review gate for side-effectful work.
