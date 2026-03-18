# SCRAM

Structured Collaborative Review and Merge — a stream-based parallel development orchestrator for Claude Code.

## Install

```
/plugin marketplace add alxjrvs/skills
/plugin install scram@jrvs-skills
```

## Skills

### `/scram`

Launch a structured dev team to implement features in parallel. Uses sequential gates (ADRs, docs-as-spec, story breakdown) followed by concurrent streams (dev, merge, doc refinement) with strict TDD discipline.

### `/scramstorm`

Launch a team brainstorm to collaboratively research a problem. Same agents, no code — produces structured options with trade-offs through anonymous positions and attributed debate.

## Agents

| Agent | Role | Default Model |
|-------|------|---------------|
| `scram:developer-reviewer` | G1/G2 doc review (Tier 2, read-only) | sonnet |
| `scram:developer-breakdown` | G3 story breakdown, context brief authoring (Tier 2) | sonnet |
| `scram:developer-impl` | TDD implementation in isolated worktrees (Tier 1) | sonnet |
| `scram:merge-maintainer` | Line-level code review, story strictness, TDD discipline | sonnet |
| `scram:code-maintainer` | Structural harmony, DRYness, codebase-wide patterns | sonnet |
| `scram:doc-specialist` | Docs-as-spec, incremental refinement | sonnet |
| `scram:designer` | Design ADRs, UI/UX merge approver (optional) | sonnet |
| `scram:dev-tooling-maintainer` | CI/CD, build systems, agentic integrations, DX (optional) | sonnet |
