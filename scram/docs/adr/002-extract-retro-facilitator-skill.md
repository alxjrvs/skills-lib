# ADR-002: Extract G5 Retrospective Into a Standalone Retro-Facilitator Skill

## Status
Accepted

## Context
The G5 retrospective is approximately 134 lines of self-contained process in `SKILL.md`: its own ticket submission format, structured discussion format with Current/Proposed text fields, compile/present format, and GitHub issue filing flow. It touches no other gate and shares no logic with G0–G4. It is currently embedded in the main skill file purely because no extraction mechanism existed when it was written.

Two related problems exist alongside the extraction opportunity. First, retro input is reconstructed post-hoc from memory and `backlog.md` at the start of G5. Process friction observed during the stream — a confusing handoff, an unexpected git state, an isolation failure — gets filtered through recollection rather than captured at the moment it occurs. Second, the retro discussion format currently produces agreed changes in loose prose form, which requires a subsequent human-driven SCRAM run to apply them. The application lag defeats the purpose of the retro loop.

## Decision
Extract G5 into a new skill at `scram/skills/scram-retro/SKILL.md`, registered as `scram:retro-facilitator`. The skill is self-contained and receives its inputs as dispatch arguments (SCRAM_WORKSPACE path, in-flight.md path if it exists, session context including total stories, escalations, and HALT events). The main SKILL.md G5 section collapses to a dispatch instruction.

Add one workspace artifact: `SCRAM_WORKSPACE/retro/in-flight.md`. Add one instruction to both `merge-maintainer.md` and `code-maintainer.md` in the streams section: when encountering process friction — a confusing instruction, an unexpected git state, an ambiguous handoff — append a one-liner to `retro/in-flight.md` in the format `[timestamp] [role]: <observation>`. Capture and continue; synthesis happens at G5. The retro facilitator reads `in-flight.md` before dispatching maintainers for ticket writing.

Tighten the retro discussion format to require exact string matches in Current/Proposed text pairs rather than loose prose paraphrases. Auto-application of retro changes is deferred to a follow-on ADR — the exact-match format is adopted now to enable future automation, but this ADR's scope is limited to extraction and in-flight capture only.

## Consequences

### Positive
- Approximately 130 lines removed from SKILL.md
- The retro process becomes independently evolvable without touching the main skill
- The retro skill is usable standalone for non-SCRAM retrospective processes
- In-flight capture turns post-hoc recall into real-time observation — the gap between "isolation failure occurs" and "retro ticket filed" collapses from days to minutes
- The exact-match format positions the retro for future auto-application without requiring it in this pass

### Negative
- Two-file maintenance (main skill + retro skill) instead of one
- `retro/in-flight.md` is a new workspace artifact that must be documented and managed
- Auto-apply is deferred but the format commitment constrains future retro discussions to exact-match text pairs, which may be overly rigid for structural reorganization proposals

### Risks
- The retro facilitator must receive enough context via dispatch arguments to function without reading the full SKILL.md. If it needs to cross-reference gate descriptions or team composition rules, the dispatch arguments must be expanded.
- Maintainers must use `in-flight.md` under stream pressure, where merge review work competes for attention. Bounding entries to one-liners is essential to keep this viable.
- Exact-string format may prove too rigid if most retro changes are structural reorganizations rather than text replacements. The follow-on ADR for auto-application will need to evaluate this.

## Dependencies
- Requires: none (both the extraction and in-flight capture can be implemented independently of other ADRs)
- Enables: ADR-003 (once the retro is extracted, the main skill is shorter and duplication cleanup is more tractable); the auto-apply retro loop enables a tighter SCRAM self-improvement cycle
