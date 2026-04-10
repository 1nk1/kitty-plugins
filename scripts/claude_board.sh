#!/bin/bash
# ──────────────────────────────────────────────────────────────
#  claude_board.sh — Native Kitty Claude Board
#  Launch: Ctrl+Alt+0
#
#  Opens a new Kitty OS window with 4 tabs:
#    Tab 1: Claude   — 4-pane grid
#    Tab 2: Monitor  — btop
#    Tab 3: Logs     — journalctl live + warnings
#    Tab 4: Shell    — 2 shells side by side
# ──────────────────────────────────────────────────────────────

LOGS_FULL="/tmp/kitty_board_logs_full.sh"
LOGS_WARN="/tmp/kitty_board_logs_warn.sh"

printf '#!/bin/bash\nexec journalctl -f --output=short-precise --no-hostname\n' > "$LOGS_FULL"
printf '#!/bin/bash\nexec journalctl -f -p warning --no-hostname\n' > "$LOGS_WARN"
chmod +x "$LOGS_FULL" "$LOGS_WARN"

SESSION="/tmp/kitty_claude_board.session"

# No comments, no blank lines, no special chars in tab names
cat > "$SESSION" << EOF
new_tab Claude
layout grid
launch
launch
launch
launch
focus_tab
new_tab Monitor
layout stack
launch btop
new_tab Logs
layout horizontal
launch $LOGS_FULL
launch $LOGS_WARN
new_tab Shell
layout vertical
launch
launch
EOF

# --override to suppress startup_session from kitty.conf
kitty --session "$SESSION" --override "startup_session=none" --title "Claude Board" &
disown

echo "Claude Board launched"
