#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  claude_board.sh — Neon Board: 4 windows, Kitty Ctrl+Alt+0
#
#  Windows (Alt+Shift+← → or Alt+F1..F4):
#    1 󰄛 claude   — 4-pane Claude Code grid
#    2  monitor  — btop system dashboard
#    3  logs     — live system logs
#    4  shell    — 2 clean shells
#
#  Pane control (no prefix):
#    Alt+1..4        jump to pane
#    Alt+← → ↑ ↓    move between panes
#    Alt+v / Alt+s   split vertical / horizontal
#    Alt+z           zoom / unzoom
#    Alt+Space       cycle layouts
#    Ctrl+a H/J/K/L  resize pane
#    Ctrl+a x        close pane
# ──────────────────────────────────────────────────────────────

SESSION="claude-board"
CLAUDE="/home/adj/.local/bin/claude"

# ── re-attach if already running ────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
    exec tmux attach-session -t "$SESSION"
fi

# ════════════════════════════════════════════════════════════
#  WINDOW 1 — 󰄛 claude  (4-pane Claude grid)
# ════════════════════════════════════════════════════════════
tmux new-session  -d -s "$SESSION" -n "󰄛 claude"

tmux split-window -t "$SESSION:󰄛 claude"
tmux split-window -t "$SESSION:󰄛 claude"
tmux split-window -t "$SESSION:󰄛 claude"
tmux select-layout -t "$SESSION:󰄛 claude" tiled

# ════════════════════════════════════════════════════════════
#  WINDOW 2 —  monitor  (btop full screen)
# ════════════════════════════════════════════════════════════
tmux new-window -t "$SESSION" -n " monitor"
tmux send-keys -t "$SESSION: monitor" "btop" Enter

# ════════════════════════════════════════════════════════════
#  WINDOW 3 —  logs  (live system journal + dmesg split)
# ════════════════════════════════════════════════════════════
tmux new-window -t "$SESSION" -n " logs"
tmux send-keys -t "$SESSION: logs" \
    "journalctl -f --output=short-precise --no-hostname" Enter
tmux split-window -t "$SESSION: logs" -v -p 30
tmux send-keys -t "$SESSION: logs" \
    "journalctl -f -p warning --no-hostname" Enter

# ════════════════════════════════════════════════════════════
#  WINDOW 4 —  shell  (2 clean shells side by side)
# ════════════════════════════════════════════════════════════
tmux new-window -t "$SESSION" -n " shell"
tmux split-window -t "$SESSION: shell" -h

# ── return to window 1, focus first pane ────────────────────
tmux select-window -t "$SESSION:󰄛 claude"
first=$(tmux list-panes -t "$SESSION:󰄛 claude" -F "#{pane_id}" | head -1)
tmux select-pane -t "$first"

# ── attach ──────────────────────────────────────────────────
exec tmux attach-session -t "$SESSION"
