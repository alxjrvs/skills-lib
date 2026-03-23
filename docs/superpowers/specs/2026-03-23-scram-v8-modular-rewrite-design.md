# SCRAM v8.0.0 — Modular Rewrite Design Spec

**Date:** 2026-03-23
**Status:** Draft
**Breaking change:** Yes (skill names, invocation patterns, directory structure)

## Problem

SCRAM v7 suffers from two compounding problems:

1. **Rigidity** — One 566-line monolithic skill tries to serve 4 scales of work (Full/Lightweight/Quick/Nano) through degradation modes. Small work loads the full process and then skips most of it. The tier system patches a fundamentally heavyweight design.

2. **Fragility** — Recurring failures (worktree violations, bundled diffs, out-of-order operations, dispatching blocked stories, lost in-flight observations, cross-story type drift) are mitigated by prose instructions that agents forget or misinterpret. 10+ retro issues documented the same failure classes repeatedly.

## Solution

Decompose SCRAM into composable primitives that compose up, not a monolith that scales down. Replace prose-described invariants with mechanical script enforcement.

## Architecture Overview

```
User invokes /scram
        │
        ▼
┌──────────────────┐
│  scram dispatcher │  (~100 lines)
│  Scope assessment │
│  Route decision   │
└────┬─────────┬───┘
     │         │
     ▼         ▼
┌─────────┐ ┌──────────────┐
│ /scram  │ │ /scram       │
│  -solo  │ │  -sprint     │
│ (~150)  │ │ (~300)       │
└────┬────┘ └──────┬───────┘
     │             │
     │     ┌───────┴────────┐
     │     │                │
     ▼     ▼                ▼
┌─────────────────┐  ┌──────────────┐
│  refs/ (shared  │  │ scripts/     │
│  primitives,    │  │ (mechanical  │
│  read on-demand)│  │ enforcement) │
└─────────────────┘  └──────────────┘
```

## Component 1: `/scram` Dispatcher

**File:** `scram/skills/scram/SKILL.md` (~100 lines)
**User-invocable:** Yes

A thin router that:

1. **Checks for existing sessions** — runs `scram-discover.sh`, offers resume
2. **Checks for scramstorm handoff** — scans `~/.scram/brainstorm--*` for recent manifests, reads `handoff.md` if found
3. **Assesses scope** — asks the user what they're building, gathers:
   - Features to implement (with enough detail to route)
   - Scope boundaries
4. **Routes** based on signals:

| Signal | Route |
|--------|-------|
| 1 story, ≤5 files, no shared state changes | `/scram-solo` |
| Any shared state/package changes (regardless of story count) | `/scram-sprint` |
| 2+ stories | `/scram-sprint` |
| New abstractions or architectural decisions needed | `/scram-sprint` |
| User explicitly requests brainstorm | `/scramstorm` |

Rules are evaluated top-to-bottom. Any shared state change forces sprint even for a single story — the integration branch and dual-review are needed to protect shared surfaces.

5. **Confirms** — shows routing decision with rationale, asks user to approve or override
6. **Invokes** the target skill

The dispatcher owns: scope assessment, scramstorm handoff detection, session resume. It does NOT own any gate logic, team composition, or process steps.

### Scramstorm Handoff (in dispatcher)

When a handoff manifest is detected:
1. Read `handoff.md` from the brainstorm workspace
2. Display gate eligibility (which gates the brainstorm marked as skippable)
3. Copy stub briefs into the sprint workspace if applicable
4. Route to `/scram-sprint` with `prior_brainstorm` context

## Component 2: `/scram-solo` — Single-Story Flow

**File:** `scram/skills/scram-solo/SKILL.md` (~150 lines)
**User-invocable:** Yes (also invoked by dispatcher)

Purpose-built lightweight flow for single-story work.

### Flow

```
Assess → Brief → Implement → Review → Merge
```

### Steps

1. **Assess** — Orchestrator confirms scope fits solo (≤5 files, no shared state changes). If scope exceeds solo capacity, redirect to `/scram-sprint`.

2. **Brief** — Orchestrator writes a context brief directly (using `refs/brief-template.md`). No breakdown agent dispatch. User confirms acceptance criteria.

