# ADR-003: Eliminate Duplication Between SKILL.md and Agent Definitions

## Status
Accepted

## Context
SKILL.md currently re-states agent procedures that are already owned by agent definition files. TDD phases appear in both SKILL.md and `developer.md`. Merge review checklists appear in both SKILL.md and `merge-maintainer.md`. G0 environment checks appear in SKILL.md, `merge-maintainer.md`, and `code-maintainer.md`. ADR review and G2 doc review processes appear in SKILL.md and both maintainer files. Additionally, `merge-maintainer.md` and `code-maintainer.md` share approximately 60–70 lines of verbatim duplicate content covering G0 procedure, approval tiers, merge mechanics, conflict resolution, tracker updates, and commit format.

This duplication creates two risks: the skill and agent files can drift, and every agent dispatch loads procedure text from two sources simultaneously. It also embeds an anti-pattern — the skill re-teaches agents their own jobs, consuming orchestrator context doing so.

## Decision
Establish a clear boundary: the skill owns orchestration flow; agents own their procedures.

**Skill owns:** Gate sequencing, who does what when, dispatch instructions, role assignments, team composition rules, integration branch topology, emergency halt and recovery triggers.

**Agents own:** Their review criteria and process, their operational checklists, their report format, their constraints.

Concrete removals from SKILL.md:
- TDD phase descriptions (approximately 25 lines) are removed. The G3/stream section says "dispatch `developer-impl` with the context brief — the agent follows its TDD discipline."
- The merge stream review checklist (approximately 27 lines) shrinks to a dispatch instruction. The 19-step checklist lives in `merge-maintainer.md`.
- G0 environment check duplication (approximately 45 lines across three files) is resolved by making the maintainer files authoritative. The skill's G0 section says "both maintainers run environment checks per their definitions."
- ADR review and G2 doc review procedure (approximately 20 lines) are owned by `code-maintainer.md`. The skill references the outcome, not the steps.

Concrete deduplication between maintainer files: `merge-maintainer.md` is authoritative for shared merge mechanics (G0 procedure, approval tiers, merging, conflict resolution, tracker updates, commit format). `code-maintainer.md` carries a condensed version covering what it needs — code maintainer approves, merge maintainer executes. This option is preferred over a third shared-reference file because independent dispatch must remain viable.

The constraints block at the end of SKILL.md is audited and cut from approximately 15 bullets to 6–8 bullets that are genuinely not stated elsewhere.

Expected total reduction: approximately 180 lines across all files. SKILL.md drops from approximately 880 to approximately 700 lines.

## Consequences

### Positive
- Total system line count drops by approximately 180 lines
- The skill becomes a flow document, not a manual
- Agents become authoritative on their own procedures — improving an agent's process requires editing one file, not two or three
- The "skill re-teaching agents their jobs" anti-pattern is eliminated
- Context budget per agent dispatch decreases (agents no longer load redundant procedure text from two sources)

### Negative
- The skill becomes more opaque — reading SKILL.md alone no longer gives the full picture of what each agent does
- Debugging a SCRAM run may require opening more files
- Any divergence between what the skill says and what the agent does is harder to catch because they no longer repeat each other (repetition, while bloated, was at least a consistency check)

### Risks
- Agents dispatched without the full procedure in the skill will execute correctly only if the dispatch always loads the agent definition file. If any dispatch path loads only the skill and not the agent file, the procedure disappears.
- The orchestrator needs to understand the outcome of each agent action even without the full procedure steps. Dispatch instructions must clearly communicate expected outcomes.
- The merge-execution authority question (which role has final authority to execute a merge) must be resolved cleanly. This ADR designates `merge-maintainer.md` as authoritative for merge mechanics.

## Dependencies
- Requires: ADR-001 (splitting developer agent makes the skill-vs-agent boundary cleaner), benefits from ADR-002 (extracting the retro first reduces skill size before this cleanup)
- Enables: significant reduction in token cost per SCRAM session; cleaner standalone skill extraction in future iterations
