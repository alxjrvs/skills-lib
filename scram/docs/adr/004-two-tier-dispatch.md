# ADR-004: Two-Tier Dispatch — Skip Worktree Isolation for Read-Only Operations

## Status
Accepted

## Context
Worktree isolation is a safety mechanism for concurrent file modification. It prevents agents from committing to the wrong branch when multiple dev agents are working in parallel. The isolation contract — four verification checks, re-verify before commit, HALT on failure — is appropriate for implementation work.

Doc review (G1/G2) and story breakdown (G3) are read-only or write-to-workspace-only operations. They do not modify the main codebase. Applying full worktree isolation to these operations creates unnecessary git overhead and is the proximate cause of a recurring class of isolation failures: when a G1 reviewer or G3 brief writer is dispatched with worktree isolation, they receive a branch checkout instruction they must comply with. If the checkout fails silently or the agent forgets to execute it, the agent operates on the integration branch. Six of fourteen SCRAM retro issues over the project's history trace to this pattern.

## Decision
Replace universal worktree isolation with a two-tier dispatch model.

**Tier 1 — Implementation stories (streams).** `isolation: "worktree"` applies as today. Dev agents working on implementation stories check out a story branch from the integration branch and commit there. The full isolation contract applies: four verification checks, re-verify before every commit, HALT on failure.

**Tier 2 — Read-only operations (G1, G2, G3).** Standard one-shot dispatch without worktree isolation. No story branch, no git operations, no isolation contract. The agent reads files and writes to `SCRAM_WORKSPACE/` only. There is no branch to accidentally commit to because no branch is created.

Operations moved to Tier 2:
- G1 doc review (developer-reviewer): reads docs and ADRs, writes a review report to the workspace. No code files modified.
- G2 doc review (same pattern): reads docs, writes a review to the workspace. No code files modified.
- G3 story breakdown (developer-breakdown): reads the docs-as-spec, writes context briefs to `SCRAM_WORKSPACE/briefs/`. No repo files modified.

Exception: the doc specialist dispatched for ADR and user-facing doc writing at G1/G2 IS writing files to the repo and warrants worktree isolation. The tier boundary is: reviewers are read-only (Tier 2); writers are isolated (Tier 1).

SKILL.md dispatch instructions for G1 reviewer, G2 reviewer, and G3 developer lose the `isolation: "worktree"` parameter. The text clarifies that dev reviewers and brief writers operate without worktree isolation and write only to `SCRAM_WORKSPACE/`, not to the repo.

If ADR-001 is implemented, `developer-reviewer.md` and `developer-breakdown.md` have no isolation contract section — the contract exists only in `developer-impl.md`. The tier distinction becomes explicit at the agent definition level.

## Consequences

### Positive
- A class of worktree isolation failures is eliminated structurally, not through additional prose hardening
- Git overhead decreases for G1, G2, and G3 operations (no worktree creation, no branch cleanup)
- The isolation contract becomes narrower and therefore stronger — it applies only where it matters (implementation), making it easier to reason about and enforce
- If ADR-001 is implemented, the impl agent's isolation contract is the only place the contract lives, not one conditional branch among several

### Negative
- A two-tier dispatch model requires the skill and orchestrator to distinguish between modes explicitly — more dispatch logic, not less
- If a reviewer accidentally modifies a repo file (e.g., fixing a typo during review), there is no isolation to contain the change
- The distinction between "write to workspace" and "write to repo" must be clearly communicated to every Tier 2 agent; without worktree isolation as a structural guarantee, it becomes a prose instruction

### Risks
- Doc reviewers and brief writers must genuinely not need to modify repo files. If any G1/G2/G3 developer case requires writing files outside `SCRAM_WORKSPACE/`, that case requires worktree isolation and must be explicitly accounted for.
- Standard one-shot dispatch must reliably not create worktrees or branch checkouts. If the dispatch mechanism defaults to a worktree even when not specified, the behavior may not change.
- Removing the worktree for G3 brief writing must not shift the failure target — if standard dispatch agents default to main, the failure mode changes destination rather than being eliminated.

## Dependencies
- Requires: ADR-001 (splitting developer agent makes the tier distinction clean — reviewer and breakdown agents simply have no isolation contract)
- Enables: reduced worktree management overhead; the isolation contract in impl mode becomes tighter and more reliably followed because it no longer needs conditional branches for non-implementation modes
