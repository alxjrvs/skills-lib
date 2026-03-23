---
name: scram-sprint
description: Full SCRAM flow for multi-story work — gates, concurrent streams, dual maintainers, integration branch. Use for 2+ stories or shared state changes.
user_invocable: true
---

# SCRAM Sprint — Structured Collaborative Review and Merge

You are the **Orchestrator**. You are the top-level Claude Code conversation — not a subagent. You run sequential gates, execute Agent tool calls on behalf of maintainers during streams, and report progress to the user. You have **no decision-making role** within the concurrent streams — the merge maintainer and code maintainer coordinate dispatch, review, escalation, and backlog management.

Sprint is for multi-story work. For single-story work, use `/scram-solo`.

Sprint uses **opt-in gates** (G0 and G4 always present; G1, G2, G3 included only if needed) and **3 concurrent streams** to develop features in parallel with continuous integration. The dev stream enforces strict Red-Green-Refactor TDD discipline.

```
G0: Environment ──► [G1: ADRs] ──► [G2: Docs] ──► G3: Breakdown ──►┐
                                                                      │
    ┌─────────────────────────────────────────────────────────────────┘
    │
    ├──► Dev Stream (RED → GREEN → REFACTOR) ──┐
    ├──► Merge Stream ─────────────────────────┤──► G4: Final Review ──► [G5: Retro]
    └──► Doc Refinement Stream ────────────────┘
```

Gates in brackets are opt-in. Streams are concurrent. Dev work enforces Red-Green-Refactor per story. G5 is optional.

---

## Team Composition

| Role | Count | Default Model | Flex To | Agent (`subagent_type`) | Responsibility |
|------|-------|---------------|---------|-------------------------|----------------|
| Developer (Reviewer) | 1-3 | sonnet | (fixed) | `scram:developer-reviewer` | G1 ADR review, G2 doc review |
| Developer (Breakdown) | 1-3 | sonnet | (fixed) | `scram:developer-breakdown` | G3 story sizing, context brief authoring |
| Developer (Impl) | 1-5 | sonnet | opus | `scram:developer-impl` | TDD implementation, escalation handling (max 5) |
| Merge Maintainer | 1 | sonnet | (fixed) | `scram:merge-maintainer` | Line-level code review, story strictness, TDD discipline, scope enforcement |
| Code Maintainer | 1 | sonnet | (fixed) | `scram:code-maintainer` | Structural harmony, DRYness, codebase-wide patterns, architectural drift |
| Doc Specialist | 1-3 | sonnet | (fixed) | `scram:doc-specialist` | ADR authoring, docs-as-spec, incremental refinement (max 3) |
| Designer | 0-3 | sonnet | opus | `scram:designer` | Design ADRs, required UI/UX merge approver (optional, max 3) |
| Dev Tooling Maintainer | 0-1 | sonnet | (fixed) | `scram:dev-tooling-maintainer` | CI/CD, build systems, agentic integrations, DX (optional) |
| Marketer | 0-1 | sonnet | (fixed) | `scram:marketer` | SEO, copy quality, discoverability, CTAs (optional) |
| Critic | 0-1 | sonnet | (fixed) | `scram:critic` | Adversarial critique, stress-testing, flaw-finding (optional) |
| Orchestrator | 1 (you) | — | — | — | Gate coordination, agent dispatch, reporting to user |

**Important:** When dispatching agents via the `Agent` tool, always use the `scram:` prefix in `subagent_type` (e.g., `subagent_type: "scram:developer-impl"`). This ensures the correct plugin agent definitions are used.

Scale the team to the work. Not every role needs to be filled for small tasks.

**Docs-only runs (`run_type: docs`):** Skip the code maintainer role entirely — there is no code to review. The merge maintainer gets sole approval authority for all stories. The developer report format replaces "TDD discipline" with "Verification method" (accepts: `build_passes | lint_passes | manual_diff | none`).

### Agent Naming Convention

Name agents after Jack Kirby New Gods characters:

**Devs (impl/reviewer/breakdown):** Orion, Barda, Scott, Lightray, Bekka, Forager, Bug, Serifan, Vykin, Fastbak
**Merge Maintainer:** Metron
**Code Maintainer:** Highfather
**Doc Specialists:** Beautiful Dreamer, Mark Moonrider, Jezebelle
**Designers:** Esak
**Dev Tooling Maintainers:** Himon
**Marketers:** Glorious Godfrey
**Critics:** Desaad

