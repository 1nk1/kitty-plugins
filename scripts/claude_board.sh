#!/bin/bash
# ──────────────────────────────────────────────────────────────
#  claude_board.sh — Native Kitty Claude Board
#  Launch: Ctrl+Alt+0
#
#  8 tabs with Nerd Font icons:
#    󰄛 Claude    — 4-pane grid for AI sessions
#     Monitor   — btop system dashboard
#     Logs      — live journal + warnings
#     Network   — connections + traffic
#     Security  — audit + firewall
#     Git       — status + log
#     Docker    — containers + images
#     Shell     — 2 clean shells
# ──────────────────────────────────────────────────────────────

# Helper scripts for commands with args
TMPDIR="/tmp/kitty_board"
mkdir -p "$TMPDIR"

cat > "$TMPDIR/logs_full.sh" << 'SCRIPT'
#!/bin/bash
exec journalctl -f --output=short-precise --no-hostname
SCRIPT

cat > "$TMPDIR/logs_warn.sh" << 'SCRIPT'
#!/bin/bash
exec journalctl -f -p warning --no-hostname
SCRIPT

cat > "$TMPDIR/net_ss.sh" << 'SCRIPT'
#!/bin/bash
watch -n 2 -c 'echo -e "\033[38;2;139;233;253m\033[1m  Active Connections\033[0m"; echo; ss -tupn 2>/dev/null | head -40'
SCRIPT

cat > "$TMPDIR/net_traffic.sh" << 'SCRIPT'
#!/bin/bash
if command -v iftop &>/dev/null; then
    exec sudo iftop -i "$(ip route | awk '/default/ {print $5; exit}')" 2>/dev/null
else
    watch -n 1 -c 'echo -e "\033[38;2;80;250;123m\033[1m  Network Traffic\033[0m"; echo; ip -s -c link show | head -30'
fi
SCRIPT

cat > "$TMPDIR/sec_audit.sh" << 'SCRIPT'
#!/bin/bash
echo -e "\033[38;2;255;85;85m\033[1m  Security Audit\033[0m"
echo
echo -e "\033[38;2;241;250;140m=== Failed logins (last 24h) ===\033[0m"
journalctl -b --no-pager | grep -i 'failed\|authentication failure' | tail -15
echo
echo -e "\033[38;2;241;250;140m=== Listening ports ===\033[0m"
ss -tlnp 2>/dev/null
echo
echo -e "\033[38;2;241;250;140m=== CVE Check ===\033[0m"
arch-audit 2>/dev/null || echo "arch-audit not installed"
echo
echo -e "\033[38;2;98;114;164mPress any key to refresh, q to quit\033[0m"
while read -rsn1 key; do
    [ "$key" = "q" ] && break
    exec "$0"
done
SCRIPT

cat > "$TMPDIR/sec_fw.sh" << 'SCRIPT'
#!/bin/bash
watch -n 5 -c 'echo -e "\033[38;2;255;121;198m\033[1m  Firewall Rules\033[0m"; echo; sudo nft list ruleset 2>/dev/null | head -40 || echo "nftables not configured"'
SCRIPT

cat > "$TMPDIR/git_status.sh" << 'SCRIPT'
#!/bin/bash
watch -n 3 -c 'echo -e "\033[38;2;189;147;249m\033[1m  Git Status\033[0m"; echo; for d in ~/projects/*/; do
    if [ -d "$d/.git" ]; then
        name=$(basename "$d")
        branch=$(git -C "$d" branch --show-current 2>/dev/null)
        changes=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
        if [ "$changes" -gt 0 ]; then
            echo -e "  \033[38;2;255;85;85m$name\033[0m ($branch) — $changes changes"
        else
            echo -e "  \033[38;2;80;250;123m$name\033[0m ($branch)"
        fi
    fi
done'
SCRIPT

cat > "$TMPDIR/git_log.sh" << 'SCRIPT'
#!/bin/bash
cd ~/projects/kitty-plugins 2>/dev/null || cd ~
exec git log --oneline --graph --decorate --color --all -30
SCRIPT

cat > "$TMPDIR/docker_ps.sh" << 'SCRIPT'
#!/bin/bash
if command -v docker &>/dev/null; then
    watch -n 3 -c 'echo -e "\033[38;2;139;233;253m\033[1m  Docker Containers\033[0m"; echo; docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null'
else
    echo -e "\033[38;2;98;114;164mDocker not installed\033[0m"
    echo "Install: sudo pacman -S docker"
    read -rsn1
fi
SCRIPT

cat > "$TMPDIR/docker_img.sh" << 'SCRIPT'
#!/bin/bash
if command -v docker &>/dev/null; then
    watch -n 10 -c 'echo -e "\033[38;2;255;184;108m\033[1m  Docker Images\033[0m"; echo; docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null'
else
    echo -e "\033[38;2;98;114;164mDocker not installed\033[0m"
    read -rsn1
fi
SCRIPT

chmod +x "$TMPDIR"/*.sh

SESSION="/tmp/kitty_claude_board.session"

cat > "$SESSION" << EOF
new_tab 󰄛 Claude
layout grid
launch
launch
launch
launch
new_tab  Monitor
layout stack
launch btop
new_tab  Logs
layout horizontal
launch $TMPDIR/logs_full.sh
launch $TMPDIR/logs_warn.sh
new_tab 󰛳 Network
layout horizontal
launch $TMPDIR/net_ss.sh
launch $TMPDIR/net_traffic.sh
new_tab  Security
layout horizontal
launch $TMPDIR/sec_audit.sh
launch $TMPDIR/sec_fw.sh
new_tab  Git
layout horizontal
launch $TMPDIR/git_status.sh
launch $TMPDIR/git_log.sh
new_tab  Docker
layout horizontal
launch $TMPDIR/docker_ps.sh
launch $TMPDIR/docker_img.sh
new_tab  Shell
layout vertical
launch
launch
EOF

kitty --session "$SESSION" --override "startup_session=none" --title "Claude Board" &
disown

echo "Claude Board launched — 8 tabs"