3. **Implement** — Dispatch one `scram:developer-impl` with `isolation: "worktree"`. Branch from current branch: `scram/solo/<story-slug>`. Same TDD discipline, same Story Report. Model matches complexity tag.

4. **Review** — Dispatch one maintainer (Metron) as a one-shot reviewer. Single-approval only. Uses `refs/review-checklist.md`.

5. **Merge** — Metron merges to the source branch. Tests must pass. Done.

### Solo workspace

Solo creates a **minimal temp workspace** for hook compatibility:
```bash
SCRAM_WORKSPACE=$(mktemp -d)/scram-solo-<story-slug>
mkdir -p "$SCRAM_WORKSPACE"
```

This directory holds only the context brief file. No `session.md`, no `backlog.md`, no `events/`. The solo orchestrator cleans up the workspace after the merge step completes: `rm -rf "$SCRAM_WORKSPACE"`. This ensures all hooks that guard on `SCRAM_WORKSPACE` being set continue to function (halt-check, isolation-check, brief-lint).

### Solo branch convention

Solo bypasses `worktree-init.sh` entirely. The solo orchestrator creates the worktree and branch directly:

```bash
git worktree add .claude/worktrees/<story-slug> -b scram/solo/<story-slug>
```

This avoids the sprint-specific branch derivation logic in `worktree-init.sh` (which expects `scram/<feature>` as the integration branch and derives `scram/<feature>/<story-slug>`). Solo's branch convention is simpler — no feature namespace, just `scram/solo/<slug>`. The isolation-check.sh PostToolUse hook still fires and validates the worktree.

### What's eliminated (vs. today's Nano/Quick)

- No G0-G4 gate ceremony
- No integration branch (branch directly from current)
- No full `~/.scram/` workspace (only a temp dir for hook compat)
- No session manifest or backlog file
- No persistent team (agents dispatched as one-shots via `Agent` tool, no `TeamCreate`)
- No doc specialist dispatch
- No ADR gate
- No retro
- No stash checks (no teardown that could interact with stashes)
- No external tracker integration

### What's preserved

- Worktree isolation (non-negotiable)
- TDD discipline (via `refs/tdd-discipline.md`)
- Context brief (agents need structured input)
- Code review (always required — a SCRAM run without review is not a SCRAM run)
- Story Report format (structured output via `refs/report-formats.md`)
- Hook enforcement (halt-check, isolation-check, brief-lint — all function via solo workspace)

### Escape hatch

If the dev discovers scope exceeds solo capacity mid-implementation, they report `failure_reason: scope_exceeded`. The orchestrator offers to upgrade to `/scram-sprint`, carrying forward the brief and any completed work.

## Component 3: `/scram-sprint` — Multi-Story Flow

**File:** `scram/skills/scram-sprint/SKILL.md` (~300 lines, down from 566)
**User-invocable:** Yes (also invoked by dispatcher)

The full SCRAM flow: gates, concurrent streams, dual maintainers. Same architecture, leaner delivery.

### What stays the same

- Integration branch model (`scram/<feature-name>`)
- `~/.scram/` workspace with session manifest
- Three concurrent streams (dev, merge, doc refinement)
- Persistent maintainer team (Metron + Highfather)
- Worktree isolation for Tier 1 agents
- All existing hooks and scripts
- Max 5 concurrent dev agents
- Pull-based dispatch (as agent finishes, next story dispatched)

### Change 3a: Gate-omit (replaces gate-skip)

Today's gate-skip requires a rationale in `session.md`. The new model inverts this:

- **G0** (environment) and **G4** (final review) are always present
- **G1** (ADRs), **G2** (docs), **G3** (breakdown) are **opt-in, not opt-out**
- During G0 scope assessment, the orchestrator asks: "Does this work need new ADRs? New user-facing docs? Or are stories already defined?"
- Only gates with work to do are included
- No rationale required for omission — the conversation is the record

### Change 3b: Single-maintainer mode

Decided at G3 after stories are sized, not at G0:

- ≤3 stories AND all simple complexity → **single maintainer** (Metron only, no persistent team)
- 4+ stories OR any moderate/complex → **full dual-maintainer** mode with persistent team

### Change 3c: Prose extracted to refs/

