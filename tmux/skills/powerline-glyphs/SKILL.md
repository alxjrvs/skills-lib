---
description: Recipe for powerline glyph color assignments — which side FG dominates, how to flow segments together, and exact color patterns for entry/split/exit transitions.
---

# Powerline Glyphs

Powerline-style status bars use filled Nerd Font glyphs to create seamless color transitions
between segments. Each glyph has one side fully dominated by FG and the other by BG.

**Core rule:** FG = source color (what the glyph blends into on its dominant side). BG =
destination color (what follows). The FG side faces its source; BG faces the destination.

---

## Glyph Catalog

Two glyphs are used in this setup:

| Variable | Glyph | Codepoint | FG side | Shape | Use |
|---|---|---|---|---|---|
| `SL` | `` | U+E0BC | **Left** | Forward-slash `/` | Segment entry |
| `BS` | `` | U+E0BA | **Right** | Backslash `\` | Sub-split or exit |

**Reading the table:** "FG side = Left" means the FG color fills the left triangle of the
glyph. To blend with the terminal background on the left, set `fg=TERM_BG`.

---

## Recipes

### 1. Terminal → segment entry (SL)

Use at the start of a segment to transition from terminal background into the segment color.

```
#[bg=SEGMENT_BG, fg=TERM_BG]<SL glyph>
```

- Left side (FG = TERM_BG): blends with terminal background to the left
- Right side (BG = SEGMENT_BG): enters the segment

### 2. Value → label sub-split (BS)

Use inside a segment to split a bright value area from a darker label area.

```
#[bg=VALUE_BG, fg=LABEL_BG]<BS glyph>
#[bg=LABEL_BG, fg=#f0f0f0] LABEL TEXT
```

- Left side (BG = VALUE_BG): continues the value segment
- Right side (FG = LABEL_BG): bleeds into the label segment that follows

### 3. Inter-segment valley (BS exit + SL entry)

Use between two segments to create a thin diagonal "V" of terminal background.

```
#[bg=PREV_DK, fg=TERM_BG]<BS glyph>
#[bg=NEXT_BG, fg=TERM_BG]<SL glyph>
```

- BS right side (FG = TERM_BG): exits previous segment back to terminal BG
- SL left side (FG = TERM_BG): enters next segment from terminal BG
- The two complementary slopes create a V-shaped valley of terminal color between segments

---

## Worked Example: CPU Segment

From `status-right` in `tmux-powerline.sh`. Variables: `CPU_BG` = bright CPU color,
`CPU_DK` = darker CPU label color, `TERM_BG` = terminal background (`#282c34`).

```sh
# 1. Entry: terminal BG → CPU_BG via SL
#    FG=TERM_BG (left side blends with bar background)
#    BG=CPU_BG  (right side enters segment)
o="#[bg=${CPU_BG},fg=${TERM_BG}]${SL}"

# 2. Value text: CPU percentage on bright background
o="${o}#[bg=${CPU_BG},fg=#f0f0f0] ${cpu_display} "

# 3. Sub-split: CPU_BG → CPU_DK via BS
#    BG=CPU_BG (left side continues bright area)
#    FG=CPU_DK (right side bleeds into label color)
o="${o}#[bg=${CPU_BG},fg=${CPU_DK}]${BS}"

# 4. Label text: "CPU" on darker background
o="${o}#[bg=${CPU_DK},fg=#f0f0f0,nobold] CPU "

# 5. Exit: CPU_DK → TERM_BG via BS (before next segment's SL entry)
#    BG=CPU_DK (left side finishes segment)
#    FG=TERM_BG (right side returns to terminal BG)
o="${o}#[bg=${CPU_DK},fg=${TERM_BG}]${BS}"
```

The next segment then starts with its own SL entry from TERM_BG, completing the valley.
