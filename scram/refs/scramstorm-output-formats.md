# SCRAMstorm Output Formats

## Single Recommendation

```
## Brainstorm Result

### Recommendation: <approach title>
**Source tickets:** NNN, NNN
<summary>

**Support:** <count>/<total> team members
**Effort:** <estimate>

**Why this approach:**
<synthesized reasoning from debate>

**Key trade-offs:**
- <trade-off 1>
- <trade-off 2>

**Dissenting views:**
- <role>: <concern>

### Alternatives Considered
1. <approach> -- rejected because <reason>
2. <approach> -- rejected because <reason>

## Next Step

To implement this, start a new conversation and run:
  /scram implement <recommendation> from this scramstorm
Workspace: <BRAINSTORM_WORKSPACE path>
```

## Ranked Options

```
## Brainstorm Result

### Option 1: <approach title> (recommended)
**Source tickets:** NNN, NNN
**Support:** <count>/<total> | **Effort:** <estimate>
<summary>
- **Pros:** <list>
- **Cons:** <list>
- **Risks:** <list>

### Option 2: <approach title>
**Source tickets:** NNN, NNN
**Support:** <count>/<total> | **Effort:** <estimate>
<summary>
- **Pros:** <list>
- **Cons:** <list>
- **Risks:** <list>

### Option 3: <approach title>
**Source tickets:** NNN, NNN
...

### Team Notes
<any cross-cutting observations, open questions, or caveats from the debate>

### Open Implementation Questions
<Unresolved implementation decisions surfaced during the brainstorm. Each must have:
- A named owner
- A resolution trigger (deadline, blocker, or escalation condition)
Questions the brainstorm team can answer should be answered here. Questions they cannot must be surfaced explicitly.>

## Next Step

To implement this, start a new conversation and run:
  /scram implement <option> from this scramstorm
Workspace: <BRAINSTORM_WORKSPACE path>
```

## Exploration

```
## Brainstorm Result

### The Problem Space
<synthesized understanding of the problem from all perspectives>

### Approaches Explored

#### <approach 1>
**Source tickets:** NNN, NNN
<description, trade-offs, who supported it and why>

#### <approach 2>
**Source tickets:** NNN, NNN
<description, trade-offs, who supported it and why>

#### <approach 3>
**Source tickets:** NNN, NNN
...

### Tensions and Trade-offs
<where the team genuinely disagreed and why -- these are real trade-offs, not resolvable by more discussion>

### Open Questions
Each open question must include a **named decision owner** and a **resolution trigger** (deadline, blocker, or escalation condition). Open questions without owners are organizational debt. If the brainstorm cannot name an owner, flag the question as a blocker on the relevant option.
- <question> -- **Owner:** <who decides> -- **Resolve by:** <trigger>

### Open Implementation Questions
<Unresolved implementation decisions surfaced during the brainstorm. Each must have:
- A named owner
- A resolution trigger (deadline, blocker, or escalation condition)
Questions the brainstorm team can answer should be answered here. Questions they cannot must be surfaced explicitly.>

## Next Step

To implement this, start a new conversation and run:
  /scram implement <option> from this scramstorm
Workspace: <BRAINSTORM_WORKSPACE path>
```
