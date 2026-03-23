# Report Formats

## Story Report (developer-impl)

```
## Story Report
- **Story:** <story-id>
- **Branch:** <branch name from git rev-parse --abbrev-ref HEAD>
- **Commit:** <commit SHA from git rev-parse HEAD>
- **Status:** completed | partial | failed
- **Phase reached:** RED | GREEN | REFACTOR
- **Failure reason:** none | context_exhaustion | test_failure | build_error | missing_dependency | unclear_spec | pre_flight_failure
- **Failure details:** <specific error message or description, if failed>
- **Commit count:** <output of `git rev-list --count --no-merges <integration-branch>..HEAD` -- must be 1>
- **Files changed:**
  - <file path> -- <brief description>
- **Tests:** <pass count>/<total count> passing
- **Pre-existing issues:** <list or "none">
- **Design decisions:** <any architectural choices made and why>
- **Adjacent issues found:** <bugs or problems found but not fixed -- document here for orchestrator>
- **Remaining work:** <what's left, if partial>
- **Escalation notes:** <if escalated: what was different from previous attempt>
```

## Merge Maintainer Report (merge-maintainer)

```
## Merge Maintainer Report
- **Story:** <story-id>
- **Action:** review | merge | revert | escalation
- **Review status:** approved | revisions_requested | rejected
- **Acceptance criteria met:** yes | partial | no -- <details if not fully met>
- **TDD discipline:** followed | violated -- <details if violated>
- **Scope violations:** none | <list of out-of-scope changes>
- **ADR deviations:** none | <list of deviations with classification: wording-only or behavioral>
- **Code quality issues:** none | <specific line-level issues>
- **Post-merge test status:** all_passing | failure_reverted
- **Backlog updated:** yes | no
- **Tracker updated:** yes | no | not_configured
```

## Code Maintainer Report (code-maintainer)

```
## Code Maintainer Report
- **Story:** <story-id>
- **Action:** review | merge | revert | escalation
- **Review status:** approved | revisions_requested | rejected
- **Harmony notes:** <how well this fits existing patterns>
- **DRY violations:** <duplicated code or patterns that should be extracted, or "none">
- **Patterns identified:** <emergent patterns worth extracting or documenting, or "none">
- **Run patterns:** <cross-story accumulation observations -- DRY drift, type surface growth, pattern inconsistencies across the full run. Read `session.md` Merged Stories list before answering. For the first story in a run, write "none so far.">
- **Deletable/streamlineable:** <dead code, unused exports, redundant props, over-abstractions found, or "none">
- **Post-merge test status:** all_passing | failure_reverted
- **Backlog updated:** yes | no
- **Tracker updated:** yes | no | not_configured
```

## Doc Report (doc-specialist)

```
## Doc Report
- **Gate:** G1 | G2 | refinement
- **Status:** completed | partial | revisions_needed
- **Files changed:**
  - <file path> -- <brief description>
- **ADRs written/amended:**
  - <ADR file> -- <decision title>
- **Sections added/updated:** <list>
- **Plans cleaned up:** <list or "none">
- **Divergence flags:** <list of significant spec-vs-implementation gaps, or "none">
- **Remaining work:** <what's left, if partial>
```

## Developer Reviewer Report (developer-reviewer)

```
## Developer Review Report
- **Gate:** G1 | G2
- **Status:** approved | revisions_needed
- **Feasibility:** <assessment>
- **Testability:** <assessment>
- **Ambiguity flags:** <list or "none">
- **Architecture concerns:** <list or "none">
- **Blocking issues:** <list of items that would block implementation, or "none">
- **Suggested revisions:** <specific, actionable feedback, or "none">
```