Agent files carry only unique content. Shared procedures are read on-demand from `refs/`. See Component 5 for the full refs/ inventory.

### Change 3d: Mechanical state enforcement

Gate transitions and story status are tracked by scripts, not prose. See Component 6 for details.

### Preserved sprint features

- Scramstorm handoff processing (moved to dispatcher, results passed in)
- External tracker integration
- Contested files and hook constraint audits at G3
- P0 wave gating
- Cherry-pick fallback with bundled diff prohibition
- Post-G4 hotfix protocol
- Emergency halt with HALT file
- Mid-stream failure recovery
- Doc refinement stream with deviation taxonomy
- Follow-up story sweep before G4 close
- G5 retrospective (optional)
- Docs-only run mode (`run_type: docs`) — code maintainer omitted, merge maintainer gets sole approval, dev reports use "Verification method" instead of "TDD discipline"
- External service staging pattern — write proposed content to local files, review, then push to external service
- Stash checks at G0 and G4
- AskUserQuestion interactions for tracker, team roster, backlog approval

## Component 4: `/scramstorm` — Brainstorm Flow

**File:** `scram/skills/scramstorm/SKILL.md` (~400 lines, down from 555)
**User-invocable:** Yes

### What stays in the skill file (~400 lines)

- Phase flow overview (Frame → Research → Tickets → Vote → Discuss → Present)
- Team composition table (core + optional specialists) — names and `subagent_type` mappings stay inline (personality descriptions move to refs/)
- Phase 1: Frame (problem.md template with Known Friction, Known Divergences, Desired Outcome)
- Phase 1.5: Prior Retro Scan
- Phase 2: Research (dispatch instructions, evidence pass, scoped exploration, open questions resolution, context integrity check)
- Phase 3: Tickets (structured ticket template, state contract requirement, pre-vote processing)
- Phase 4: Vote (voting mechanics, disposition field, orphan check)
- Phase 5: Discuss (steward triage, unanimous fast-path with brief generation, discussion format, steward synthesis)
- Phase 6: Present — dispatch instructions and handoff manifest format stay inline; output format templates move to refs/
- Retrospective section
- Constraints

### What's extracted to refs/

- **Output format templates** (~120 lines) → `refs/scramstorm-output-formats.md`, read during Phase 6 only
- **Personality table and debate roles** (~40 lines) → `refs/scramstorm-personas.md`, referenced in dispatch prompts

### Other changes

- **All retro improvements already applied** (Known Friction, Known Divergences, Prior Retro Scan, Context Integrity Check, structured ticket template, 3-pass pre-vote processing, vote disposition, orphan check, unanimous fast-path)
- **Handoff** — the new `/scram` dispatcher natively checks for handoff manifests, making the transition a first-class routing path

## Component 5: `refs/` — Shared Primitives

**Directory:** `scram/refs/` (~250 lines total)

Reference documents read on-demand by agents via the `Read` tool. Never injected into system prompts.

| File | Lines (est.) | Contains | Read by |
|------|-------------|----------|---------|
| `refs/merge-protocol.md` | ~60 | Merge mechanics, conflict resolution, commit format, tracker updates | merge-maintainer, code-maintainer |
| `refs/review-checklist.md` | ~40 | Diff isolation, ancestry check, commit count, generated type parity, scope discipline, deletion verification, cross-story type drift, ADR deviation tracking | merge-maintainer, code-maintainer |
| `refs/tdd-discipline.md` | ~30 | Red-Green-Refactor phases, content-only substitute discipline | developer-impl |
| `refs/report-formats.md` | ~60 | Story Report, Merge Maintainer Report, Code Maintainer Report, Doc Report templates | all agents |
| `refs/commit-format.md` | ~10 | Conventional commit format with Co-Authored-By | merge-maintainer, code-maintainer, developer-impl |
| `refs/brief-template.md` | ~50 | Canonical brief template (currently duplicated in scram-brief/SKILL.md and developer-breakdown.md) | developer-breakdown, scram-solo orchestrator |
| `refs/scramstorm-output-formats.md` | ~120 | Three output format templates (single_recommendation, ranked_options, exploration) | scramstorm orchestrator (Phase 6 only) |
| `refs/scramstorm-personas.md` | ~40 | Personality table, debate role descriptions | scramstorm orchestrator (dispatch prompts) |

