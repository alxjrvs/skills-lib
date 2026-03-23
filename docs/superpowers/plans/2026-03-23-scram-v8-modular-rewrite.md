# SCRAM v8.0.0 Modular Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose SCRAM from a monolithic 566-line skill into composable primitives — a thin dispatcher, purpose-built solo/sprint flows, shared refs/, and mechanical state enforcement scripts.

**Architecture:** Three user-invocable skills (dispatcher, solo, sprint) replace one monolith. Shared procedures extracted to `refs/` files read on-demand. Two new scripts (`scram-state.sh`, `scram-backlog.sh`) enforce gate ordering and story state transitions mechanically.

**Tech Stack:** Bash scripts (POSIX-compatible), Markdown skill/agent files, Claude Code plugin system

**Spec:** `docs/superpowers/specs/2026-03-23-scram-v8-modular-rewrite-design.md`

---

## Dependency Graph

```
Task 1 (refs/)  ─────────────────────────────┐
Task 2 (scram-state.sh + tests) ────────┐    │
Task 3 (scram-backlog.sh + tests) ──┐   │    │
                                     │   │    │
Task 4 (enhance existing scripts) ◄──┴───┘    │
                                              │
Task 5 (agent rewrites) ◄────────────────────┘
Task 6 (scram-brief trim) ◄──────────────────┘
Task 7 (scramstorm trim) ◄───────────────────┘
                                              │
Task 8 (scram-sprint SKILL.md) ◄──── 1,4,5 ──┘
Task 9 (scram-solo SKILL.md) ◄────── 1,5
                                     │
Task 10 (scram dispatcher) ◄── 8,9 ──┘
Task 11 (ADRs + version bump) ◄── all prior
Task 12 (validate + cleanup) ◄── 11
```

Tasks 1-3 are independent and can run in parallel. Tasks 5-7 depend on 1. Task 4 depends on 2+3. Task 8 (sprint) depends on 1+4+5. Task 9 (solo) depends on 1+5 only (solo does not use state machine scripts). Task 10 depends on 8+9. Tasks 11-12 are sequential finalization.

---

### Task 1: Create refs/ shared primitives

**Files:**
- Create: `scram/refs/merge-protocol.md`
- Create: `scram/refs/review-checklist.md`
- Create: `scram/refs/tdd-discipline.md`
- Create: `scram/refs/report-formats.md`
- Create: `scram/refs/commit-format.md`
- Create: `scram/refs/brief-template.md`
- Create: `scram/refs/scramstorm-output-formats.md`
- Create: `scram/refs/scramstorm-personas.md`
- Source: `scram/agents/merge-maintainer.md` (merge mechanics, conflict resolution, commit format, tracker updates, review checklist)
- Source: `scram/agents/code-maintainer.md` (review checks, report format)
- Source: `scram/agents/developer-impl.md` (TDD phases, report format)
- Source: `scram/agents/doc-specialist.md` (report format)
- Source: `scram/skills/scram-brief/SKILL.md` (brief template)
- Source: `scram/agents/developer-reviewer.md` (report format)
- Source: `scram/skills/scramstorm/SKILL.md` (output formats, persona table)

Extract shared content from source files into refs/ files. Each ref file is a standalone reference document — no frontmatter, no skill metadata. Just the procedure/template/checklist.

- [ ] **Step 1: Read all source files** to identify exact content to extract

- [ ] **Step 2: Create `refs/commit-format.md`**

