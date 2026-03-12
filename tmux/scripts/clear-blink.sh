#!/bin/bash
[ -n "${TMUX_PANE:-}" ] && WIN=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_index}' 2>/dev/null) && [ -n "$WIN" ] && tmux set-window-option -t :"$WIN" @tab_claude_needs_input '' && tmux set-window-option -t :"$WIN" @tab_claude_blink '' && tmux refresh-client -S || true