### How agents use refs

Agent files contain pointers, not content:

```markdown
### Merging
Read `${CLAUDE_PLUGIN_ROOT}/refs/merge-protocol.md` before executing any merge.
```

The agent reads the file on-demand, only when it actually needs to perform that action. For sessions where no merge happens, those tokens are never spent.

## Component 6: Mechanical State Enforcement

### 6a. `scram-state.sh` — Gate state machine

**File:** `scram/scripts/scram-state.sh`

```bash
scram-state.sh init <workspace>                    # Write initial state (G0)
scram-state.sh advance <workspace> <gate>          # Transition to next gate (validates ordering)
scram-state.sh advance <workspace> <gate> --skip   # Record gate omission
scram-state.sh current <workspace>                 # Print current gate
scram-state.sh check <workspace> <gate>            # Exit 0 if gate reached, exit 1 if not
scram-state.sh require <workspace> <gate>          # Exit 0 if currently AT gate, exit 1 if not
```

Valid transitions (hardcoded): `G0 → G1 → G2 → G3 → streams → G4 → G5 → complete`

`streams` is a valid `current_gate` value in `session.md`. It represents the concurrent phase between G3 and G4. The state machine treats it as a gate for transition purposes even though it is a phase — this simplifies the model without loss of expressiveness.

Out-of-order `advance` calls exit 1 with an error message explaining the valid next state. Skipped gates use `--skip` flag that records the omission in both `session.md` and `events/stream.log`.

**Hook integration:** State checking is embedded in the existing `halt-check.sh` script (not a separate hook entry). When `SCRAM_WORKSPACE` is set, `halt-check.sh` calls `scram-state.sh require streams` before allowing Agent dispatch during the streams phase. This keeps `hooks.json` simple — one PreToolUse Agent hook, not two.

### Updated hooks.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/halt-check.sh", "timeout": 10 }]
      },
      {
        "matcher": "Write",
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/brief-lint.sh", "timeout": 5 }]
      },
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/merge-guard.sh", "timeout": 5 }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Agent",
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/isolation-check.sh", "timeout": 10 }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-checkpoint.sh", "timeout": 5 }]
      }
    ]
  }
}
```

The hook configuration is unchanged from v7 except for a timeout bump on `halt-check.sh` (5 → 10) to accommodate the additional `scram-state.sh` call. All new enforcement logic is embedded in the existing scripts, not as new hook entries.

### 6b. `scram-backlog.sh` — Story state tracking

**File:** `scram/scripts/scram-backlog.sh`

```bash
scram-backlog.sh status <workspace> <story-slug>           # Print story status
scram-backlog.sh transition <workspace> <story-slug> <new>  # Validate and update status
scram-backlog.sh dispatchable <workspace>                   # List stories ready for dispatch
scram-backlog.sh blocked <workspace>                        # List stories blocked by dependencies
```

Valid story transitions (hardcoded): `pending → in_progress → in_review → merged` and `failed → escalated → in_progress`

The `dispatchable` command checks:
- Story status is `pending`
- All dependencies have status `merged`
- No HALT file exists
- SCRAM state is `streams`

Returns a newline-separated list of dispatchable story slugs, or empty if none.

### 6c. Enhanced existing scripts

| Script | Enhancement |
|--------|-------------|
| `halt-check.sh` | Also calls `scram-state.sh` — blocks dispatch if not in `streams` phase |
| `isolation-check.sh` | Also calls `scram-backlog.sh transition <story> in_progress` on successful isolation |
| `pre-merge-check.sh` | Also calls `scram-backlog.sh status` to verify story is `in_review`. Note: this script is called explicitly by the merge-maintainer before merging (per its agent definition), not via hooks.json. |
| `session-checkpoint.sh` | Also flushes `retro/in-flight.md` with `[FLUSH — checkpoint]` timestamp |

### 6d. Failure class coverage

| Failure class | v7 mitigation | v8 mitigation |
|--------------|---------------|---------------|
| Worktree violation | Prose + PostToolUse hook | Same hook + `scram-state.sh require streams` |
| Bundled multi-story diffs | Prose prohibition | `scram-backlog.sh` enforces one story `in_progress` per agent |
| Out-of-order gate operations | Prose ("gates are sequential") | `scram-state.sh` blocks invalid transitions |
| Dispatching blocked stories | Prose ("check backlog status first") | `scram-backlog.sh dispatchable` returns only valid targets |
| Lost in-flight observations | Prose ("flush before checkpoint") | `session-checkpoint.sh` auto-flushes in-flight.md |
| Cross-story type drift | Prose logging instruction | `scram-backlog.sh transition merged` logs a `[type-drift]` entry to `retro/in-flight.md` listing the story slug and any shared types/schemas in the story's deliverables (parsed from the brief's `## Type Contracts` section). Maintainers review the accumulated log at wave boundaries — this is a reporting mechanism, not an automated scan. |

