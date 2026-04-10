#!/bin/bash
# ──────────────────────────────────────────────────────────────
#  claude_board.sh — Native Kitty Claude Board
#  Launch: Ctrl+Alt+0
#
#  8 tabs with Nerd Font icons:
#    󰄛 Claude    — 4-pane grid for AI sessions
#     Monitor   — btop system dashboard
#     Logs      — live journal + warnings
#    󰛳 Network   — connections + traffic
#     Security  — audit + firewall
#     Git       — status + log
#     Docker    — containers + images
#     Shell     — 2 clean shells
# ──────────────────────────────────────────────────────────────

D="/tmp/kitty_board"
mkdir -p "$D"

# ── Dracula color vars for scripts ───────────────────────────
# Embedded in each script since they run in separate shells
COL='P="\033[38;2;189;147;249m" C="\033[38;2;139;233;253m" G="\033[38;2;80;250;123m" Y="\033[38;2;241;250;140m" R="\033[38;2;255;85;85m" O="\033[38;2;255;184;108m" K="\033[38;2;255;121;198m" D="\033[38;2;98;114;164m" W="\033[38;2;248;248;242m" B="\033[1m" N="\033[0m" DIM="\033[2m"'

# ═══════════════════════════════════════════════════════════════
#  LOGS
# ═══════════════════════════════════════════════════════════════
cat > "$D/logs_full.sh" << 'S'
#!/bin/bash
echo -e "\033[38;2;139;233;253m\033[1m   System Journal — Live\033[0m"
echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
exec journalctl -f --output=short-precise --no-hostname
S

cat > "$D/logs_warn.sh" << 'S'
#!/bin/bash
echo -e "\033[38;2;255;85;85m\033[1m   Warnings & Errors\033[0m"
echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
exec journalctl -f -p warning --no-hostname
S

# ═══════════════════════════════════════════════════════════════
#  NETWORK
# ═══════════════════════════════════════════════════════════════
cat > "$D/net_conn.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;139;233;253m\033[1m  󰛳  Active Connections\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    # Header
    printf "\033[38;2;189;147;249m\033[1m  %-8s %-22s %-22s %-20s\033[0m\n" "Proto" "Local" "Remote" "Process"
    echo -e "\033[38;2;98;114;164m  ────────────────────────────────────────────────────────────────────────────\033[0m"

    # Parse ss output with colors
    ss -tupn 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        proto=$(echo "$line" | awk '{print $1}')
        local_addr=$(echo "$line" | awk '{print $5}')
        remote_addr=$(echo "$line" | awk '{print $6}')
        # Extract process name from users:(("name",pid=...))
        proc=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' | head -1)
        [ -z "$proc" ] && proc="-"

        # Color by process type
        case "$proc" in
            claude*|node) pc="\033[38;2;189;147;249m" ;;  # purple
            zen*|firefox) pc="\033[38;2;255;184;108m" ;;   # orange
            Telegram*)    pc="\033[38;2;139;233;253m" ;;   # cyan
            ssh*)         pc="\033[38;2;80;250;123m" ;;    # green
            steam*|Discord*) pc="\033[38;2;255;121;198m" ;; # pink
            *)            pc="\033[38;2;248;248;242m" ;;   # white
        esac

        printf "  \033[38;2;241;250;140m%-8s\033[0m \033[38;2;248;248;242m%-22s\033[0m \033[38;2;98;114;164m%-22s\033[0m ${pc}%-20s\033[0m\n" \
            "$proto" "${local_addr:0:22}" "${remote_addr:0:22}" "${proc:0:20}"
    done | head -35

    echo
    # Summary
    total=$(ss -tun 2>/dev/null | tail -n +2 | wc -l)
    tcp=$(ss -tn 2>/dev/null | tail -n +2 | wc -l)
    udp=$(ss -un 2>/dev/null | tail -n +2 | wc -l)
    listen=$(ss -tlnp 2>/dev/null | tail -n +2 | wc -l)
    echo -e "  \033[38;2;98;114;164m───\033[0m \033[38;2;189;147;249m\033[1m$total\033[0m connections  \033[38;2;139;233;253mTCP:$tcp\033[0m  \033[38;2;80;250;123mUDP:$udp\033[0m  \033[38;2;255;184;108mListening:$listen\033[0m"

    sleep 2
