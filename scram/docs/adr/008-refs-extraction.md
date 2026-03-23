# ADR 008: Shared Primitives Extraction (refs/)

## Status
Accepted

## Context
Agent files duplicated shared procedures: merge protocol appeared in both merge-maintainer and code-maintainer, the brief template appeared in both scram-brief skill and developer-breakdown agent, report formats appeared in every agent file. This duplication caused drift (slightly different versions of the same procedure) and token waste (agents loaded identical content multiple times).

## Decision
Extract shared procedures into `scram/refs/` — standalone reference documents that agents read on-demand via the `Read` tool:
- `merge-protocol.md`, `review-checklist.md`, `tdd-discipline.md`
- `report-formats.md`, `commit-format.md`, `brief-template.md`
- `scramstorm-output-formats.md`, `scramstorm-personas.md`

Agent files carry pointers (`Read ${CLAUDE_PLUGIN_ROOT}/refs/<file>.md`) instead of inline content.

## Consequences
- Single source of truth for shared procedures — no drift
- ~27% reduction in agent file sizes (1,185 → ~870 lines)
- Tokens loaded on-demand — refs/ content only read when the agent actually needs it
- Risk: agents may not read refs/ files when instructed — silent degradation instead of noisy failure
- Mitigation: critical procedures (isolation contract, one-commit rule) remain inline in agent files
