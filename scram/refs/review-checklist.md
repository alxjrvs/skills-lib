# Review Checklist

## Pre-Review Gate

- [ ] Run `${CLAUDE_PLUGIN_ROOT}/scripts/pre-merge-check.sh <branch> <sha> <integration-branch>` — must pass before proceeding

## Merge Maintainer Checks (correctness and story fidelity)

- [ ] **Diff isolation** — changed files exactly match the brief's `## Deliverables`. Changes outside declared files require explanation or rejection.
- [ ] **Ancestry check** — story branch was created from the integration branch tip, not from `main` or a sibling: `git merge-base --is-ancestor <integration-tip> <story-branch>`
- [ ] **Commit count** — exactly one commit on the story branch relative to integration: `git rev-list --count --no-merges <integration-branch>..<story-branch>`. Require squash if count > 1.
- [ ] **Acceptance criteria** — every criterion satisfied. Nothing extra, nothing missing.
- [ ] **TDD discipline** — Red-Green-Refactor actually followed. Tests exist before implementation.
- [ ] **Scope discipline** — reject changes beyond the story. No bonus refactors, no "while I'm here" additions. Untraceable code is a scope violation.
- [ ] **Generated type parity** — when any variant of a generated type (Row/Insert/Update) is modified, all variants have consistent column sets.
- [ ] **Cross-story type drift** — if this story mutates a shared type/schema/generated file, append to `SCRAM_WORKSPACE/retro/in-flight.md`: `[timestamp] [type-drift]: <story-slug> mutated <type/schema name>`
- [ ] **ADR deviation tracking** — flag any implementation that deviates from approved ADRs. Classify as wording-only or behavioral.
- [ ] **Edge cases** — error paths, boundary conditions, null/empty cases handled
- [ ] **Naming and formatting** — consistent, descriptive, following CLAUDE.md conventions
- [ ] **Test quality** — tests assert behavior, not implementation details

## Code Maintainer Checks (architectural health)

- [ ] **Harmony** — does this code feel native to the codebase, or does it introduce foreign patterns?
- [ ] **DRYness** — is there duplication with existing code or across recently merged stories? Should a pattern be extracted?
- [ ] **Emergent patterns** — note recurring structures across stories; flag patterns worth extracting or documenting (2+ occurrences)
- [ ] **Deletable code** — unused imports, dead branches, orphaned helpers, exports nothing consumes
- [ ] **Streamlineable interfaces** — props/arguments that could be derived, unnecessary indirection, over-abstraction for current usage
- [ ] **Architectural drift** — is this subtly moving the codebase away from established patterns?
- [ ] **Scope violations** — code that cannot be traced to an acceptance criterion in the brief
- [ ] **Deletion verification** — if the story removes a module/export/utility, all callers accounted for in deliverables or dependencies
- [ ] **Bundle size delta** — note aggregate change; if single story causes >50% reduction or >20KB absolute change, write structural signal note in `session.md`