done
SCRIPT

cat > "$D/net_traffic.sh" << 'SCRIPT'
#!/bin/bash
IFACE=$(ip route | awk '/default/ {print $5; exit}')
[ -z "$IFACE" ] && IFACE="lo"

prev_rx=0; prev_tx=0

while true; do
    clear
    echo -e "\033[38;2;80;250;123m\033[1m   Network Traffic — $IFACE\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    rx=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    tx=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)

    if [ "$prev_rx" -gt 0 ]; then
        rx_rate=$(( (rx - prev_rx) ))
        tx_rate=$(( (tx - prev_tx) ))

        # Human-readable rates
        if [ "$rx_rate" -gt 1048576 ]; then
            rx_h="$(( rx_rate / 1048576 )) MB/s"
        elif [ "$rx_rate" -gt 1024 ]; then
            rx_h="$(( rx_rate / 1024 )) KB/s"
        else
            rx_h="$rx_rate B/s"
        fi

        if [ "$tx_rate" -gt 1048576 ]; then
            tx_h="$(( tx_rate / 1048576 )) MB/s"
        elif [ "$tx_rate" -gt 1024 ]; then
            tx_h="$(( tx_rate / 1024 )) KB/s"
        else
            tx_h="$tx_rate B/s"
        fi

        echo -e "  \033[38;2;80;250;123m  Download:\033[0m  \033[38;2;248;248;242m\033[1m$rx_h\033[0m"
        echo -e "  \033[38;2;255;85;85m  Upload:  \033[0m  \033[38;2;248;248;242m\033[1m$tx_h\033[0m"
    else
        echo -e "  \033[38;2;98;114;164mMeasuring...\033[0m"
    fi

    prev_rx=$rx; prev_tx=$tx

    echo
    echo -e "  \033[38;2;189;147;249m\033[1m  Total Transfer\033[0m"
    echo -e "  \033[38;2;98;114;164m────────────────────\033[0m"

    rx_total=$(( rx / 1048576 ))
    tx_total=$(( tx / 1048576 ))
    echo -e "  \033[38;2;80;250;123m  RX:\033[0m  ${rx_total} MB"
    echo -e "  \033[38;2;255;85;85m  TX:\033[0m  ${tx_total} MB"

    echo
    echo -e "  \033[38;2;189;147;249m\033[1m  IP Addresses\033[0m"
    echo -e "  \033[38;2;98;114;164m────────────────────\033[0m"
    ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet / {print "  \033[38;2;139;233;253m  IPv4:\033[0m  "$2}'
    ip -6 addr show "$IFACE" 2>/dev/null | awk '/inet6.*scope global/ {print "  \033[38;2;241;250;140m  IPv6:\033[0m  "$2}'

    echo
    echo -e "  \033[38;2;189;147;249m\033[1m  DNS\033[0m"
    echo -e "  \033[38;2;98;114;164m────────────────────\033[0m"
    resolvectl status "$IFACE" 2>/dev/null | grep 'DNS Servers' | sed 's/^/  /'

    sleep 1
done
SCRIPT

