---
description: Practical patterns and gotchas for building tmux powerline format strings — value+label pairing, color blending, escaping, build direction, and dynamic per-window options.
---

# Powerline Tips

Practical patterns for building and editing tmux powerline format strings. See also:
`powerline-glyphs` for the glyph color model.

---

## Value + Label Pattern

Every status-right segment uses two background colors: a bright `SEGMENT_VAL` for the
value/number, and a darker `SEGMENT_LBL` for the text label. Always define and use them
as a pair — the sub-separator glyph (U+E0BA) transitions between them.

```sh
# Bright value area
o="${o}#[bg=${CPU_VAL},fg=#f0f0f0] ${cpu_display} "
# Transition via BS glyph
o="${o}#[bg=${CPU_VAL},fg=${CPU_LBL}]${BS}"
# Darker label area
o="${o}#[bg=${CPU_LBL},fg=#f0f0f0,nobold] CPU "
```

When adding a new segment, define both `SEGMENT_VAL` and `SEGMENT_LBL` in `theme.sh`.

---

## `default` vs Explicit TERM_BG

`bg=default` inherits from the window background and can produce visible mismatches
when the window bg differs from the status bar bg. Use the explicit terminal background
color (`#282c34` or the `TERM_BG` variable) whenever a glyph must blend precisely with
the bar background.

```sh
# Unreliable — may not match status bar background
#[bg=default,fg=#c07018]

# Reliable — explicit terminal background
TERM_BG="#282c34"
#[bg=${TERM_BG},fg=#c07018]
```

---

## Hex Colors Inside tmux Format Strings

Inside `#[...]` style blocks that tmux double-expands (e.g. `window-status-format`,
`window-status-current-format`), `#` must be written as `##` to produce a literal `#`.
Hex color values therefore require `##rrggbb`.

```
# Wrong — tmux interprets the # as a variable prefix in double-expanded contexts
#[fg=#f0f0f0]

# Correct inside window-status-format and similar double-expanded strings
#[fg=##f0f0f0]
```

This does **not** apply to `set-option` values set directly in shell via
`tmux set-window-option` — those are single-expanded and use plain `#rrggbb`.

---

## Status-Right Build Direction

The status-right string is assembled left-to-right in code, but renders from right to
left on screen — the last segment appended in code is the leftmost segment on the bar
(nearest the window list).

Plan the visual layout right-to-left (TIME → BAT → MEM → CPU from right edge inward),
then write the code left-to-right in that order.

```
Visual (screen):  [CPU][MEM][BAT][TIME]  ← right edge of bar
Code order:        CPU  MEM  BAT  TIME   (appended first → last)
```

---

## Dynamic Colors via Per-Window Options

Tab colors and per-window state are driven by `tmux set-window-option @tab_foo value`
and read in format strings via `#{@tab_foo}`. This avoids re-running scripts on every
status bar render — only the hook or `tab-colors` command updates the values.

```sh
# Set in tab-colors script or hook
tmux set-window-option -t :$WIN @tab_dk_color "#9a5818"
```

```
# Read in window-status-current-format
#[bg=#{@tab_dk_color},fg=##f0f0f0] #W
```

For conditional logic, combine with `#{?condition,true,false}`:

```
#{?#{@tab_claude_needs_input},#[bg=##D97757],#[bg=#{@tab_inactive_color}]}
```

An empty string (`''`) clears an option — tmux treats unset and empty identically in
`#{}` expansions, so clearing an option effectively sets its conditional to false.