Extract from `merge-maintainer.md` § Commit Format:
```markdown
# Commit Format

```
<type>(<scope>): <description>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
Scope: the package or area changed (e.g., `scram`, `auth`, `api`)
```

- [ ] **Step 3: Create `refs/merge-protocol.md`**

Extract from `merge-maintainer.md` § Merging + § Conflict Resolution + § Tracker Updates. Include:
- Pre-merge git health checks (copy files from worktree, stage specific files, no `git add -A`)
- Commit with conventional format (reference `refs/commit-format.md`)
- Post-merge test suite run
- Worktree removal
- Conflict resolution (trivial vs. substantive)
- Tracker update procedures
- "One atomic commit per story" rule
- "If tests fail after merge: revert immediately" rule

- [ ] **Step 4: Create `refs/review-checklist.md`**

Extract from `merge-maintainer.md` § Code Review checks + `code-maintainer.md` § Code Review checks. Consolidate into a single checklist. Include:
- Diff isolation (changed files match brief deliverables)
- Ancestry check (branch from integration, not main)
- Commit count (exactly 1)
- Generated type parity
- Scope discipline (reject untraceable code)
- Deletion verification
- Cross-story type drift logging
- ADR deviation tracking
- Pre-merge-check.sh invocation

- [ ] **Step 5: Create `refs/tdd-discipline.md`**

Extract from `developer-impl.md` § RED, § GREEN, § REFACTOR. Include:
- RED phase rules (tests compile, fail as expected, no implementation)
- GREEN phase rules (minimum code, make it pass, no refactor)
- REFACTOR phase rules (clarity, conventions, tests still pass)
- Content-only substitute discipline (schema/validation contract, validate, diff review)

- [ ] **Step 6: Create `refs/report-formats.md`**

Extract from all agent files. Consolidate all report templates:
- Story Report (from developer-impl.md)
- Merge Maintainer Report (from merge-maintainer.md)
- Code Maintainer Report (from code-maintainer.md)
- Doc Report (from doc-specialist.md)
- Developer Reviewer Report (from developer-reviewer.md)

- [ ] **Step 7: Create `refs/brief-template.md`**

Extract the canonical brief template from `scram-brief/SKILL.md` (the ```markdown block). This is the single source of truth — `developer-breakdown.md` and `scram-brief/SKILL.md` will both reference it instead of carrying copies.

- [ ] **Step 8: Create `refs/scramstorm-output-formats.md`**

Extract from `scramstorm/SKILL.md` the three output format templates:
- `single_recommendation` format
- `ranked_options` format
- `exploration` format

Include the `Source tickets:` field and `Open Implementation Questions` section added in the recent retro sweep.

- [ ] **Step 9: Create `refs/scramstorm-personas.md`**

Extract from `scramstorm/SKILL.md` the personality/debate-role descriptions:
- Core team personality table (Orion, Metron, Highfather, Forager)
- Optional specialists (Beautiful Dreamer, Scott Free, Himon, Glorious Godfrey, Desaad)
- The "Personality in practice" paragraph

- [ ] **Step 10: Commit**

```bash
git add scram/refs/
git commit -m "feat(scram): add refs/ shared primitives for v8 extraction"
```

---

### Task 2: Create `scram-state.sh` with tests

**Files:**
- Create: `scram/scripts/scram-state.sh`
- Create: `scram/scripts/tests/test-scram-state.sh`

- [ ] **Step 1: Write test file `test-scram-state.sh`**

Test groups:
1. `init` creates state file with `G0`
2. `current` reads current state
3. `advance` from G0 to G1 succeeds
4. `advance` out of order (G0 to G3) fails with exit 1
5. `advance` with `--skip` records skip in events log
6. `check` returns 0 for reached gates, 1 for unreached
7. `require` returns 0 only for current gate
8. Full transition sequence G0 → G1 → G2 → G3 → streams → G4 → G5 → complete
9. `advance` past `complete` fails

Each test creates a temp workspace via `mktemp -d`, runs the command, checks exit code and file contents.

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash scram/scripts/tests/test-scram-state.sh
```

Expected: all tests FAIL (script doesn't exist yet)

- [ ] **Step 3: Implement `scram-state.sh`**

Interface:
```bash
#!/usr/bin/env bash
set -euo pipefail

VALID_GATES="G0 G1 G2 G3 streams G4 G5 complete"
# State stored in: $WORKSPACE/.scram-state

case "$1" in
  init)     # Write G0 to state file
  advance)  # Validate next gate is valid successor, write new state
  current)  # Print current gate
  check)    # Exit 0 if gate is current or past
  require)  # Exit 0 if gate matches current exactly