# ═══════════════════════════════════════════════════════════════
#  SECURITY (no sudo!)
# ═══════════════════════════════════════════════════════════════
cat > "$D/sec_audit.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;255;85;85m\033[1m   Security Audit\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    echo -e "  \033[38;2;241;250;140m\033[1m  Failed Auth (last 24h)\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    count=$(journalctl -b --no-pager 2>/dev/null | grep -ci 'failed\|authentication failure' || echo 0)
    if [ "$count" -gt 10 ]; then
        echo -e "  \033[38;2;255;85;85m\033[1m    $count attempts\033[0m"
    elif [ "$count" -gt 0 ]; then
        echo -e "  \033[38;2;255;184;108m    $count attempts\033[0m"
    else
        echo -e "  \033[38;2;80;250;123m    Clean — 0 failures\033[0m"
    fi
    journalctl -b --no-pager 2>/dev/null | grep -i 'failed\|authentication failure' | tail -5 | while IFS= read -r l; do
        echo -e "    \033[38;2;98;114;164m$l\033[0m"
    done

    echo
    echo -e "  \033[38;2;139;233;253m\033[1m  Listening Services\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    ss -tlnp 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        port=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
        proc=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' | head -1)
        [ -z "$proc" ] && proc="?"
        printf "    \033[38;2;80;250;123m%-6s\033[0m \033[38;2;248;248;242m%s\033[0m\n" ":$port" "$proc"
    done

    echo
    echo -e "  \033[38;2;255;121;198m\033[1m  Package CVEs\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    if command -v arch-audit &>/dev/null; then
        arch-audit 2>/dev/null | while IFS= read -r line; do
            if echo "$line" | grep -q 'High'; then
                echo -e "    \033[38;2;255;85;85m$line\033[0m"
            elif echo "$line" | grep -q 'Medium'; then
                echo -e "    \033[38;2;255;184;108m$line\033[0m"
            else
                echo -e "    \033[38;2;241;250;140m$line\033[0m"
            fi
        done
    else
        echo -e "    \033[38;2;98;114;164march-audit not installed\033[0m"
    fi

    echo
    echo -e "  \033[38;2;189;147;249m\033[1m  System Info\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    echo -e "    \033[38;2;139;233;253m Kernel:\033[0m  $(uname -r)"
    echo -e "    \033[38;2;80;250;123m Uptime:\033[0m  $(uptime -p | sed 's/up //')"
    echo -e "    \033[38;2;241;250;140m Users: \033[0m  $(who | wc -l) active"

    echo
    echo -e "  \033[38;2;98;114;164m  r=refresh  q=quit\033[0m"
    read -rsn1 -t 30 key
    [ "$key" = "q" ] && break
done
SCRIPT

cat > "$D/sec_fw.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;255;121;198m\033[1m   Firewall & Ports\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    echo -e "  \033[38;2;241;250;140m\033[1m  Open Ports (external)\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    ss -tlnp 2>/dev/null | tail -n +2 | grep -v '127.0.0.1\|::1\|\[::1\]' | while IFS= read -r line; do
        addr=$(echo "$line" | awk '{print $4}')
        proc=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' | head -1)
        printf "    \033[38;2;255;85;85m%-25s\033[0m  \033[38;2;248;248;242m%s\033[0m\n" "$addr" "$proc"
    done
    ext_count=$(ss -tlnp 2>/dev/null | tail -n +2 | grep -v '127.0.0.1\|::1\|\[::1\]' | wc -l)
    [ "$ext_count" -eq 0 ] && echo -e "    \033[38;2;80;250;123m  All ports local-only — good!\033[0m"

    echo
    echo -e "  \033[38;2;139;233;253m\033[1m 󰒘 Established Connections by Process\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    ss -tupn 2>/dev/null | tail -n +2 | grep -oP 'users:\(\("\K[^"]+' | sort | uniq -c | sort -rn | head -10 | while read cnt proc; do
        bar=""
        for ((i=0; i<cnt && i<30; i++)); do bar+="█"; done
        printf "    \033[38;2;189;147;249m%-15s\033[0m \033[38;2;80;250;123m%3d\033[0m \033[38;2;139;233;253m%s\033[0m\n" "$proc" "$cnt" "$bar"
    done

    echo
    echo -e "  \033[38;2;98;114;164m  Auto-refreshing every 10s  q=quit\033[0m"
    read -rsn1 -t 10 key
    [ "$key" = "q" ] && break
done
SCRIPT

# ═══════════════════════════════════════════════════════════════
#  GIT
# ═══════════════════════════════════════════════════════════════
cat > "$D/git_status.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;189;147;249m\033[1m   Git Repos — ~/projects\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    for d in ~/projects/*/; do
        [ -d "$d/.git" ] || continue
        name=$(basename "$d")
        branch=$(git -C "$d" branch --show-current 2>/dev/null)
        changes=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
        ahead=$(git -C "$d" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
        behind=$(git -C "$d" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)

        # Status indicator
        if [ "$changes" -gt 0 ]; then
            icon=""; color="\033[38;2;255;85;85m"
            detail=" ${changes} changed"
        else
            icon=""; color="\033[38;2;80;250;123m"
            detail=""
        fi

        # Ahead/behind
        sync=""
        [ "$ahead" -gt 0 ] && sync+=" ↑${ahead}"
        [ "$behind" -gt 0 ] && sync+=" ↓${behind}"

        printf "  ${color}${icon}\033[0m  \033[38;2;248;248;242m\033[1m%-25s\033[0m \033[38;2;189;147;249m %s\033[0m${color}${detail}\033[0m\033[38;2;241;250;140m${sync}\033[0m\n" \
            "$name" "$branch"
    done

    echo
    echo -e "  \033[38;2;98;114;164m  Auto-refreshing every 5s  q=quit\033[0m"
    read -rsn1 -t 5 key
    [ "$key" = "q" ] && break
done
SCRIPT

cat > "$D/git_log.sh" << 'SCRIPT'
#!/bin/bash
echo -e "\033[38;2;255;184;108m\033[1m   Recent Commits\033[0m"
echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo
cd ~/projects/kitty-plugins 2>/dev/null || cd ~
git log --oneline --graph --decorate --color --all -40
echo
echo -e "\033[38;2;98;114;164m  Press q to quit\033[0m"
read -rsn1
SCRIPT

# ═══════════════════════════════════════════════════════════════
#  DOCKER
# ═══════════════════════════════════════════════════════════════
cat > "$D/docker_ps.sh" << 'SCRIPT'
#!/bin/bash
if ! command -v docker &>/dev/null; then
    clear
    echo -e "\033[38;2;139;233;253m\033[1m   Docker\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo
    echo -e "  \033[38;2;98;114;164m  Docker not installed\033[0m"
    echo -e "  \033[38;2;241;250;140m  Install: sudo pacman -S docker\033[0m"
    read -rsn1
    exit 0
fi
while true; do
    clear
    echo -e "\033[38;2;139;233;253m\033[1m   Containers\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo
    running=$(docker ps -q 2>/dev/null | wc -l)
    stopped=$(docker ps -aq 2>/dev/null | wc -l)
    echo -e "  \033[38;2;80;250;123m  Running: $running\033[0m   \033[38;2;98;114;164m  Total: $stopped\033[0m"
    echo
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -1 | sed 's/^/  \x1b[38;2;189;147;249m\x1b[1m/' | sed 's/$/\x1b[0m/'
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tail -n +2 | sed 's/^/  /'
    echo
    echo -e "  \033[38;2;98;114;164m  Refreshing every 5s  q=quit\033[0m"
    read -rsn1 -t 5 key
    [ "$key" = "q" ] && break
done
SCRIPT

cat > "$D/docker_img.sh" << 'SCRIPT'
#!/bin/bash
if ! command -v docker &>/dev/null; then
    clear
    echo -e "\033[38;2;255;184;108m\033[1m   Images\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo
    echo -e "  \033[38;2;98;114;164m  Docker not installed\033[0m"
    read -rsn1
    exit 0
fi
while true; do
    clear
    echo -e "\033[38;2;255;184;108m\033[1m   Docker Images\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo
    total=$(docker images -q 2>/dev/null | wc -l)
    size=$(docker system df --format "{{.Size}}" 2>/dev/null | head -1)
    echo -e "  \033[38;2;189;147;249m  Images: $total\033[0m   \033[38;2;241;250;140m  Disk: $size\033[0m"
    echo
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" 2>/dev/null | head -1 | sed 's/^/  \x1b[38;2;189;147;249m\x1b[1m/' | sed 's/$/\x1b[0m/'
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" 2>/dev/null | tail -n +2 | sed 's/^/  /'
    echo
    echo -e "  \033[38;2;98;114;164m  Refreshing every 10s  q=quit\033[0m"
    read -rsn1 -t 10 key
    [ "$key" = "q" ] && break
done
SCRIPT

chmod +x "$D"/*.sh

# ═══════════════════════════════════════════════════════════════
#  SESSION FILE
# ═══════════════════════════════════════════════════════════════
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
launch $D/logs_full.sh
launch $D/logs_warn.sh
new_tab 󰛳 Network
layout horizontal
launch $D/net_conn.sh
launch $D/net_traffic.sh
new_tab  Security
layout horizontal
launch $D/sec_audit.sh
launch $D/sec_fw.sh
new_tab  Git
layout horizontal
launch $D/git_status.sh
launch $D/git_log.sh
new_tab  Docker
layout horizontal
launch $D/docker_ps.sh
launch $D/docker_img.sh
new_tab  Shell
layout vertical
launch
launch
EOF

kitty --session "$SESSION" --override "startup_session=none" --title "Claude Board" &
disown

echo "Claude Board launched — 8 tabs"