**Principle:** If a failure has appeared in 2+ retros, it gets a script. Prose instructions are for judgment calls. Mechanical enforcement is for invariants.

## Agent File Changes

All agents shrink by extracting shared procedures to `refs/`.

| Agent | v7 lines | v8 lines (est.) | Change |
|-------|---------|-----------------|--------|
| developer-impl.md | 163 | ~120 | TDD phases → `refs/tdd-discipline.md`, report → `refs/report-formats.md` |
| developer-breakdown.md | 192 | ~120 | Brief template → `refs/brief-template.md`, report → `refs/report-formats.md` |
| developer-reviewer.md | 53 | ~50 | Minimal change (already lean) |
| merge-maintainer.md | 188 | ~100 | Merge mechanics, conflict resolution, commit format, tracker → `refs/`, review checks → `refs/review-checklist.md` |
| code-maintainer.md | 150 | ~80 | Merge mechanics, commit format, tracker → `refs/`, review checks → `refs/review-checklist.md` |
| doc-specialist.md | 131 | ~110 | Report → `refs/report-formats.md` |
| designer.md | 69 | ~65 | Minimal change |
| critic.md | 82 | ~80 | Minimal change |
| marketer.md | 70 | ~65 | Minimal change |
| dev-tooling-maintainer.md | 87 | ~80 | Minimal change |
| **Total** | **1,185** | **~870** | **27% reduction** |

## Sub-Skill Changes

| Sub-skill | Change |
|-----------|--------|
| `scram-brief/SKILL.md` | Brief template extracted to `refs/brief-template.md`. Skill becomes a pointer + complexity/resolution/priority tables. |
| `scram-session/SKILL.md` | Unchanged — workspace schema and session manifest format stay as-is. |
| `scram-escalation/SKILL.md` | Unchanged — failure taxonomy and escalation path stay as-is. |
| `scram-retro/SKILL.md` | Unchanged — retro facilitator is already well-scoped. |

## Token Impact Summary

| Scenario | v7 prompt cost (lines) | v8 prompt cost (lines) | Reduction |
|----------|----------------------|----------------------|-----------|
| Solo run (orchestrator + dev + reviewer) | ~920 | ~370 | **60%** |
| Sprint run (upfront agent prompts) | ~1,260 | ~720 | **43%** |
| Sprint run (including on-demand refs/) | ~1,260 | ~970 | **23%** (but refs/ only loaded when needed) |
| Scramstorm run | ~555 | ~400 | **28%** |

## Directory Structure (v8)