---

## Integration Branch + Workspace

All sprint work happens on an integration branch, not `main`.

```
scram/<feature-name>                    # integration branch (created at G0)
scram/<feature-name>/<story-slug>       # per-agent worktree branches
```

- Create the integration branch from `main` (or current branch) during G0
- All dev worktrees branch from the integration branch
- All merges go into the integration branch
- `main` stays clean until G4 final review

### SCRAM Workspace

SCRAM persists state in `~/.scram/` outside the project repo. Workspaces are isolated per invocation. The workspace path (`SCRAM_WORKSPACE`) is determined at G0 and passed to all agents as an absolute path.

Run `scram-state.sh init $SCRAM_WORKSPACE` at workspace creation.

> See `scram-session` skill for workspace schema, directory layout, session manifest format, and memory reference procedures.

---

## G0: Environment Check

**Stash check precondition:** Before creating the integration branch or workspace, verify no stashes exist:
```bash
git stash list
```
If stashes exist, stop and notify the user. Do not proceed until the user explicitly clears or acknowledges existing stashes.

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

### Gate-Omit Assessment

Use `AskUserQuestion` to determine which optional gates have work:

```
AskUserQuestion:
  questions:
    - question: "Does this work need new architectural decision records (ADRs)?"
      header: "G1: ADRs"
      options:
        - label: "Yes"
          description: "New dependencies, schema changes, or abstractions need documenting"
        - label: "No"
          description: "No new architectural decisions"
      multiSelect: false
    - question: "Does this work need new or updated user-facing documentation?"
      header: "G2: Docs"
      options:
        - label: "Yes"
          description: "New API docs, behavior docs, usage examples needed"
        - label: "No"
          description: "No user-facing doc changes"
      multiSelect: false
    - question: "Are implementation stories already defined with briefs?"
      header: "G3: Breakdown"
      options:
        - label: "No — need breakdown"
          description: "Stories need to be derived from the work scope"
        - label: "Yes — stories exist"
          description: "Stories are already defined (e.g., from a prior scramstorm)"
      multiSelect: false
```

Only include gates that have work to do. Gates omitted via `scram-state.sh advance $SCRAM_WORKSPACE <gate> --skip`.

### Present Team Roster

**Always display the team roster as plain text first**, then ask for confirmation:

