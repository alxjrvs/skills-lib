#!/bin/bash
[ -n "${TMUX_PANE:-}" ] && WIN=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_index}' 2>/dev/null) && [ -n "$WIN" ] && tmux set-window-option -t :"$WIN" @tab_claude_needs_input '1' && ~/dotFiles/tmux-scripts/tmux-powerline.sh tab-blink-start "$WIN" || true
