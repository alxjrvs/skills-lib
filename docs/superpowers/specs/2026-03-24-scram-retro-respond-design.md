# scram-retro-respond Design Spec

**Date:** 2026-03-24
**Status:** Draft
**Skill location:** `.claude/skills/scram-retro-respond/SKILL.md`

## Purpose

A user-invocable skill that consumes open retro issues filed by `scram-retro` (the G5 gate). It investigates the feedback via scramstorm, dispatches a scram team to address changes, bumps the SCRAM plugin version, comments on the retro issues with the new version number, commits, and pushes to main.

This is the **consumer** end of the retro lifecycle. `scram-retro` creates issues; `scram-retro-respond` resolves them.

## Pipeline

Six sequential phases:

### Phase 1: Observe

Query GitHub for open retro issues:

```bash
gh issue list --repo alxjrvs/skills --label retrospective --state open --json number,title,body
```

Parse issue bodies to extract individual retro items (numbered list items within sections like "Agreed Changes", "Disagreements", etc.). If no open retro issues exist, exit early with a message.

### Phase 2: Scramstorm

Invoke `/scramstorm` with the retro items as the problem frame. This is a normal interactive scramstorm — the user participates in confirming the team roster, problem frame, and voting. The skill sets up the context (retro items as the problem statement), then scramstorm runs its full interactive pipeline and produces its standard `options.md` + `handoff.md` output.

**User interaction expected:** The user will be prompted during the scramstorm for confirmations and decisions. This is by design — retro response benefits from human judgment on which fixes to pursue.

### Phase 3: Triage

Custom orchestrator phase. Read the scramstorm output and build a **triage map** — a structured in-context artifact (not persisted to disk):

```yaml
triage:
  semver: minor | patch
  rationale: "<why this semver level>"
  issues:
    - number: <issue number>
      title: "<issue title>"
      items:
        - id: <item number within issue>
          summary: "<item title>"
          status: addressed | out-of-scope
          scramstorm_option: "<which scramstorm option was selected>"
          reason: "<why out-of-scope, or null>"
  close_decisions:
    - number: <issue number>
      action: close | comment-only
      addressed_count: <n>
      total_count: <n>
```

**Semver determination:** If any addressed item introduces new behavior or process gates, the bump is `minor`. If all items are refinements to existing behavior, the bump is `patch`.

**Purpose:** This map drives Phases 4-6:
- Phase 4 uses addressed items to build the scram backlog
- Phase 5 uses `semver` to determine the version bump
- Phase 6 uses `close_decisions` to determine comment content and whether to close

**User checkpoint:** Present the triage map to the user for approval before proceeding to Phase 4. The user may reclassify items (addressed ↔ out-of-scope) or override the semver decision.

### Phase 4: Execute

Scope-assess based on addressed item count:

- **1-2 addressed items** — invoke `/scram-solo` for each item sequentially. Each solo run gets a context brief written in the format expected by `${CLAUDE_PLUGIN_ROOT}/refs/brief-template.md`, derived from the scramstorm handoff for that specific item.
- **3+ addressed items** — invoke `/scram` (the router, which will route to sprint). The scramstorm's `handoff.md` (filtered to addressed items only) is already in the format `/scram` expects when detecting brainstorm handoffs (`~/.scram/brainstorm--*`).

For the solo path, items are processed sequentially to avoid branch conflicts. Both paths involve normal interactive flows — the user participates in scram decisions as usual.

**Failure policy:** If a solo run fails (dev agent failure, review rejection), the orchestrator skips that item, marks it as `failed` in the triage map, and continues with remaining items. Failed items are reported alongside out-of-scope items in Phase 6 comments. If a sprint run fails, the orchestrator halts and surfaces the failure to the user — sprint failures are too complex to skip past.

### Phase 5: Finalize

After scram run(s) complete:

1. Bump version in `scram/.claude-plugin/plugin.json` per triage semver decision
2. Commit: `chore(scram): bump version to X.Y.Z`
3. Push to main: `git push`

The scram runs commit their own implementation changes directly to main (solo) or via integration branch merge at G4 (sprint). Either way, main has all changes before the version bump. The version bump is the final commit on top.

### Phase 6: Report

Iterate over each retro issue from the triage map:

**All items addressed** — comment and close:
```bash
gh issue comment <number> --repo alxjrvs/skills --body "Addressed in v<version>. All items resolved."
gh issue close <number> --repo alxjrvs/skills
```

**Partial — some out-of-scope or failed** — comment and leave open:
```bash
gh issue comment <number> --repo alxjrvs/skills --body "v<version> addressed items: #1, #2, #3. Deferred: #4 (<reason>). Leaving open."
```

**Lifecycle for deferred items:** On subsequent `/scram-retro-respond` runs, the same issue will be picked up again (it's still open). The new scramstorm will re-evaluate deferred items. Issues may accumulate multiple version comments across runs — this is expected and provides an audit trail.

## Design Decisions

### Project-level skill, not plugin skill

This skill orchestrates the SCRAM plugin's tools but is specific to this repo's workflow (alxjrvs/skills). It lives in `.claude/skills/`, not inside `scram/skills/`.

### Thin orchestrator with triage phase (Approach C)

The skill reuses existing skills (`/scramstorm`, `/scram-solo`, `/scram`) and adds only the triage mapping phase. This avoids duplicating scramstorm/scram logic while giving the conditional-close requirement a solid data foundation.

### No new agents, scripts, or hooks

All GitHub operations use `gh` CLI directly. The triage map is an in-context artifact. This keeps the surface area minimal.

### Scope assessment routes to solo or sprint

1-2 items use sequential solo runs. 3+ items use the sprint path. This matches the existing SCRAM convention where solo handles small changes and sprint handles larger coordinated work.