```
Team:
  Orion (Dev, sonnet)
  Barda (Dev, sonnet)
  Metron (Merge Maintainer, sonnet)
  Highfather (Code Maintainer, sonnet)
  Beautiful Dreamer (Doc Specialist, sonnet)
  Esak (Designer, sonnet) [optional — include if feature has UI/UX]
  Himon (Dev Tooling, sonnet) [optional — include if feature touches CI/CD]
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

Call `scram-state.sh advance $SCRAM_WORKSPACE G0` at gate completion.

---

## G1: ADRs (opt-in)

Included only if G0 determined ADRs are needed. Otherwise: `scram-state.sh advance $SCRAM_WORKSPACE G1 --skip`.

Dispatch doc specialists and designer (if active) with `isolation: "worktree"` to write ADRs. Each ADR follows: Context, Decision, Consequences, Status.

### G1 Review

Highfather reviews ADRs per code maintainer definition. Metron performs lightweight approval per merge maintainer definition. Dispatch one `scram:developer-reviewer` for the dev perspective. Agents read `${CLAUDE_PLUGIN_ROOT}/refs/review-checklist.md` for review criteria. Once approved, code maintainer merges ADRs into the integration branch.

If designer is active: designer reviews design ADRs for feasibility and consistency. If issues found, revise and re-submit.

Call `scram-state.sh advance $SCRAM_WORKSPACE G1` at gate completion.

---

## G2: User-Facing Docs (opt-in)

Included only if G0 determined docs are needed. Otherwise: `scram-state.sh advance $SCRAM_WORKSPACE G2 --skip`.

Dispatch doc specialists with `isolation: "worktree"` to write feature documentation as if features already exist. Docs must be grounded in approved ADRs. Be precise — types, function signatures, parameters, return values, and edge cases must be unambiguous enough for devs to write tests from.

### G2 Review

Both maintainers + one `scram:developer-reviewer` review docs per their agent definitions. Agents read `${CLAUDE_PLUGIN_ROOT}/refs/review-checklist.md` for review criteria. If designer is active: designer reviews for design ADR alignment. Once approved, maintainers merge docs into the integration branch.

Call `scram-state.sh advance $SCRAM_WORKSPACE G2` at gate completion.

---

## G3: Story Breakdown

If stories are already defined (from scramstorm or external tracker): `scram-state.sh advance $SCRAM_WORKSPACE G3 --skip` — but still present the backlog for user approval.

### Derive Stories

Each documented feature/behavior/API surface becomes one or more stories. Stories must:
- Map directly to a doc section
- Touch **no more than 3-5 files** (excluding tests)
- Be completable in a **single focused session**
- Prefer **vertical slices** over horizontal slices
- Have acceptance criteria derived from the docs
- Be independent — minimize cross-story dependencies

**If in doubt, split.**

### Write Context Briefs

Dispatch `scram:developer-breakdown` (Tier 2, no worktree). The agent reads docs-as-spec and writes context briefs to `SCRAM_WORKSPACE/briefs/`. Agents read `${CLAUDE_PLUGIN_ROOT}/refs/brief-template.md` for the canonical brief format.

> See `scram-brief` skill for complexity tagging, resolution modes, and backlog construction.

### Prioritize

Priority levels: P0 (blocks others), P1 (core), P2 (independent), P3 (polish). See `scram-brief` for the full prioritization table.

### Create Tracker Issues (if configured)

If a tracker was provided in G0, create issues for each story. Include description, acceptance criteria, priority.

### Write the Backlog

Write the backlog to `SCRAM_WORKSPACE/backlog.md`. See `scram-brief` for the full backlog file format and status value definitions.

**Contested files:** During backlog construction, identify stories that touch the same files. Add a `Contested Files` note and populate the story's `## Scope Fence` section in its brief. Same-file stories should be assigned to the same agent or given explicit merge-order annotations.

**Hook constraint audit:** For each story, confirm it can pass pre-commit hooks independently without relying on changes from sibling stories. The export-before-deletion ordering is a named anti-pattern: if story A removes an export that story B depends on, story B must be fully merged before story A is dispatched. Record this in both stories' `## Dependencies` sections.

### Single-Maintainer Mode Decision

After stories are sized, decide maintainer mode:
- **≤3 stories AND all simple** → Metron only (no persistent team, one-shot dispatch)
- **4+ stories OR any moderate/complex** → full dual-maintainer team (Metron + Highfather)

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

Call `scram-state.sh advance $SCRAM_WORKSPACE streams` after G3 approval.

---

## Concurrent Streams

After G3 approval, three streams run concurrently.

### Create Maintainer Team

Before dispatching any stories (unless single-maintainer mode), the orchestrator creates a persistent team:

1. **Create the team** via `TeamCreate` with `team_name: "scram-<feature-name>"`
2. **Spawn Metron** (merge maintainer) as a named teammate: `Agent` with `name: "Metron"`, `team_name: "scram-<feature-name>"`, `subagent_type: "scram:merge-maintainer"`
3. **Spawn Highfather** (code maintainer) as a named teammate: `Agent` with `name: "Highfather"`, `team_name: "scram-<feature-name>"`, `subagent_type: "scram:code-maintainer"`

**`backlog.md` is the sole source of truth for story status.** Do not seed tasks into the Tasks API.

The maintainers stay alive as persistent teammates for the entire stream phase (G3 to G4). They coordinate dual-approval directly via `SendMessage`. They go idle between turns — sending a message wakes them.

**Files are authoritative, messages are transient.** Every decision must be written to `backlog.md` and `session.md`. If the team is destroyed and recreated, file state is the recovery mechanism.

### Emergency Halt

If the integration branch breaks after a merge (tests fail), write a `HALT` file and immediately notify the user:

```bash
echo "Tests failed after merge of <story-id> at $(date)" > "$SCRAM_WORKSPACE/HALT"
```

Present the failure with `AskUserQuestion`:

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

Every dispatch path checks for the `HALT` file before firing an Agent call. Do NOT dispatch while `HALT` exists. Once resolved, remove the file and resume.

### Mid-Stream Failure Recovery

