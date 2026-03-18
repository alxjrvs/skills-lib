# ADR-005: Build Scripts and Hooks Layer for SCRAM

## Status
Accepted

## Context
SCRAM currently implements a state machine in prose. Every deterministic action — check for HALT file, update session.md, verify branch, run git health checks, lint brief files for line-number references — is a prose instruction that consumes orchestrator context and can be silently skipped under pressure. There is no enforcement mechanism other than the orchestrator's attention. Context exhaustion is a known failure mode that causes bookkeeping steps to be skipped without any signal.

Separately, the HALT mechanism is currently enforced by the orchestrator reading a file and choosing not to dispatch. If the orchestrator forgets, is under context pressure, or interprets the HALT state incorrectly, agent dispatch proceeds anyway. The brief linting rule ("no line-number locators") has no enforcement point — it fires only when the orchestrator remembers.

Claude Code's plugin system supports `hooks.json` and a `scripts/` directory, used in at least one existing plugin (tmux). This infrastructure is available but unused in SCRAM.

## Decision
Add `scram/scripts/` and `scram/hooks.json` to the plugin. The first pass implements five scripts and three hook registrations, targeting the highest-value mechanical operations.

**Scripts:**

- `halt-check.sh` — exits 1 if `$SCRAM_WORKSPACE/HALT` exists, exits 0 if clear. Registered as a `PreToolUse` hook on `Agent` tool calls. When HALT is present, no agent dispatch fires — the check is system-level, not prose-dependent.
- `scram-init.sh` — creates the workspace directory structure (`briefs/`, `retro/`, `events/`), writes the initial `session.md` skeleton, records timestamp. Invoked once by the orchestrator at workspace creation. Replaces the prose "run mkdir -p" instructions at G0.
- `scram-discover.sh` — finds existing sessions, reads `session.md` timestamps, and formats a structured list for the orchestrator. Removes this discovery logic from the orchestrator's working memory.
- `pre-merge-check.sh` — runs three git reads: branch exists, SHA is on that branch, diff is non-empty. Returns structured pass/fail with reason. Replaces the prose git-health check block in the merge stream.
- `brief-lint.sh` — greps brief files for line-number reference patterns (`line \d+`, `:\d+$`, `L\d+`). Intended to be registered as a `PreToolUse` hook on `Write` tool calls matching paths under `$SCRAM_WORKSPACE/briefs/`. Path filtering on Write hooks must be verified against the plugin hook specification before implementation. If path-based matching is unsupported, `brief-lint.sh` becomes an orchestrator-invoked script called explicitly before merging stories, or is folded into `pre-merge-check.sh`.

**Deferred to a later pass:** `worktree-init.sh`, `backlog-update.sh`, and `session-update.sh` are identified as high-value but deferred. The markdown-parsing scripts are brittle if file formats evolve and carry higher implementation risk. `worktree-init.sh` is deferred pending stabilization of the two-tier dispatch model from ADR-004.

**Hooks registered in `hooks.json`:**
- `PreToolUse` on `Agent` → `halt-check.sh`
- `PreToolUse` on `Write` (briefs path filter, pending verification) → `brief-lint.sh` (fallback: orchestrator-invoked or folded into pre-merge-check)
- `Stop` → session checkpoint (writes a last-seen timestamp to `session.md` on every conversation stop — cheap insurance against context exhaustion leaving stale state)

Scripts reference `${CLAUDE_PLUGIN_ROOT}/scripts/` for their paths, consistent with the existing tmux plugin pattern.

## Consequences

### Positive
- Deterministic actions become testable artifacts — scripts can be unit-tested independently of a SCRAM run
- The HALT mechanism becomes a hard system-level enforcement, not a prose reminder
- Brief linting fires automatically, not when the orchestrator remembers
- Context exhaustion no longer causes orchestrators to skip bookkeeping steps — the Stop hook fires regardless
- The skill shrinks as prose control flow is replaced with script references
- Scripts are auditable in git history

### Negative
- Scripts add a maintenance surface. Prose that "forgets" fails silently; a broken script fails loudly (potentially blocking dispatch)
- Hook configuration adds indirection — debugging a blocked dispatch requires checking `hooks.json` as well as the skill
- Shell scripting in a primarily prose/markdown plugin introduces a new skill requirement for contributors

### Risks
- `PreToolUse` hooks on `Agent` tool calls must fire before the agent is dispatched. If the hook fires after, the HALT check is too late.
- `${CLAUDE_PLUGIN_ROOT}` must be available to hook scripts at runtime. This matches the tmux plugin's pattern but is not independently verified for SCRAM's environment.
- Path filtering on `PreToolUse` Write hooks is not demonstrated in any existing plugin. If unsupported, `brief-lint.sh` must adopt a fallback registration strategy (see Decision section).
- A broken `halt-check.sh` could block all agent dispatches without the orchestrator knowing why. Scripts must have clear error output and be tested before deployment.

## Dependencies
- Requires: none (can be layered on current SCRAM independently of other ADRs)
- Enables: ADR-002 in-flight capture (the Stop hook provides a checkpoint that reduces the risk of in-flight.md being lost on context exhaustion); significant SKILL.md line reduction as prose control flow is replaced by script references