esac
```

State file: `$WORKSPACE/.scram-state` (single line with current gate name).
Events logged to: `$WORKSPACE/events/stream.log` (JSON lines).

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash scram/scripts/tests/test-scram-state.sh
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git add scram/scripts/scram-state.sh scram/scripts/tests/test-scram-state.sh
git commit -m "feat(scram): add scram-state.sh gate state machine with tests"
```

---

### Task 3: Create `scram-backlog.sh` with tests

**Files:**
- Create: `scram/scripts/scram-backlog.sh`
- Create: `scram/scripts/tests/test-scram-backlog.sh`

- [ ] **Step 1: Write test file `test-scram-backlog.sh`**

Test groups:
1. `status` reads story status from backlog.md
2. `transition` from `pending` to `in_progress` succeeds
3. `transition` invalid (e.g., `pending` to `merged`) fails with exit 1
4. `transition` to `failed` from `in_review` succeeds
5. `transition` to `escalated` from `failed` succeeds
6. `dispatchable` returns only `pending` stories with all deps merged
7. `dispatchable` returns nothing when HALT file exists
8. `dispatchable` returns nothing when a state file shows non-`streams` gate
9. `blocked` returns stories whose deps are not yet merged
10. `transition merged` writes a `[type-drift]` entry to `retro/in-flight.md` if brief has `## Type Contracts` section

Each test creates a temp workspace with a sample `backlog.md` and `.scram-state` file.

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash scram/scripts/tests/test-scram-backlog.sh
```

Expected: all tests FAIL

- [ ] **Step 3: Implement `scram-backlog.sh`**

Interface:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Parses SCRAM_WORKSPACE/backlog.md (markdown table format)
# Status column is updated in-place via sed

case "$1" in
  status)       # Grep backlog.md for story slug, print status column
  transition)   # Validate transition, update status column in backlog.md
  dispatchable) # Filter: pending + deps merged + no HALT + state=streams
  blocked)      # Filter: pending + any dep not merged
esac
```

The script parses the markdown table in `backlog.md`. The table format is defined in `scram/skills/scram-brief/SKILL.md` § Backlog File Format:

```
| # | Story | Priority | Complexity | Resolution | Depends On | UI/UX | Status | Agent | Commit |
```

