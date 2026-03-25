# Inference-First SCRAM Gates

**Date:** 2026-03-25
**Goal:** Replace most `AskUserQuestion` approval gates with infer-announce-proceed pattern. Reduce total user prompts from ~12 to ~3 across a typical sprint run.

## Principle

The orchestrator infers decisions from context (codebase state, environment, requirements) and announces them as plain text. The user can interrupt naturally if they disagree — no formal approval prompt needed. Only prompt when the decision is irreversible or high-cost (spending agent compute on the wrong stories).

**Kept prompts:**
1. Scope gathering (dispatcher) — can't infer what to build
2. Backlog approval (sprint G3) — last chance before agent dispatch
3. Brief approval (solo) — same rationale as backlog
4. File public issue (retro/scramstorm) — user must verify scrubbing before public post
5. Workspace cleanup (sprint G4) — irreversible deletion of reference artifacts

Everything else becomes infer + announce.

---

## Changes by Skill

### `/scram` (Dispatcher) — `scram/skills/scram/SKILL.md`

#### Section 1: Session Discovery (currently prompts)

**Before:** `AskUserQuestion` — "Resume or start fresh?"
**After:**
- If exactly 1 active session found → auto-resume, announce: `Resuming: <feature> at <gate>`
- If 2+ active sessions found → prompt to pick which one (keep `AskUserQuestion`)
- If 0 sessions found → proceed to scope gathering

#### Section 2: Scramstorm Handoff Check (currently prompts)

**Before:** `AskUserQuestion` — "Did this come from a scramstorm?"
**After:**
- If brainstorm workspace found with `handoff.md` → auto-import, announce: `Imported scramstorm: <workspace>`
- If brainstorm workspace found without `handoff.md` → warn: `Found brainstorm workspace <path> but no handoff.md — skipping (incomplete brainstorm?)`. This alerts the user in case a scramstorm crashed before writing handoff.
- If no workspace found → skip silently

#### Section 3: Scope Assessment (currently 2 prompts)

**Before:** Two separate `AskUserQuestion` prompts — "What are you building?" + "What is explicitly out of scope?"
**After:** Single prompt — "What are you building?" Infer scope boundaries from the answer and codebase analysis. If boundaries are genuinely ambiguous, ask a targeted follow-up (not a generic "what's out of scope?" prompt).

#### Section 5: Confirm and Invoke (currently prompts)

**Before:** `AskUserQuestion` — "Route to X?" with override option
**After:** Announce route and rationale, proceed immediately. `Routing: sprint (shared state detected, 2+ stories)`. Remove the override prompt entirely — if the user disagrees, they'll say so.

### `/scram-sprint` — `scram/skills/scram-sprint/SKILL.md`

#### G0: External Tracker (currently prompts)

**Before:** `AskUserQuestion` — "Do you have an external tracker?" (offered GitHub Issues, Linear, Jira, none)
**After:**
- Check for `gh` CLI availability (`which gh`)
- If available → default to GitHub Issues, announce: `Tracker: GitHub Issues (gh detected)`
- If not available → default to none, announce: `Tracker: none`
- No prompt
- **Note:** Linear and Jira support is intentionally dropped from the auto-detection path. These integrations were rarely used and require MCP or API tokens that can't be reliably auto-detected. Users who need them can interrupt and specify.

#### G0: Gate-Omit Assessment (currently 3-question prompt)

**Before:** `AskUserQuestion` with 3 questions about G1/G2/G3
**After:** Infer from requirements analysis:
- **G1 (ADRs):** Include if requirements mention new dependencies, schema changes, new abstractions, or technology choices. Detect by scanning for keywords like "new package", "database", "migration", "schema", "dependency", "architecture".
- **G2 (Docs):** Include if requirements mention user-facing behavior changes, new APIs, CLI changes, or public interfaces.
- **G3 (Breakdown):** Skip if prior scramstorm provided briefs (check `handoff.md` and verify `briefs` list is non-empty). If `handoff.md` exists but `briefs: []` is empty, include G3 — the scramstorm produced options but not implementation-ready briefs.
- Announce: `Gates: G1 (new schema), G3 | Skipped: G2 (no user-facing changes)`

