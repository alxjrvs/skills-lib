---
description: Reference for Claude Code tmux hook behaviors — what each hook event sets and clears, for developers building custom tmux status bars or powerline setups.
---

# Claude Code tmux Hooks

This skill documents the hook-based signaling model used by the `tmux` plugin. Claude Code sets tmux **window options** as state flags; your status bar or powerline script reads those flags to reflect Claude's current activity.

---

## What the Hooks Do NOT Do

**These hooks set tmux window options only.** They produce no visible output by themselves. To surface Claude's status visually, you must read `#{@tab_claude_needs_input}` and/or `#{@tab_claude_blink}` in your own `window-status-format` or status bar configuration. The "Adapting to Your Setup" section at the bottom shows a minimal example.

---

## Environment Prerequisites

All hook scripts depend on `$TMUX_PANE` being set. This environment variable is automatically present when Claude Code runs inside a tmux pane. Without it, every script is a no-op.

The window index is resolved at runtime:

```bash
WIN=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_index}')
```

This is how all scripts know *which* window to update, even when tmux has multiple windows open.

---

## State: Window Options

The hooks communicate state via per-window tmux options:

| Option | Value | Meaning |
|---|---|---|
| `@tab_claude_needs_input` | `1` or empty | Claude is waiting for user input (permission request or elicitation dialog) |
| `@tab_claude_blink` | `1` or empty | The tab should visually blink/alert |

These are set and cleared via `tmux set-window-option -t :"$WIN" <option> <value>`.

An empty string (`''`) clears the option — tmux treats unset and empty-string options identically in `#{}` format strings.

A `/tmp/claude-active-${TMUX_PANE}` file is also used as an active-session marker (created on PermissionRequest, removed on Stop).

---

## Hook Events

### `PermissionRequest`

**Trigger:** Claude is about to perform a tool call that requires user approval.

**What it does:**
1. Touches `/tmp/claude-active-${TMUX_PANE}` (marks session active)
2. Sets `@tab_claude_needs_input` to `1` on the current window
3. Calls the powerline script to start a visual blink on the tab

**Script:** `scripts/permission-request.sh`

```bash
[ -n "${TMUX_PANE:-}" ] \
  && touch "/tmp/claude-active-${TMUX_PANE}" \
  && WIN=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_index}' 2>/dev/null) \
  && [ -n "$WIN" ] \
  && tmux set-window-option -t :"$WIN" @tab_claude_needs_input '1' \
  && ~/dotFiles/tmux-scripts/tmux-powerline.sh tab-blink-start "$WIN" \
  || true
```

---

### `Notification` (matcher: `elicitation_dialog`)

The `matcher` field in `hooks.json` filters which notification types trigger this hook — only `elicitation_dialog` events fire it.

**Trigger:** Claude raises an elicitation dialog — a structured prompt asking for user input mid-task.

**What it does:** Sets `@tab_claude_needs_input` and starts a blink. Does **not** touch the active file.

**Script:** `scripts/notify-blink.sh`

```bash
[ -n "${TMUX_PANE:-}" ] \
  && WIN=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_index}' 2>/dev/null) \
  && [ -n "$WIN" ] \
  && tmux set-window-option -t :"$WIN" @tab_claude_needs_input '1' \
  && ~/dotFiles/tmux-scripts/tmux-powerline.sh tab-blink-start "$WIN" \
  || true
```

---

### `UserPromptSubmit`

**Trigger:** The user submits a message to Claude.

**What it does:** Clears both `@tab_claude_needs_input` and `@tab_claude_blink`, then refreshes the tmux client status bar.

**Script:** `scripts/clear-blink.sh`

```bash
[ -n "${TMUX_PANE:-}" ] \
  && WIN=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_index}' 2>/dev/null) \
  && [ -n "$WIN" ] \
  && tmux set-window-option -t :"$WIN" @tab_claude_needs_input '' \
  && tmux set-window-option -t :"$WIN" @tab_claude_blink '' \
  && tmux refresh-client -S \
  || true
```

---

### `PostToolUse` and `PostToolUseFailure`

**Trigger:** Any tool call completes (success or failure).

**What it does:** Same as `UserPromptSubmit` — clears blink flags and refreshes status. This ensures the tab stops blinking once Claude resumes work after a permission grant.

**Script:** `scripts/clear-blink.sh` (same script reused)

---

### `Stop`

**Trigger:** The Claude Code session ends.

**What it does:**
1. Removes `/tmp/claude-active-${TMUX_PANE}`
2. Sets `@tab_claude_needs_input` to `1` and triggers `tab-blink-start` — signals "session ended, check this tab"

> **Note:** Stop sets `@tab_claude_needs_input` only. `@tab_claude_blink` is NOT set directly by this script. The visual blink is driven entirely by the external `tmux-powerline.sh tab-blink-start` call. If you are building a status bar using `#{@tab_claude_blink}`, that option will remain empty after Stop fires; rely on `#{@tab_claude_needs_input}` to detect session end.

**Script:** `scripts/stop.sh`

```bash
rm -f "/tmp/claude-active-${TMUX_PANE:-}" \
  && [ -n "${TMUX_PANE:-}" ] \
  && WIN=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_index}' 2>/dev/null) \
  && [ -n "$WIN" ] \
  && tmux set-window-option -t :"$WIN" @tab_claude_needs_input '1' \
  && tmux refresh-client -S \
  && ~/dotFiles/tmux-scripts/tmux-powerline.sh tab-blink-start "$WIN" \
  || true
```

---

## Adapting to Your Setup

The only non-generic part of each script is the `~/dotFiles/tmux-scripts/tmux-powerline.sh` call. If you are not using this powerline setup, replace those lines with whatever triggers a visual update in your status bar.

The `tmux set-window-option` calls are fully generic and work with any status bar that reads `#{@tab_claude_needs_input}` or `#{@tab_claude_blink}`.

**Minimal adaptation — status bar format string example:**

```tmux
set -g window-status-format "#{?#{@tab_claude_needs_input}, ⚠ ,} #W"
```

This adds a warning indicator to any window where Claude is waiting for input, with no custom scripts required beyond the hook scripts themselves. This is the required step to make the hooks visible; without it, the hooks run silently.