Status is the 8th pipe-delimited field. Updates use `sed` to replace the status value in-place. Test fixtures should use this exact table format.

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash scram/scripts/tests/test-scram-backlog.sh
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git add scram/scripts/scram-backlog.sh scram/scripts/tests/test-scram-backlog.sh
git commit -m "feat(scram): add scram-backlog.sh story state tracking with tests"
```

---

### Task 4: Enhance existing scripts

**Files:**
- Modify: `scram/scripts/halt-check.sh`
- Modify: `scram/scripts/isolation-check.sh`
- Modify: `scram/scripts/pre-merge-check.sh`
- Modify: `scram/scripts/session-checkpoint.sh`
- Modify: `scram/hooks/hooks.json`

Depends on: Tasks 2 and 3 (new scripts must exist)

- [ ] **Step 1: Read current versions of all four scripts**

- [ ] **Step 2: Enhance `halt-check.sh`**

Add after the existing HALT file check:
```bash
# State gate check — only during sprint (SCRAM_WORKSPACE with .scram-state)
if [ -f "$SCRAM_WORKSPACE/.scram-state" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if ! "$SCRIPT_DIR/scram-state.sh" require "$SCRAM_WORKSPACE" streams 2>/dev/null; then
    echo "SCRAM state is not in 'streams' phase — agent dispatch blocked" >&2
    exit 1
  fi
fi
```

- [ ] **Step 3: Enhance `isolation-check.sh`**

After the existing successful isolation check, add backlog transition:
```bash
# Mark story as in_progress in backlog (sprint only)
if [ -f "$SCRAM_WORKSPACE/backlog.md" ] && [ -n "$STORY_SLUG" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  "$SCRIPT_DIR/scram-backlog.sh" transition "$SCRAM_WORKSPACE" "$STORY_SLUG" in_progress 2>/dev/null || true
fi
```

- [ ] **Step 4: Enhance `pre-merge-check.sh`**

Add backlog status verification:
```bash
# Verify story is in_review (sprint only)
if [ -f "$SCRAM_WORKSPACE/backlog.md" ] && [ -n "$STORY_SLUG" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  STATUS=$("$SCRIPT_DIR/scram-backlog.sh" status "$SCRAM_WORKSPACE" "$STORY_SLUG" 2>/dev/null || echo "unknown")
  if [ "$STATUS" != "in_review" ]; then
    echo "Story '$STORY_SLUG' is not in_review (current: $STATUS) — merge blocked" >&2
    exit 1
  fi
fi
```

- [ ] **Step 5: Enhance `session-checkpoint.sh`**

Add in-flight flush:
```bash
# Flush in-flight observations
IN_FLIGHT="$SCRAM_WORKSPACE/retro/in-flight.md"
if [ -f "$IN_FLIGHT" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [FLUSH — context checkpoint]" >> "$IN_FLIGHT"
fi
```

- [ ] **Step 6: Update `hooks.json`**

Change halt-check.sh timeout from 5 to 10:
```json
{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/halt-check.sh", "timeout": 10 }
```

- [ ] **Step 7: Run existing test suites to verify no regressions**

```bash
bash scram/scripts/tests/test-hook-enforcement.sh
bash scram/scripts/tests/test-script-fixes.sh
```

Expected: all existing tests still PASS

- [ ] **Step 8: Commit**

```bash
git add scram/scripts/halt-check.sh scram/scripts/isolation-check.sh scram/scripts/pre-merge-check.sh scram/scripts/session-checkpoint.sh scram/hooks/hooks.json
git commit -m "feat(scram): enhance scripts with state machine and backlog integration"
```

---

### Task 5: Rewrite agent files

**Files:**
- Modify: `scram/agents/merge-maintainer.md`
- Modify: `scram/agents/code-maintainer.md`
- Modify: `scram/agents/developer-impl.md`
- Modify: `scram/agents/developer-breakdown.md`
- Modify: `scram/agents/doc-specialist.md`

Depends on: Task 1 (refs/ must exist)

For each agent: read the current file, identify which content was extracted to refs/, replace inline content with `Read ${CLAUDE_PLUGIN_ROOT}/refs/<file>.md` pointers. Preserve all unique content (role description, unique review lens, constraints, persona table).

- [ ] **Step 1: Rewrite `merge-maintainer.md`**

Remove inline content that now lives in refs/:
- § Merging (atomic, per-story) → replace with: `Read ${CLAUDE_PLUGIN_ROOT}/refs/merge-protocol.md before executing any merge.`
- § Conflict Resolution → covered by merge-protocol.md
- § Tracker Updates → covered by merge-protocol.md
- § Commit Format → replace with: `Read ${CLAUDE_PLUGIN_ROOT}/refs/commit-format.md`
- Code Review check items → replace with: `Read ${CLAUDE_PLUGIN_ROOT}/refs/review-checklist.md for the full review checklist.`
- Report Format → replace with: `Read ${CLAUDE_PLUGIN_ROOT}/refs/report-formats.md for the Merge Maintainer Report template.`

Keep: role description, G0 procedure, ADR review (lightweight), Doc review, Approval Tiers, Approval Outcomes, Approval Records, In-Flight Capture, Constraints.

Target: ~100 lines.

- [ ] **Step 2: Rewrite `code-maintainer.md`**

Remove:
- § Merging → replace with pointer to merge-protocol.md
- All "See merge-maintainer.md" references → replace with refs/ pointers
- Review check duplicates → pointer to review-checklist.md
- Report Format → pointer to report-formats.md

Keep: role description, architectural review lens (harmony, DRYness, patterns, deletable code), G0/G1/G2 unique review criteria, shell scripting standards, In-Flight Capture, Constraints reference.

Target: ~80 lines.

- [ ] **Step 3: Rewrite `developer-impl.md`**

Remove:
- § RED, § GREEN, § REFACTOR → replace with: `Read ${CLAUDE_PLUGIN_ROOT}/refs/tdd-discipline.md for the Red-Green-Refactor phases.`
- Story Report template → replace with: `Read ${CLAUDE_PLUGIN_ROOT}/refs/report-formats.md for the Story Report template.`

Keep: persona table, role description, setup (isolation contract), pre-flight, reading instructions, escalation, context management, one-commit self-check, constraints.

Target: ~120 lines.

- [ ] **Step 4: Rewrite `developer-breakdown.md`**

Remove:
- Inline brief template (the full ```markdown block) → replace with: `Read ${CLAUDE_PLUGIN_ROOT}/refs/brief-template.md for the canonical brief format.`

Keep: role description, story sizing, complexity tagging, checklist categories, conventions population, shared interface rule, deletion verification, testing notes population, retry briefs, output rules, story-agent matching, constraints.

Target: ~120 lines.

- [ ] **Step 5: Update `developer-reviewer.md`**

Replace inline report template with pointer to `refs/report-formats.md`. This agent is already lean (~53 lines) — only the report template moves.

- [ ] **Step 6: Trim `doc-specialist.md`**

Remove:
- Report Format template → replace with pointer to report-formats.md

Keep everything else (already lean).

Target: ~110 lines.

- [ ] **Step 7: Verify no broken references**

Search all agent files for any remaining references to content that was moved:
```bash
grep -rn "Commit Format\|Conflict Resolution\|Tracker Updates" scram/agents/
```
Should return only pointer lines, not inline content.

- [ ] **Step 8: Commit**

```bash
git add scram/agents/
git commit -m "refactor(scram): extract shared agent content to refs/, reduce agent sizes ~27%"
```

---

### Task 6: Trim `scram-brief/SKILL.md`

**Files:**
- Modify: `scram/skills/scram-brief/SKILL.md`

Depends on: Task 1 (refs/brief-template.md must exist)

- [ ] **Step 1: Read current scram-brief SKILL.md**

- [ ] **Step 2: Replace inline brief template with pointer**

Replace the full ```markdown template block with:
```
> The canonical brief template is at `${CLAUDE_PLUGIN_ROOT}/refs/brief-template.md`. Agents and orchestrators read the template from disk when authoring briefs.
```

Keep: frontmatter, intro paragraph, story sizing, complexity tagging, resolution mode tagging, UI/UX story tagging, prioritization table, backlog file format.

- [ ] **Step 3: Commit**

```bash
git add scram/skills/scram-brief/SKILL.md
git commit -m "refactor(scram): extract brief template to refs/, trim scram-brief skill"
```

---

### Task 7: Trim `scramstorm/SKILL.md`

**Files:**
- Modify: `scram/skills/scramstorm/SKILL.md`

Depends on: Task 1 (refs/scramstorm-*.md must exist)

- [ ] **Step 1: Read current scramstorm SKILL.md**

- [ ] **Step 2: Replace output format templates with pointer**

Find the three output format blocks (single_recommendation, ranked_options, exploration — each is a markdown code block starting with `### If the user wanted`). Replace all three with:

```
Read `${CLAUDE_PLUGIN_ROOT}/refs/scramstorm-output-formats.md` for the output format templates matching the user's desired outcome (single_recommendation, ranked_options, or exploration).
```

- [ ] **Step 3: Replace persona descriptions with pointer**

Find the personality/debate-role table and descriptions in the team composition section. Replace the detailed personality descriptions with a pointer:

```
Read `${CLAUDE_PLUGIN_ROOT}/refs/scramstorm-personas.md` for personality descriptions and debate roles when dispatching agents.
```

Keep the team composition table (names, agent types) inline — agents need to know WHO is on the team. Move only the HOW (personality descriptions) to refs/.

- [ ] **Step 4: Verify the skill still has complete phase instructions**

The skill should still contain: Frame, Prior Retro Scan, Research, Tickets, Vote, Discuss, Present phases with dispatch instructions. Only the large template blocks and personality prose should be gone.

- [ ] **Step 5: Commit**

```bash
git add scram/skills/scramstorm/SKILL.md
git commit -m "refactor(scram): extract scramstorm output formats and personas to refs/"
```

---

### Task 8: Write `scram-sprint/SKILL.md`

**Files:**
- Create: `scram/skills/scram-sprint/SKILL.md`
- Source: `scram/skills/scram/SKILL.md` (current main skill — this is the primary source)

Depends on: Tasks 1, 4, 5

This is the biggest single task. The sprint skill is the current main SCRAM skill, rewritten to be leaner by:
- Removing tier logic (Full/Lightweight/Quick/Nano)
- Removing dispatcher responsibilities (session discovery, scope assessment, scramstorm handoff)
- Inverting gate-skip to gate-omit
- Referencing refs/ for shared procedures
- Referencing scram-state.sh and scram-backlog.sh for mechanical enforcement

- [ ] **Step 1: Read the current `scram/SKILL.md` in full**

- [ ] **Step 2: Write `scram-sprint/SKILL.md` frontmatter**

```yaml
---
name: scram-sprint
description: Full SCRAM flow for multi-story work — gates, concurrent streams, dual maintainers, integration branch. Use for 2+ stories or shared state changes.
user_invocable: true
---
```

- [ ] **Step 3: Write the skill body — section by section**

The sprint skill is organized by gate. For each section below, the keep/cut/add lists are explicit. Read the corresponding v7 section and apply the delta.

**Section 1: Header + Team Composition (~30 lines)**
- KEEP: "You are the Orchestrator" role definition, team composition table (all 10 roles), agent naming convention, `subagent_type` prefix note, docs-only runs note
- CUT: All tier descriptions (Full/Lightweight/Quick/Nano), tier assessment criteria, "Process discipline" paragraph about degraded SCRAM
- ADD: One-line note: "Sprint is for multi-story work. For single-story work, use `/scram-solo`."

**Section 2: Integration Branch + Workspace (~15 lines)**
- KEEP: Branch model (`scram/<feature-name>`), workspace reference to scram-session skill
- CUT: Nothing
- ADD: `Run scram-state.sh init $SCRAM_WORKSPACE` at workspace creation. `Run scram-init.sh` for directory structure.

**Section 3: G0 Environment Check (~50 lines)**
- KEEP: Stash check precondition, scram_version read, environment checks, gate-boundary events, AskUserQuestion for tracker, team roster presentation and confirmation
- CUT: Session discovery (moved to dispatcher), scramstorm handoff (moved to dispatcher), tier assessment (eliminated), gate-skip criteria table (replaced by gate-omit)
- ADD: Gate-omit questions via AskUserQuestion: "Does this work need new ADRs? New user-facing docs? Are stories already defined?" Only include gates with work to do. Call `scram-state.sh advance $SCRAM_WORKSPACE G0` at gate completion.

**Section 4: G1 ADRs + G2 Docs (~20 lines each, opt-in)**
- KEEP: ADR dispatch and review process, doc dispatch and review process
- CUT: Detailed review criteria (agents read refs/review-checklist.md)
- ADD: Both gates marked as opt-in (included only if G0 determined they have work). State advance calls at completion. Gates omitted via `scram-state.sh advance --skip`.

**Section 5: G3 Story Breakdown (~30 lines)**
- KEEP: Story derivation rules, brief authoring via scram:developer-breakdown, prioritization, backlog creation, tracker issue creation, backlog presentation with AskUserQuestion
- CUT: Inline brief format (agents read refs/brief-template.md)
- ADD: Single-maintainer mode decision after stories sized (≤3 simple → Metron only; 4+ or moderate/complex → full team). State advance. Reference scram-backlog.sh for backlog management.

**Section 6: Concurrent Streams (~80 lines)**
- KEEP: Maintainer team creation (TeamCreate), dev stream dispatch rules (P0 wave, max 5 concurrent, dependency checks, contested files, hook constraint audit), emergency halt + HALT file, mid-stream failure recovery, escalation reference, cherry-pick fallback with bundled diff prohibition, post-G4 hotfix protocol, doc refinement stream with deviation taxonomy, thin orchestrator discipline
- CUT: Inline merge mechanics (agents read refs/merge-protocol.md), inline TDD rules (agents read refs/tdd-discipline.md), inline review checklist items
- ADD: `Use scram-backlog.sh dispatchable to get the dispatch list instead of manual backlog parsing.` `Use scram-backlog.sh transition to update story status.` Docs-only run mode note: when `run_type: docs`, code maintainer omitted, merge maintainer gets sole authority, dev reports use "Verification method" instead of "TDD discipline." External service staging pattern: write to local files, review, then push.

**Section 7: G4 Final Review (~30 lines)**
- KEEP: Team shutdown, commit review, test suite, doc verification, backlog verification, stash cleanup, retro question, merge/PR to main, follow-up story sweep, workspace cleanup
- CUT: Nothing significant
- ADD: State advance. Compressed gate tracking note.

**Section 8: G5 Retrospective (~5 lines)**
- KEEP: Reference to scram-retro skill
- CUT: Nothing
- ADD: State advance to complete.

**Section 9: Constraints (~15 lines)**
- KEEP: Worktree isolation, TDD, no hook skipping, new commits only, one commit per story, workspace outside repo, post-merge fixes through lifecycle, G2 doc specialist requirement, external service staging
- CUT: Duplicates of constraints that appear in agent files
- ADD: Bounded fixup exception (from recent retro sweep)

- [ ] **Step 4: Verify all preserved features are present**

Cross-reference the spec's "Preserved sprint features" list against the written skill. Every item must be accounted for.

- [ ] **Step 5: Commit**

```bash
git add scram/skills/scram-sprint/SKILL.md
git commit -m "feat(scram): add scram-sprint skill — full SCRAM flow for multi-story work"
```

---

### Task 9: Write `scram-solo/SKILL.md`

**Files:**
- Create: `scram/skills/scram-solo/SKILL.md`

Depends on: Tasks 1, 5

- [ ] **Step 1: Write `scram-solo/SKILL.md`**

```yaml
---
name: scram-solo
description: Lightweight single-story SCRAM flow — one dev, one reviewer, no integration branch. Use for 1 story with no shared state changes.
user_invocable: true
---
```

Structure (~150 lines):

1. **Header** — You are the Orchestrator. Solo is a lightweight single-story flow.
2. **Flow diagram** — `Assess → Brief → Implement → Review → Merge`
3. **Solo Workspace** — temp workspace creation (`mktemp -d`), cleanup after merge.
4. **Step 1: Assess** — confirm scope fits solo, redirect to sprint if not.
5. **Step 2: Brief** — orchestrator writes brief directly using `refs/brief-template.md`. User confirms ACs.
6. **Step 3: Implement** — dispatch `scram:developer-impl` with worktree. Branch convention: `scram/solo/<story-slug>`. Solo bypasses worktree-init.sh.
7. **Step 4: Review** — dispatch Metron (one-shot). Single-approval. Reference `refs/review-checklist.md`.
8. **Step 5: Merge** — Metron merges to source branch. Tests pass. Cleanup workspace. Done.
9. **Escape Hatch** — scope_exceeded → offer upgrade to sprint.
10. **Constraints** — worktree isolation, TDD, code review always required.

- [ ] **Step 2: Commit**

```bash
git add scram/skills/scram-solo/SKILL.md
git commit -m "feat(scram): add scram-solo skill — lightweight single-story flow"
```

---

### Task 10: Rewrite `scram/SKILL.md` as dispatcher

**Files:**
- Modify: `scram/skills/scram/SKILL.md` (complete rewrite)

Depends on: Tasks 8 and 9 (solo and sprint must exist)

- [ ] **Step 1: Rewrite `scram/SKILL.md` as the dispatcher**

```yaml
---
name: scram
description: Launch a structured dev team (SCRAM) to implement features in parallel with stream-based development, integration branches, and continuous merging.
user_invocable: true
---
```

Structure (~100 lines):

1. **Header** — You are the SCRAM Dispatcher. You assess scope and route to the right flow.
2. **Session Discovery** — run `scram-discover.sh`, check for existing sessions, offer resume.
3. **Scramstorm Handoff** — check for brainstorm workspace manifests, read `handoff.md`, display gate eligibility.
4. **Scope Assessment** — ask clarifying questions (features, boundaries).
5. **Routing Table** — the signal → route table from the spec. Rules evaluated top-to-bottom.
6. **Confirm and Invoke** — show routing decision, ask for approval, invoke target skill.

- [ ] **Step 2: Verify the dispatcher references solo and sprint correctly**

Check that the dispatcher uses `Skill` tool invocation syntax (not Agent dispatch) to invoke scram-solo and scram-sprint.

- [ ] **Step 3: Commit**

```bash
git add scram/skills/scram/SKILL.md
git commit -m "refactor(scram): rewrite main skill as thin dispatcher routing to solo/sprint"
```

---

### Task 11: ADRs, hooks.json finalization, version bump

**Files:**
- Create: `scram/docs/adr/006-modular-decomposition.md`
- Create: `scram/docs/adr/007-mechanical-state-enforcement.md`
- Create: `scram/docs/adr/008-refs-extraction.md`
- Modify: `scram/.claude-plugin/plugin.json`

- [ ] **Step 1: Write ADR 006 — Modular Decomposition**

Context: SCRAM v7 monolithic skill serves 4 scales via degradation.
Decision: Decompose into dispatcher + solo + sprint.
Consequences: Breaking change to invocation, simpler per-flow logic, eliminated tier system.
Status: Accepted.

- [ ] **Step 2: Write ADR 007 — Mechanical State Enforcement**

Context: Recurring failures from agents ignoring prose instructions.
Decision: Add scram-state.sh and scram-backlog.sh with hook integration.
Consequences: Gate ordering and story transitions mechanically enforced. Scripts become critical path.
Status: Accepted.

- [ ] **Step 3: Write ADR 008 — Refs Extraction**

Context: Agent files duplicate shared procedures (merge, review, TDD, reports).
Decision: Extract to refs/ directory, agents read on-demand.
Consequences: ~27% agent size reduction, single source of truth, risk of agents not reading refs.
Status: Accepted.

- [ ] **Step 4: Bump version to 8.0.0**

In `scram/.claude-plugin/plugin.json`, change `"version": "7.1.1"` to `"version": "8.0.0"`.

- [ ] **Step 5: Commit**

```bash
git add scram/docs/adr/006-modular-decomposition.md scram/docs/adr/007-mechanical-state-enforcement.md scram/docs/adr/008-refs-extraction.md scram/.claude-plugin/plugin.json
git commit -m "feat(scram): add v8 ADRs and bump version to 8.0.0"
```

---

### Task 12: Validate and cleanup

**Files:**
- Verify: all files in `scram/`

- [ ] **Step 1: Run plugin validation**

```bash
claude plugin validate ./scram
```

Expected: validation passes with no errors.

- [ ] **Step 2: Verify no orphaned references**

Search for references to content that no longer exists where expected:
```bash
# Check for agents still carrying inline content that should be in refs/
grep -rn "## RED\|## GREEN\|## REFACTOR" scram/agents/
grep -rn "## Commit Format" scram/agents/
grep -rn "## Conflict Resolution" scram/agents/

# Check for skills referencing old tier names
grep -rn "Quick tier\|Nano tier\|Lightweight\|Full tier" scram/skills/
```

Expected: no matches (all moved to refs/ or removed).

- [ ] **Step 3: Verify refs/ files exist and are non-empty**

```bash
for f in scram/refs/*.md; do echo "$f: $(wc -l < "$f") lines"; done
```

Expected: all 8 files exist with reasonable line counts.

- [ ] **Step 4: Line count comparison**

```bash
echo "=== Skills ==="
wc -l scram/skills/*/SKILL.md
echo "=== Agents ==="
wc -l scram/agents/*.md
echo "=== Refs ==="
wc -l scram/refs/*.md
echo "=== Scripts ==="
wc -l scram/scripts/*.sh
```

Compare against spec projections.

- [ ] **Step 5: Run all script tests**

```bash
bash scram/scripts/tests/test-hook-enforcement.sh
bash scram/scripts/tests/test-script-fixes.sh
bash scram/scripts/tests/test-scram-state.sh
bash scram/scripts/tests/test-scram-backlog.sh
```

Expected: all tests PASS.

- [ ] **Step 6: Final commit (if any cleanup needed)**

```bash
git add -A scram/
git commit -m "chore(scram): v8.0.0 validation and cleanup"
```
