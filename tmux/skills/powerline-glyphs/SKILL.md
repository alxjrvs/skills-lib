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

**Reading the table:** "FG side = Left" means FG fills the left triangle; "FG side = Right"
means FG fills the right triangle. To blend with the terminal background on the FG-dominant
side, set `fg=TERM_BG` on that side.

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

- Left side (BG = VALUE_BG): background fills the left (BG-dominated) side — continues the value segment visually
- Right side (FG = LABEL_BG): FG fills the right (FG-dominated) side — bleeds into the label color that follows

Note: the `bg=LABEL_BG` on the label text line is required — it explicitly sets the background to match the glyph's destination. Without it, the background may not carry over correctly.

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

## Worked Example: Single Segment

Variables: `SEG_VAL` = bright segment color, `SEG_LBL` = darker label color, `TERM_BG` = terminal background.

```sh
# 1. Entry: terminal BG → SEG_VAL via SL
#    FG=TERM_BG (left side blends with bar background)
#    BG=SEG_VAL  (right side enters segment)
o="#[bg=${SEG_VAL},fg=${TERM_BG}]${SL}"

# 2. Value text: content on bright background
o="${o}#[bg=${SEG_VAL},fg=#f0f0f0] ${value} "

# 3. Sub-split: SEG_VAL → SEG_LBL via BS
#    BG=SEG_VAL (left side continues bright area)
#    FG=SEG_LBL (right side bleeds into label color)
o="${o}#[bg=${SEG_VAL},fg=${SEG_LBL}]${BS}"

# 4. Label text: "LABEL" on darker background
o="${o}#[bg=${SEG_LBL},fg=#f0f0f0,nobold] LABEL "

# 5. Exit: SEG_LBL → TERM_BG via BS (before next segment's SL entry)
#    BG=SEG_LBL (left side finishes segment)
#    FG=TERM_BG (right side returns to terminal BG)
o="${o}#[bg=${SEG_LBL},fg=${TERM_BG}]${BS}"
```

The next segment then starts with its own SL entry from TERM_BG, completing the valley.
