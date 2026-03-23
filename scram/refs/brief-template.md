# Context Brief Template

```markdown
# <Story Title>

## Story
<description and acceptance criteria>

## Doc Section
<reference to the approved doc section this story maps to>

## Budget
`tight | standard | open`
- `tight` -- read only this brief and directly referenced files (use for simple, well-scoped stories)
- `standard` -- normal codebase exploration permitted (default)
- `open` -- full codebase exploration permitted (use for complex or cross-cutting stories)

## Scope Fence
<For stories that touch contested files: explicitly declare which sections/files/functions are OUT OF SCOPE for this story. Example: "Do not modify the authentication middleware -- that is owned by story auth-2." Leave blank if no contested files.>

## Files
- <file path> -- <why it's relevant>

## Locators
Use content-stable grep anchors. **Never use line numbers.**
- Good: "Find the sentence beginning with 'X' and change to..."
- Bad: "Line 42 of foo.ts"

## Types & Interfaces
- <key type/interface signatures>
- **If modifying any variant of a generated type (Row/Insert/Update), verify all variants have consistent column sets.** Note which variants exist and confirm parity.

## Type Contracts
<Required for any story that introduces or modifies exported types/interfaces. List:
- Every exported type name
- Its expected shape (or reference to the doc section defining it)
- Any `string` fields that must be narrowed to a literal union
- Any discriminant fields
Gate dev dispatch on this section being present for type-changing stories. If absent, the brief goes back to the doc specialist.>

## Dependencies
### Code dependencies
- <stories this depends on, and whether they're merged -- do not dispatch until these are merged>

### Structural dependencies
- <brief-to-brief format dependencies: "this story extends the manifest format defined in story X">
- <merge order constraints: "must merge before story Y to avoid ancestry contamination">

## Hook Constraint Check
Can this story pass pre-commit hooks independently (without relying on changes from other stories)?
- Yes / No -- <explain if No>
- If "No": note the export-before-deletion ordering constraint or other hook dependency. This story may need to be sequenced or its scope adjusted.

## Hook Scope
<Scope of pre-commit hooks relative to this story. Values:
- `story-scoped` -- hooks only check files this story touches
- `project-wide` -- hooks check entire project (e.g., monorepo-wide typecheck)
- `unknown` -- not yet determined
If `project-wide`: note known out-of-scope failures that the dev should diagnose, not fix.>

## Architecture
<summary of relevant architecture and relevant ADRs from G1>

## Conventions
<Top 5 most-violated project rules from CLAUDE.md/ESLint config. Populated by the breakdown agent from project conventions. Example:
- No default exports
- Prefer `type` over `interface`
- All async functions must handle errors explicitly
Leave blank if no project-specific conventions apply.>

## Checklist
<Story-specific checklist items. Populate only the checklist(s) relevant to this story's domain.
If no special checklist applies, write "none". Available categories:
- Shared-state, Call-boundary, Async/lifecycle, Test-update (see developer-breakdown agent for item text)>

## Testing Notes (conditional)
<Required when the story involves state management libraries with known test isolation patterns. Examples:
- Zustand: reset ALL state fields in `beforeEach`
- Redux: use `configureStore` per test, never share store instances
- React Query: wrap in `QueryClientProvider` with fresh client per test
Leave blank or omit if no library-specific testing patterns apply.>

## UI/UX Context (if tagged)
<relevant design ADRs, existing UI patterns, component references -- only populated if the story is tagged as UI/UX>

## Deliverables
- [ ] <file> -- <specific change>
```