#### G0: Team Roster (currently prompts)

**Before:** Display roster + `AskUserQuestion` — "Does this team roster look right?"
**After:** Auto-compose team based on scope signals:
- UI/UX files in scope → include Designer (Esak)
- CI/CD, build config, hooks in scope → include Dev Tooling (Himon)
- Public-facing docs, README, CLI help → include Marketer (Glorious Godfrey)
- Scale dev count to story count (1 dev per story, max 5)
- Announce roster as plain text block, proceed immediately

#### G3: Backlog Approval (KEPT)

No change. This remains a full `AskUserQuestion` prompt. The backlog is the point of no return before agent compute is spent.

#### G4: Retrospective (currently prompts)

**Before:** `AskUserQuestion` — "Would you like a team retrospective?"
**After:** Default yes. Announce: `Running retrospective`. The retro dispatches agent compute (multi-phase), but the cost is bounded (2 one-shot maintainer dispatches + synthesis) and the value is consistently high — retros are how SCRAM improves itself. Auto-proceed to G5.

#### G4: Workspace Cleanup (KEPT)

**Before:** `AskUserQuestion` — "Clean up workspace and worktrees?"
**After:** Kept as-is. Workspace deletion is irreversible and destroys retro artifacts, briefs, and session logs that have reference value. This prompt stays.

### `/scram-solo` — `scram/skills/scram-solo/SKILL.md`

#### Brief Approval (KEPT)

No change. This is the one checkpoint in solo.

#### Escape Hatch (KEPT)

No change. This is conditional on failure — it only fires when scope is exceeded.

### `/scramstorm` — `scram/skills/scramstorm/SKILL.md`

#### Issue Tracker (currently prompts)

**Before:** `AskUserQuestion` — "Record to issue tracker?"
**After:** Same inference as sprint — default none, auto-detect `gh`. Announce.

#### Team Approval (currently prompts)

**Before:** Display roster + `AskUserQuestion` — "Does this brainstorm team look right?"
**After:** Auto-compose based on problem domain:
- User-facing / API ergonomics → include Beautiful Dreamer
- Problem feels stuck / false dichotomy → include Scott Free
- CI/CD / toolchain → include Himon
- Public docs / SEO / onboarding → include Godfrey
- Needs adversarial critique → include Desaad
- Announce roster, proceed

#### Retrospective (currently prompts)

**Before:** `AskUserQuestion` — "Run retro?"
**After:** Default yes. Auto-run retro.

#### File Issue (KEPT)

**Before:** `AskUserQuestion` — "File retro results as an issue?"
**After:** Kept as-is. The issue is filed on a public GitHub repo and the user must verify business-specific information has been scrubbed before posting.

### `/scram-retro` — `scram/skills/scram-retro/SKILL.md`

#### File Issue (KEPT)

**Before:** `AskUserQuestion` — "File retro results as an issue?"
**After:** Kept as-is. Same rationale as scramstorm — public issue requires user verification of scrubbing.

---

## Implementation Plan

Each skill file gets surgical edits — replace `AskUserQuestion` blocks with inference logic and announce text. No structural changes to the skills otherwise.

**Files to modify:**
1. `scram/skills/scram/SKILL.md` — sections 1, 2, 3, 5
2. `scram/skills/scram-sprint/SKILL.md` — G0 (tracker, gate-omit, team), G4 (retro)
3. `scram/skills/scramstorm/SKILL.md` — tracker, team, retro

**Files unchanged:**
- `scram/skills/scram-solo/SKILL.md` — only has 2 essential prompts (brief approval + escape hatch)
- `scram/skills/scram-retro/SKILL.md` — file issue prompt kept (public repo, needs scrub verification)
- `scram/skills/scram-session/SKILL.md` — reference doc, no prompts
- `scram/skills/scram-brief/SKILL.md` — reference doc, no prompts
- `scram/skills/scram-escalation/SKILL.md` — reference doc, no prompts

**Version bump:** Bump `scram/.claude-plugin/plugin.json` version (minor bump — behavior change, not breaking).
