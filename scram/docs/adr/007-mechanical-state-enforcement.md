# ADR 007: Mechanical State Enforcement

## Status
Accepted

## Context
Recurring failures across 10+ retrospective issues traced to agents ignoring prose instructions: worktree violations, out-of-order gate operations, dispatching blocked stories, bundled multi-story diffs, lost in-flight observations. The v7 mitigation was more prose — which agents continued to ignore.

## Decision
Add two new scripts that mechanically enforce invariants:
- `scram-state.sh` — gate state machine that blocks out-of-order transitions
- `scram-backlog.sh` — story state tracking that validates transitions and provides dependency-aware dispatch lists

These integrate with existing hooks: `halt-check.sh` calls `scram-state.sh` before agent dispatch; `isolation-check.sh` calls `scram-backlog.sh` on successful isolation; `pre-merge-check.sh` verifies story status before merge.

## Consequences
- Gate ordering and story transitions are mechanically enforced, not prose-described
- Scripts become critical path — if they break, SCRAM is blocked
- Existing hook infrastructure reused (no new hook entries in hooks.json)
- Principle established: if a failure appears in 2+ retros, it gets a script