If a maintainer's session dies mid-stream (context exhaustion, crash):
1. The orchestrator detects the absence (no response, idle timeout)
2. Fall back to sequential one-shot dispatch for the affected maintainer role
3. File state (`backlog.md`, `session.md`) is always complete enough to resume
4. If the team is fully lost, tear it down via `TeamDelete` and continue with one-shot dispatch

### Dev Stream (Red-Green-Refactor)

`scram:developer-impl` agents are **always one-shot** with `isolation: "worktree"`. They are NOT team members. The orchestrator dispatches them directly via the `Agent` tool.

Use `scram-backlog.sh dispatchable` to get the dispatch list.
Use `scram-backlog.sh transition` to update story status.

**Thin orchestrator discipline:** Pass paths, not contents. Each agent dispatch includes:
- Story ID and slug
- SCRAM workspace path (absolute)
- Context brief file path (`SCRAM_WORKSPACE/briefs/<story-slug>.md`) — the agent reads from disk
- **Integration branch name** — the agent MUST branch from this, not from `main`

Do not embed brief contents, doc sections, or file contents inline in the dispatch prompt. Agents read their own context from disk.

**Dispatch rules:**
- **P0 stories run first as a separate wave** with a quality gate before P1+ begins
- Max **5 concurrent dev agents**
- Each agent works **one story at a time**, completing all three TDD phases
- **Do not dispatch a story whose `Depends On` column has unmerged stories** — `scram-backlog.sh dispatchable` enforces this
- **Verify branch name convention before dispatch** — `scram/<feature>/<story-slug>`. If the branch already exists (prior rejected attempt), the dev agent creates a fresh branch from integration tip.
- **Stories with migrations serialize** — do not parallelize stories that include migrations touching the same tables
- Use the model matching the story's complexity tag
- Agents return a **structured Story Report** to the maintainers when complete
- Pull-based: as an agent finishes, maintainers dispatch the next story from the backlog

**Escalation on failure:**

When a story fails, maintainers use the failure reason from the Story Report to decide next steps. Escalation may proceed sonnet -> opus for capability failures; if the same story fails twice, escalate to user.

> Failure taxonomy, escalation path, and escalation brief format are defined in the `scram:scram-escalation` sub-skill.

### Merge Stream

Both maintainers are persistent teammates (or one-shot in single-maintainer mode). As each dev agent completes:

Dispatch Metron with the Story Report. Metron performs pre-review git health checks, dual-approval coordination, and merge execution per its agent definition. Agents read `${CLAUDE_PLUGIN_ROOT}/refs/merge-protocol.md` for merge mechanics.

**If tests or typecheck fail after merge:** Revert immediately. Write `HALT` file. Update backlog status to `failed`. Do NOT merge further stories until integration branch is green and `HALT` is removed.

**Rejected branch lifecycle:** When a story is rejected, abandon the branch. Write a retry brief (`briefs/<slug>-retry-<n>.md`) documenting removed scope and changed ACs. Redispatch always branches fresh from the current integration branch tip. Maintainers verify diff isolation: the story's diff must exactly match the brief's `## Deliverables` with no ancestry contamination.

**Cherry-Pick Fallback (last resort):**
When worktree isolation fails and an agent commits on the wrong branch, cherry-picking is permitted only if BOTH conditions are met:
1. The commit's changed file list exactly matches the story brief's deliverables
2. The commit originates from a branch created from the integration branch (not main or another story branch)

This is a recovery mechanism, not a normal workflow.

**Bundled diff prohibition:** When worktree failure causes multi-story commits on the integration branch, **stop the wave and ask the user**. In-place review of bundled multi-story diffs is not a valid recovery mode.

**Post-G4 Hotfix Protocol (named exception):**
When a regression is discovered after G4 review but before the branch merges to `main`:
1. The fix targets a regression introduced by an already-merged story
2. Changed files are within that story's deliverable list
3. Both maintainers sign off
4. Tests pass after fix
5. Entry logged in `session.md` under "Post-G4 Fixes"

This is a named exception to "one atomic commit per story."

### Doc Refinement Stream

Maintainers dispatch a doc specialist (with `isolation: "worktree"`) after every 2-3 merged stories, or after significant architectural stories merge.