```
scram/
├── .claude-plugin/
│   └── plugin.json                    # version: 8.0.0
├── agents/
│   ├── code-maintainer.md             # rewritten (~80 lines)
│   ├── critic.md                      # minimal change
│   ├── designer.md                    # minimal change
│   ├── dev-tooling-maintainer.md      # minimal change
│   ├── developer-breakdown.md         # rewritten (~120 lines)
│   ├── developer-impl.md             # rewritten (~120 lines)
│   ├── developer-reviewer.md         # minimal change
│   ├── doc-specialist.md             # trimmed (~110 lines)
│   ├── marketer.md                   # minimal change
│   └── merge-maintainer.md           # rewritten (~100 lines)
├── docs/
│   └── adr/
│       ├── 001-005 (existing)
│       ├── 006-modular-decomposition.md
│       ├── 007-mechanical-state-enforcement.md
│       └── 008-refs-extraction.md
├── hooks/
│   └── hooks.json                     # enhanced with state checks
├── refs/                              # NEW — shared primitives
│   ├── brief-template.md
│   ├── commit-format.md
│   ├── merge-protocol.md
│   ├── report-formats.md
│   ├── review-checklist.md
│   ├── scramstorm-output-formats.md
│   ├── scramstorm-personas.md
│   └── tdd-discipline.md
├── scripts/
│   ├── tests/
│   │   ├── test-hook-enforcement.sh
│   │   ├── test-script-fixes.sh
│   │   ├── test-scram-state.sh        # NEW
│   │   └── test-scram-backlog.sh      # NEW
│   ├── brief-lint.sh
│   ├── halt-check.sh                  # enhanced
│   ├── isolation-check.sh             # enhanced
│   ├── merge-guard.sh
│   ├── pre-merge-check.sh             # enhanced
│   ├── scram-backlog.sh               # NEW
│   ├── scram-discover.sh
│   ├── scram-init.sh
│   ├── scram-state.sh                 # NEW
│   ├── scramstorm-handoff.sh
│   ├── session-checkpoint.sh          # enhanced
│   └── worktree-init.sh
├── skills/
│   ├── scram/
│   │   └── SKILL.md                   # rewritten as dispatcher (~100 lines)
│   ├── scram-brief/
│   │   └── SKILL.md                   # trimmed (template → refs/)
│   ├── scram-escalation/
│   │   └── SKILL.md                   # unchanged
│   ├── scram-retro/
│   │   └── SKILL.md                   # unchanged
│   ├── scram-session/
│   │   └── SKILL.md                   # unchanged
│   ├── scram-solo/
│   │   └── SKILL.md                   # NEW (~150 lines)
│   ├── scram-sprint/
│   │   └── SKILL.md                   # NEW (~300 lines, replaces main flow)
│   └── scramstorm/
│       └── SKILL.md                   # trimmed (~400 lines)
└── README.md
```

## Migration

- `/scram` invocation semantics change: it becomes a router, not the full process
- Users who invoke `/scram` get the same experience (it routes automatically)
- Direct invocation of `/scram-solo` and `/scram-sprint` available for users who know what they want
- Existing `~/.scram/` workspaces remain compatible (session manifest format unchanged)
- All existing hooks continue to fire (new hooks are additive)

## Deprecated/Removed Features

Explicit accounting for v7 features that do not carry forward:

| v7 Feature | v8 Fate | Rationale |
|-----------|---------|-----------|
| **Quick tier** (orchestrator handles directly, no dev dispatch) | Absorbed by `/scram-solo` | Solo always dispatches a dev agent — the "orchestrator verifies directly" pattern was unreliable and defeated the purpose of review. Solo is the lightweight path. |
| **Nano tier** (≤2 files, `scram/nano/` branches, `--nano` workspace) | Absorbed by `/scram-solo` | The distinction between Nano and Quick was confusing and rarely used correctly. Solo handles all single-story work. |
| **Lightweight tier** (≤3 stories, single maintainer) | Absorbed by sprint single-maintainer mode | Decided at G3 based on actual story sizing, not at G0 based on guesses. |
| **Full tier** | Renamed to `/scram-sprint` | Same flow, leaner delivery. |
| **`run_type: docs`** (docs-only mode) | Preserved in sprint | Sprint supports docs-only runs: code maintainer is omitted, merge maintainer gets sole approval authority, developer report replaces "TDD discipline" with "Verification method." This is a sprint configuration, not a separate tier. |
| **External service staging pattern** | Preserved in sprint | Listed under sprint constraints: external service work uses the staging pattern (write to local files, review, then push). |
| **Stash checks at G0/G4** | Sprint only | Solo has no teardown that interacts with stashes. Sprint preserves stash checks. |
| **`AskUserQuestion` for tracker** | Sprint only | Solo doesn't integrate with external trackers. Sprint preserves tracker integration. |

## Non-Goals

- No changes to the scramstorm brainstorm-to-SCRAM handoff protocol (already works)
- No changes to the retro facilitator (already well-scoped)
- No changes to the escalation taxonomy (already well-scoped)
- No new agent roles
- No changes to the New Gods naming convention
