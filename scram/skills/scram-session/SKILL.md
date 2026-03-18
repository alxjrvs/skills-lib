---
name: scram-session
description: Session lifecycle reference for SCRAM — manifest format, workspace structure, state update events, and context recovery.
user_invocable: false
---

# SCRAM Session Lifecycle

This sub-skill is a reference document for SCRAM session lifecycle management. It is read by the orchestrator and other agents when session format detail is needed. It is not invoked as a standalone procedure.

## SCRAM Workspace

SCRAM persists state in a **global workspace directory** outside the project repo, ensuring zero contamination of the project's git history. Workspaces are **isolated per invocation** to prevent context bleed between concurrent SCRAM runs.

```
~/.scram/
└── <project-dir>--<feature-name>--<invocation-id>/
    ├── session.md              # session manifest — resume state
    ├── backlog.md              # tracked backlog with story status
    ├── briefs/
    │   └── <story-slug>.md     # context brief per story
    ├── retro/                  # retrospective artifacts (G5, if enabled)
    │   ├── in-flight.md        # appended during streams; read by retro facilitator at G5
    │   ├── tickets/
    │   │   ├── metron.md
    │   │   └── highfather.md
    │   └── discussions/
    │       └── <topic-slug>.md # consensus discussion outputs
    └── events/
    │   └── stream.log          # checkpoint event log — one JSON line per Stop hook invocation
```

**Workspace path construction** (at G0):
1. `<project-dir>` — the basename of the project's working directory (e.g., `my-app`)
2. `<feature-name>` — the feature name from the integration branch (e.g., `auth-system`)
3. `<invocation-id>` — a short timestamp: `YYYYMMDD-HHMMSS` (e.g., `20260316-143022`)

Example: `~/.scram/my-app--auth-system--20260316-143022/`

The workspace path is determined at G0 and passed to all agents as an **absolute path**. Refer to it as `SCRAM_WORKSPACE` throughout this document.

- **Backlog** (`SCRAM_WORKSPACE/backlog.md`) — the single source of truth for story status. Created at G3, updated by maintainers as stories complete, fail, or escalate. Survives context limits.
- **Context briefs** (`SCRAM_WORKSPACE/briefs/<story-slug>.md`) — written by devs at G3. Dev agents read these from disk rather than receiving them inline. Persistent across retries and escalation.
- **Retro** (`SCRAM_WORKSPACE/retro/`) — retrospective artifacts, created at G5 if enabled.
- **Session manifest** (`SCRAM_WORKSPACE/session.md`) — all state needed to resume a SCRAM run in a new conversation. Updated after every gate transition and after every story merge.

The workspace is cleaned up at the user's discretion after the SCRAM run. The orchestrator reports the workspace path in the final summary.

**Resuming a session:** Read `session.md` to restore state. Also read the last 5 lines of `events/stream.log` (if it exists) to understand the most recent activity before context was lost. This gives a mechanical checkpoint trace that supplements the prose state in `session.md`.

## Session Manifest

The session manifest (`SCRAM_WORKSPACE/session.md`) is the single file needed to resume a SCRAM run. It is written at G0 and **updated after every gate transition and every story merge**. Format:

```markdown
---
project: <absolute project path>
feature: <feature-name>
integration_branch: scram/<feature-name>
workspace: <absolute SCRAM_WORKSPACE path>
current_gate: G0 | G1 | G2 | G3 | streams | G4 | G5 | complete
run_type: code | docs | mixed
retrospective: pending | true | false
# retrospective transitions: set to "pending" at G0; resolve to "true" (opted in) or "false" (opted out) at G4 after the user prompt; never resolve during the stream phase
prior_brainstorm: <absolute path to brainstorm workspace, or "none">
scram_version: <semver string read from scram/.claude-plugin/plugin.json at G0, e.g. "6.1.0">
compressed_gates: <comma-separated list of skipped gates, e.g. "G1, G2", or "none">
tracker: <tracker config or "none">
created: <YYYY-MM-DD HH:MM:SS>
updated: <YYYY-MM-DD HH:MM:SS>
---

# SCRAM Session — <feature-name>

## Team

| Name | Role | Agent | Model |
|------|------|-------|-------|
| <name> | <role> | <agent type> | <model> |

Example:
| Name | Role | Agent | Model |
|------|------|-------|-------|
| Orion | Dev | developer | sonnet |
| Barda | Dev | developer | sonnet |
| Forager | Dev | developer | sonnet |
| Bug | Dev | developer | sonnet |
| Metron | Merge Maintainer | merge-maintainer | sonnet |
| Highfather | Code Maintainer | code-maintainer | sonnet |
| Beautiful Dreamer | Doc Specialist | doc-specialist | sonnet |
| Mark Moonrider | Doc Specialist | doc-specialist | sonnet |
| Esak | Designer | designer | sonnet |

Record the exact team as approved by the user. On resume, redispatch agents with the same names, roles, and models.

## Current State
<what has been completed, what is in progress, what remains>

## Merged Stories
- <commit hash> — <story title>

## In-Progress Stories
- <story title> — <agent name> (<status>)

## Escalations
- <story title> — <failure reason> — <current tier>

## Notes
<any context the next orchestrator session needs>
```

## Saving Memory References

After writing or updating the session manifest, **save a memory reference** so future conversations can discover it:

Write a memory file to the project's memory directory with type `project`:

```markdown
---
name: scram-session-<feature-name>
description: Active SCRAM session for <feature-name> — workspace at <SCRAM_WORKSPACE path>
type: project
---

Active SCRAM run for feature "<feature-name>".
**Workspace:** <SCRAM_WORKSPACE absolute path>
**Integration branch:** scram/<feature-name>
**Current gate:** <gate>
**Last updated:** <timestamp>

**How to apply:** When the user mentions resuming SCRAM work on this feature, read `session.md` from the workspace path above and resume from the recorded gate.
```

Update this memory each time the session manifest is updated. Remove it when the SCRAM run completes (G4/G5 done).

## Session Discovery

Before starting a new run, check for existing SCRAM workspaces for this project:

```bash
ls -d ~/.scram/$(basename "$PWD")--* 2>/dev/null
```

Also check memory for any `scram-session-*` references.

If existing workspaces are found, present them to the user:

```
Existing SCRAM sessions found for this project:
  1. ~/.scram/my-app--auth-system--20260315-100000/ (gate: streams, last updated: 2026-03-15 14:30)
  2. ~/.scram/my-app--api-routes--20260310-090000/ (gate: complete, last updated: 2026-03-12 16:00)

Resume an existing session, or start fresh?
```

**If resuming:** Read `session.md` from the selected workspace. Set `SCRAM_WORKSPACE` to that path. Check the integration branch still exists (`git branch --list`). Skip to the recorded `current_gate` — all prior gate work is already done. Update the session manifest's `updated` timestamp.

**If starting fresh:** Continue with the new session flow.

## Session State Updates

The session manifest MUST be kept current. Update `SCRAM_WORKSPACE/session.md` (and the corresponding memory reference) at these points:

| Event | Update |
|-------|--------|
| Gate transition (G0→G1, G1→G2, etc.) | Set `current_gate`, update `Current State` |
| Maintainer team created (G3) | Record team name in `Current State` |
| Story dispatched | Add to `In-Progress Stories` |
| Story merged | Move to `Merged Stories` with commit hash, remove from in-progress |
| Story failed/escalated | Add to `Escalations` with failure reason and tier |
| Doc refinement batch completed | Note in `Current State` |
| Maintainer team shut down (G4) | Note in `Current State` |
| Context limit approaching | Write full state to manifest before checkpointing |

## Context Limit Recovery

If you approach context limits, ensure the session manifest is fully up to date, then present the workspace path to the user:

```
Approaching context limits. Session state saved to:
  SCRAM_WORKSPACE/session.md

Resume in a new conversation — SCRAM will discover this session automatically.
```

The user can continue in a fresh session. The new orchestrator will find the workspace via the discovery flow at G0 (filesystem scan + memory reference) and resume from the recorded gate.