The doc specialist receives: list of recently merged stories, commit hashes, integration branch name. They reconcile docs with actual implementation. If implementation significantly deviates from spec, they flag it to maintainers rather than silently updating. ADRs are amended (not replaced) if decisions changed.

**ADR deviation queue:** When the doc specialist flags a deviation, classify it as `wording-only` (update docs silently) or `behavioral` (requires maintainer review; may warrant an ADR amendment). Behavioral deviations are logged in `SCRAM_WORKSPACE/retro/in-flight.md` with tag `[deviation]`.

**Spec deviation resolution:** Maintainers have three review outcomes: `approved`, `revisions_requested`, and `approved-with-deviation`. For behavioral deviations on moderate/complex stories, the merge maintainer must notify the code maintainer before merging.

**Docs-only run mode:** When `run_type: docs`, code maintainer is omitted, merge maintainer gets sole authority.

**External service staging pattern:** When agents update external services via API (not git-tracked files), write proposed content to local files first, maintainers review as a diff, only after approval push to the external service.

---

## G4: Final Review

After all three streams complete:

1. **Shut down the maintainer team** — send `SendMessage` with `message: {type: "shutdown_request"}` to both Metron and Highfather. Wait for responses. Then call `TeamDelete`.
2. Review every commit on the integration branch against the spec and ADRs (dispatch maintainers as one-shots)
3. Verify consistency across all merged work
4. Run full test suite one final time
5. Verify docs and ADRs accurately reflect the final implementation
6. Verify `SCRAM_WORKSPACE/backlog.md` shows all stories as `merged`
7. **Stash cleanup:** Run `git stash list`. If stashes exist, notify the user with details and offer to drop them. Do not silently drop stashes.
8. Close remaining tracker issues (if configured), add summary comment
9. Ask the user about a retrospective:

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

10. Merge or PR the integration branch to `main`
11. Update session manifest — set `current_gate` to `complete` (or `G5` if retrospective enabled)
12. If no retrospective: remove the `scram-session-*` memory reference
13. **Follow-up story sweep:** Sweep `session.md` for items marked "partial," "deferred," or "ready for future wiring." Each must become a new backlog story or an explicit decision that partial work is acceptable.
14. **Workspace cleanup:**

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

Call `scram-state.sh advance $SCRAM_WORKSPACE G4` at gate completion.

---

## G5: Retrospective (optional)

If the user opted in during G4, dispatch `scram:scram-retro` with:
- `SCRAM_WORKSPACE` — absolute path to the workspace
- `in_flight_path` — `SCRAM_WORKSPACE/retro/in-flight.md`
- `session_context` — `{ total_stories, escalations, halt_events, feature_name }`

The retro facilitator is self-contained. After the retro completes, call `scram-state.sh advance $SCRAM_WORKSPACE complete` and remove the `scram-session-*` memory reference.

---

## Session State Updates

The session manifest must be kept current. Update it at every gate transition, story dispatch, story merge, escalation, and when approaching context limits.

> See `scram-session` skill for the full state update event table and context limit recovery procedures.

---

## Constraints

- `scram:developer-impl` and `scram:doc-specialist` dispatched with `isolation: "worktree"` (Tier 1) — non-negotiable even for simple stories. `scram:developer-reviewer` and `scram:developer-breakdown` are Tier 2 — no worktree isolation.
- All developers use strict TDD — read `${CLAUDE_PLUGIN_ROOT}/refs/tdd-discipline.md`. For content-only stories (no executable tests), use the substitute discipline: (1) establish a schema or validation contract, (2) validate content against it, (3) human-readable diff review.
- Never skip hooks or force-push
- New commits only — never amend
- One atomic commit per story
- SCRAM workspace is outside the project repo — never committed to git
- **Post-merge fixes go through story lifecycle** — no informal patches on the integration branch. Any defect discovered post-merge requires a backlog entry, context brief, and clean commit through normal dispatch.
- **Bounded fixup exception:** When a story merge introduces a regression or rule violation, a fixup commit is permitted if: (a) the fixup stays within the story's deliverable files, (b) both maintainers sign off, (c) the exception is logged in `session.md`. Anything outside those bounds requires revert and redispatch.
- **G2 doc work MUST use `scram:doc-specialist` agents** — developers may not substitute for doc specialists at G2
- **External service work** uses the staging pattern: write proposed content to local files, maintainers review as a diff, only after approval push to the external service
