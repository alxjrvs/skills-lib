# ADR-001: Split Developer Agent Into Mode-Specific Agents

## Status
Accepted

## Context
The current `developer.md` agent handles three fundamentally different dispatch modes — doc review (G1/G2), story breakdown (G3), and TDD implementation (streams) — in a single 165-line prompt. Every dispatch of a doc reviewer loads TDD phase descriptions they will never use. Every dispatch of a brief writer loads the isolation contract that does not apply to them. Mode-inference happens at runtime through prose branching, which creates ambiguity when dispatch context is unclear. Additionally, the current file has a duplicate step 3 numbering bug and a redundant branch-verification block that arose precisely because three modes are patched together into one file.

Story-specific checklists (shared-state, call-boundary, async/lifecycle, test-update) currently live in the base impl agent as conditional blocks, consuming context on every dispatch even for stories that touch none of those domains.

## Decision
Replace `developer.md` with three focused agent files:

- `developer-reviewer.md` — G1/G2 dispatch only. Contains doc review evaluation criteria (feasibility, testability, ambiguity, architecture fit) and the reviewer report format. No TDD machinery, no isolation contract.
- `developer-breakdown.md` — G3 dispatch only. Contains story sizing judgment, complexity tagging, context brief authoring instructions (content-anchored locators, no line numbers), and the brief format. No implementation phases, no git isolation.
- `developer-impl.md` — Stream dispatch only. Contains the isolation contract, a single pre-flight verification step, the RED/GREEN/REFACTOR phases, the structured Story Report format, and commit discipline.

Story-specific checklists move out of `developer-impl.md` and into the context brief template as a per-story `## Checklist` section. The brief for each story carries only the relevant checklist; the impl agent reads it from the brief.

The orchestrator dispatch prompt routes to the correct agent by name. The SKILL.md orchestration flow already knows which mode is being dispatched at each gate — routing is a zero-ambiguity decision.

The duplicate step 3 numbering bug and redundant isolation-contract/pre-flight branch verification are resolved structurally during the split rather than patched in place.

## Consequences

### Positive
- Each agent carries only the context it needs — no dead weight per dispatch
- The impl agent shrinks by approximately 30–40%
- A dev dispatched for G1 review pays no context cost for TDD phases
- Each agent is independently improvable without risk to the other modes
- The duplicate step numbering and redundant branch check are eliminated by structure, not by patching
- Story-specific checklists become per-story relevant in the brief rather than universally loaded

### Negative
- Three files to maintain instead of one
- Any constraint that applies to all modes (e.g., a new universal convention) must be updated in three places
- The orchestrator skill must reference the correct agent file name for each mode — a typo in the dispatch silently breaks that mode

### Risks
- The orchestrator must reliably know which mode to dispatch before firing the agent. If ambiguous intermediate states exist where mode is unclear, a router agent would be needed first.
- Story-specific checklists must be usable in brief format. If they require agent judgment to apply rather than just reading, they may still need to live in the impl agent prompt.
- Splitting must not exceed any plugin file-count limit or break `claude plugin validate`.

## Dependencies
- Requires: none
- Enables: ADR-003 (duplication between SKILL.md and agents becomes easier to resolve once agents are focused), ADR-004 (non-implementation modes become obviously safe to run without worktree isolation once they have their own agent files)
