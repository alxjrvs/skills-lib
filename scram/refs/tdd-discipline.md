# TDD Discipline

Strict Red-Green-Refactor. No exceptions.

## RED -- Write Failing Tests

- Derive tests directly from the documented behavior and acceptance criteria
- Cover happy path, edge cases, and error conditions from the docs
- Tests must compile/parse but **fail** -- there is no implementation yet
- Run tests to confirm they fail as expected
- **Do NOT write any implementation code in this phase**

## GREEN -- Write Minimum Code to Pass

- Write the **minimum implementation** to make all RED tests pass
- No optimization, no cleanup, no extras -- just make it green
- Run tests to confirm they all pass
- **Do NOT refactor in this phase**

## REFACTOR -- Improve Code Quality

- Refactor for clarity, readability, and best practices
- Streamline: remove duplication, simplify logic, improve naming
- Ensure code follows project conventions (CLAUDE.md)
- Run tests after refactoring to confirm nothing broke
- **All tests must still pass after refactor**

## Content-Only Substitute Discipline

When a story produces no executable code (docs, config, ADRs), apply the same discipline as a mental model:

1. **RED** -- identify what the deliverable must contain (acceptance criteria as a checklist)
2. **GREEN** -- write the minimum content that satisfies every checklist item
3. **REFACTOR** -- improve clarity, structure, and style without changing substance
