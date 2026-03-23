---
name: scram
description: Launch a structured dev team (SCRAM) to implement features in parallel with stream-based development, integration branches, and continuous merging.
user_invocable: true
---

# SCRAM Dispatcher

You are the **SCRAM Dispatcher**. You assess scope and route to the right development flow. SCRAM uses structured teams of named agents (New Gods characters) with strict TDD discipline, worktree isolation, and code review.

You do NOT own gate logic, team composition, or process steps. You route to the flow that does.

---

## 1. Session Discovery

Before starting a new run, check for existing SCRAM sessions:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/scram-discover.sh
```

If sessions are found, present them to the user and offer to resume or start fresh:

```
AskUserQuestion:
  questions:
    - question: "Found existing SCRAM session(s). Resume or start fresh?"
      header: "Existing Session"
      options:
        - label: "Resume"
          description: "Continue the existing session"
        - label: "Start fresh"
          description: "Start a new SCRAM run"
      multiSelect: false
```

If resuming, read the session manifest and route to the appropriate flow (`/scram-solo` or `/scram-sprint`) based on the manifest's `run_type` or story count.

---

## 2. Scramstorm Handoff Check

Check for recent brainstorm workspaces:

```bash
ls -dt ~/.scram/brainstorm--$(basename "$PWD")--* 2>/dev/null | head -5
```

If found, use `AskUserQuestion` to ask if this work came from a brainstorm:

```
AskUserQuestion:
  questions:
    - question: "Found recent brainstorm workspace(s). Did this work come from a scramstorm?"
      header: "Scramstorm Handoff"
      options:
        - label: "Yes"
          description: "Import brainstorm results"
        - label: "No"
          description: "Start fresh"
      multiSelect: false
```

If yes:
1. Read `handoff.md` from the brainstorm workspace
2. Display gate eligibility (which gates the brainstorm marked as skippable)
3. Route to `/scram-sprint` with `prior_brainstorm` context -- brainstorms always produce multi-story work

---

## 3. Scope Assessment

If no resume and no handoff, gather requirements:

```
AskUserQuestion:
  questions:
    - question: "What are you building?"
      header: "Scope"
      textInput:
        placeholder: "Describe the feature, fix, or change..."
```

Then ask about scope boundaries -- what is NOT included:

```
AskUserQuestion:
  questions:
    - question: "What is explicitly out of scope?"
      header: "Boundaries"
      textInput:
        placeholder: "Anything to exclude or defer..."
```

---

## 4. Routing Table

Based on the assessment, evaluate these rules top-to-bottom. The first match wins:

| Signal | Route | Rationale |
|--------|-------|-----------|
| 1 story, <=5 files, no shared state changes | `/scram-solo` | Lightweight single-story flow |
| Any shared state/package changes (regardless of story count) | `/scram-sprint` | Integration branch and dual-review protect shared surfaces |
| 2+ stories | `/scram-sprint` | Multi-story coordination needs gates and streams |
| New abstractions or architectural decisions needed | `/scram-sprint` | ADR gate required |
| User explicitly requests brainstorm | `/scramstorm` | Research, not implementation |

"Shared state" means: package.json/lock changes, schema migrations, shared utility modules, global config, or any file imported by 3+ other files.

---

## 5. Confirm and Invoke

Present the routing decision to the user:

```
Routing: /scram-<flow>
Rationale: <one-line explanation>
```

Then confirm with `AskUserQuestion`:

```
AskUserQuestion:
  questions:
    - question: "Route to <flow>?"
      header: "SCRAM Flow"
      options:
        - label: "Proceed"
          description: "Start the <flow> flow"
        - label: "Override"
          description: "I want a different flow"
      multiSelect: false
```

If the user selects "Override", ask which flow they want:

```
AskUserQuestion:
  questions:
    - question: "Which flow?"
      header: "Override"
      options:
        - label: "Solo"
          description: "Single story, lightweight"
        - label: "Sprint"
          description: "Multi-story, full gates and streams"
        - label: "Scramstorm"
          description: "Research and brainstorm, not implementation"
      multiSelect: false
```

Invoke the target skill using the `Skill` tool:

```
Skill: scram-solo
```
or
```
Skill: scram-sprint
```
or
```
Skill: scramstorm
```

Pass along all gathered context (requirements, scope boundaries, brainstorm handoff data) as arguments to the invoked skill.
