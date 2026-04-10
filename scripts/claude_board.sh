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

# ═══════════════════════════════════════════════════════════════
#  GPU
# ═══════════════════════════════════════════════════════════════
cat > "$D/gpu_stats.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;189;147;249m\033[1m  󰢮  AMD GPU — RX 7900 XT\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    if command -v rocm-smi &>/dev/null; then
        # Temperature
        edge=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
        junc=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp2_input 2>/dev/null | head -1)
        mem_t=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp3_input 2>/dev/null | head -1)

        [ -n "$edge" ] && edge=$((edge/1000)) || edge="?"
        [ -n "$junc" ] && junc=$((junc/1000)) || junc="?"
        [ -n "$mem_t" ] && mem_t=$((mem_t/1000)) || mem_t="?"

        tc="\033[38;2;80;250;123m"
        [ "$edge" != "?" ] && [ "$edge" -gt 70 ] && tc="\033[38;2;241;250;140m"
        [ "$edge" != "?" ] && [ "$edge" -gt 85 ] && tc="\033[38;2;255;85;85m"

        echo -e "  \033[38;2;241;250;140m\033[1m  Temperatures\033[0m"
        echo -e "    ${tc}Edge:     ${edge}°C\033[0m"
        echo -e "    ${tc}Junction: ${junc}°C\033[0m"
        echo -e "    ${tc}Memory:   ${mem_t}°C\033[0m"

        echo
        echo -e "  \033[38;2;139;233;253m\033[1m  Performance\033[0m"

        # GPU busy
        busy=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
        [ -z "$busy" ] && busy="?"
        bc="\033[38;2;80;250;123m"
        [ "$busy" != "?" ] && [ "$busy" -gt 50 ] && bc="\033[38;2;241;250;140m"
        [ "$busy" != "?" ] && [ "$busy" -gt 80 ] && bc="\033[38;2;255;85;85m"
        echo -e "    ${bc}GPU Load:  ${busy}%\033[0m"

        # Clocks
        sclk=$(cat /sys/class/drm/card*/device/pp_dpm_sclk 2>/dev/null | grep '\*' | awk '{print $2}')
        mclk=$(cat /sys/class/drm/card*/device/pp_dpm_mclk 2>/dev/null | grep '\*' | awk '{print $2}')
        echo -e "    \033[38;2;248;248;242mGPU Clock: ${sclk:-?}\033[0m"
        echo -e "    \033[38;2;248;248;242mMem Clock: ${mclk:-?}\033[0m"

        # Power
        power=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/power1_average 2>/dev/null | head -1)
        [ -n "$power" ] && power=$((power/1000000)) || power="?"
        echo -e "    \033[38;2;255;184;108m Power:    ${power}W\033[0m"

        # Fan
        fan=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/fan1_input 2>/dev/null | head -1)
        echo -e "    \033[38;2;139;233;253m Fan:      ${fan:-0} RPM\033[0m"
    else
        echo -e "  \033[38;2;98;114;164mrocm-smi not installed\033[0m"
        echo -e "  \033[38;2;241;250;140mInstall: sudo pacman -S rocm-smi-lib\033[0m"
    fi

    sleep 1
done
SCRIPT

cat > "$D/gpu_vram.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;255;184;108m\033[1m   VRAM Usage\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    used=$(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -1)
    total=$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | head -1)

    if [ -n "$used" ] && [ -n "$total" ]; then
        used_mb=$((used/1048576))
        total_mb=$((total/1048576))
        pct=$((used*100/total))

        vc="\033[38;2;80;250;123m"
        [ "$pct" -gt 50 ] && vc="\033[38;2;241;250;140m"
        [ "$pct" -gt 80 ] && vc="\033[38;2;255;85;85m"

        echo -e "  ${vc}\033[1m  ${used_mb} MB / ${total_mb} MB  (${pct}%)\033[0m"
        echo

        # Bar graph
        bar_width=40
        filled=$((pct*bar_width/100))
        empty=$((bar_width-filled))
        bar=""
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=0; i<empty; i++)); do bar+="░"; done
        echo -e "  ${vc}  [${bar}]\033[0m"
    else
        echo -e "  \033[38;2;98;114;164mVRAM info not available\033[0m"
    fi

    echo
    echo -e "  \033[38;2;189;147;249m\033[1m  GPU Processes\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"

    if command -v rocm-smi &>/dev/null; then
        rocm-smi --showpids 2>/dev/null | grep -v '=' | grep -v '^$' | while IFS= read -r line; do
            echo -e "    \033[38;2;248;248;242m$line\033[0m"
        done
    fi

    # Also show processes using the GPU via /proc
    ls /proc/*/fdinfo/* 2>/dev/null | head -1 >/dev/null 2>&1
    echo
    echo -e "  \033[38;2;139;233;253m\033[1m  DRM Clients\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    for pid_dir in /proc/[0-9]*/fdinfo; do
        pid=${pid_dir#/proc/}; pid=${pid%/fdinfo}
        if grep -q 'drm-memory-vram' "$pid_dir"/* 2>/dev/null; then
            cmd=$(cat /proc/$pid/comm 2>/dev/null)
            vram=$(grep 'drm-memory-vram' "$pid_dir"/* 2>/dev/null | awk '{sum+=$2} END {printf "%.0f", sum/1024}')
            [ -n "$cmd" ] && printf "    \033[38;2;80;250;123m%-20s\033[0m \033[38;2;255;184;108m%s MB\033[0m\n" "$cmd" "$vram"
        fi
    done 2>/dev/null | sort -t$'\t' -k2 -rn | head -10

    sleep 2
done
SCRIPT

# ═══════════════════════════════════════════════════════════════
#  DISK
# ═══════════════════════════════════════════════════════════════
cat > "$D/disk_space.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;189;147;249m\033[1m  󰋊  Filesystem Space\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    printf "  \033[38;2;189;147;249m\033[1m%-20s %6s %6s %6s %5s\033[0m\n" "Mount" "Size" "Used" "Avail" "Use%"
    echo -e "  \033[38;2;98;114;164m────────────────────────────────────────────────────────\033[0m"

    df -h --output=target,size,used,avail,pcent -x tmpfs -x devtmpfs -x efivarfs -x squashfs 2>/dev/null | tail -n +2 | grep -v '/snap' | sort | while IFS= read -r line; do
        mount=$(echo "$line" | awk '{print $1}')
        # Skip loop, snap, and other noise mounts
        [[ "$mount" == /var/lib/snapd/* ]] && continue
        [[ "$mount" == /snap/* ]] && continue
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        avail=$(echo "$line" | awk '{print $4}')
        pct=$(echo "$line" | awk '{print $5}' | tr -d '%')

        color="\033[38;2;80;250;123m"
        [ "$pct" -gt 60 ] && color="\033[38;2;241;250;140m"
        [ "$pct" -gt 80 ] && color="\033[38;2;255;184;108m"
        [ "$pct" -gt 90 ] && color="\033[38;2;255;85;85m"

        # Bar
        bw=15; filled=$((pct*bw/100)); empty=$((bw-filled))
        bar=""; for ((i=0;i<filled;i++)); do bar+="█"; done; for ((i=0;i<empty;i++)); do bar+="░"; done

        printf "  ${color}%-20s %6s %6s %6s  [%s] %s%%\033[0m\n" "${mount:0:20}" "$size" "$used" "$avail" "$bar" "$pct"
    done

    echo
    echo -e "  \033[38;2;139;233;253m\033[1m  Drives\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    lsblk -d -o NAME,SIZE,MODEL,ROTA,TRAN 2>/dev/null | tail -n +2 | while read name size model rota tran; do
        # Skip loop, zram, ram devices
        [[ "$name" == loop* || "$name" == zram* || "$name" == ram* ]] && continue
        # Detect type by transport, not ROTA (ROTA is wrong for NVMe)
        if [[ "$tran" == "nvme" ]]; then
            type_icon="\033[38;2;80;250;123m󰋊 NVMe"
        elif [[ "$rota" == "0" ]]; then
            type_icon="\033[38;2;139;233;253m󰋊 SSD "
        else
            type_icon="\033[38;2;255;184;108m HDD "
        fi
        printf "    \033[38;2;248;248;242m%-8s\033[0m \033[38;2;248;248;242m%-8s\033[0m ${type_icon}\033[0m  \033[38;2;98;114;164m%s\033[0m\n" "$name" "$size" "$model"
    done

    echo
    echo -e "  \033[38;2;98;114;164m  Refreshing every 30s  q=quit\033[0m"
    read -rsn1 -t 30 key
    [ "$key" = "q" ] && break
done
SCRIPT

cat > "$D/disk_io.sh" << 'SCRIPT'
#!/bin/bash
prev_r=(); prev_w=()

while true; do
    clear
    echo -e "\033[38;2;255;184;108m\033[1m   Disk I/O — Live\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    printf "  \033[38;2;189;147;249m\033[1m%-12s %10s %10s %8s %8s %6s\033[0m\n" \
        "Device" "Read/s" "Write/s" "R MB/s" "W MB/s" "Util%"
    echo -e "  \033[38;2;98;114;164m────────────────────────────────────────────────────────────\033[0m"

    idx=0
    for dev in /sys/block/*/stat; do
        name=$(basename $(dirname "$dev"))
        # Skip loop, ram, dm, zram devices
        [[ "$name" == loop* || "$name" == ram* || "$name" == dm-* || "$name" == zram* ]] && continue

        read r_io _ r_sec _ w_io _ w_sec _ _ _ _ _ _ _ _ < "$dev" 2>/dev/null || continue

        # Calculate deltas
        pr=${prev_r[$idx]:-$r_io}; pw=${prev_w[$idx]:-$w_io}
        pr_sec=${prev_r_sec[$idx]:-$r_sec}; pw_sec=${prev_w_sec[$idx]:-$w_sec}

        d_rio=$((r_io - pr))
        d_wio=$((w_io - pw))
        d_rsec=$((r_sec - pr_sec))
        d_wsec=$((w_sec - pw_sec))

        # Sectors are 512 bytes
        r_mb=$(awk "BEGIN {printf \"%.1f\", $d_rsec * 512 / 1048576}")
        w_mb=$(awk "BEGIN {printf \"%.1f\", $d_wsec * 512 / 1048576}")

        prev_r[$idx]=$r_io; prev_w[$idx]=$w_io
        prev_r_sec[$idx]=$r_sec; prev_w_sec[$idx]=$w_sec

        # Color by activity
        if [ "$d_rio" -gt 100 ] || [ "$d_wio" -gt 100 ]; then
            dc="\033[38;2;255;85;85m"
        elif [ "$d_rio" -gt 10 ] || [ "$d_wio" -gt 10 ]; then
            dc="\033[38;2;241;250;140m"
        elif [ "$d_rio" -gt 0 ] || [ "$d_wio" -gt 0 ]; then
            dc="\033[38;2;80;250;123m"
        else
            dc="\033[38;2;98;114;164m"
        fi

        # Activity bar
        total=$((d_rio + d_wio))
        bw=10
        if [ "$total" -gt 0 ]; then
            level=$((total > 100 ? 10 : total / 10))
            [ "$level" -gt "$bw" ] && level=$bw
        else
            level=0
        fi
        bar=""; for ((i=0;i<level;i++)); do bar+="█"; done; for ((i=level;i<bw;i++)); do bar+="░"; done

        printf "  ${dc}%-12s %10d %10d %7s %7s  [%s]\033[0m\n" \
            "$name" "$d_rio" "$d_wio" "$r_mb" "$w_mb" "$bar"

        idx=$((idx+1))
    done

    echo
    echo -e "  \033[38;2;139;233;253m\033[1m  Filesystem Writes\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    # Dirty pages
    dirty=$(grep 'Dirty:' /proc/meminfo 2>/dev/null | awk '{print $2}')
    writeback=$(grep 'Writeback:' /proc/meminfo 2>/dev/null | awk '{print $2}')
    echo -e "    \033[38;2;241;250;140mDirty pages:\033[0m  ${dirty:-0} kB"
    echo -e "    \033[38;2;241;250;140mWriteback:\033[0m    ${writeback:-0} kB"

    sleep 1
done
SCRIPT

# ═══════════════════════════════════════════════════════════════
#  THERMALS
# ═══════════════════════════════════════════════════════════════
cat > "$D/thermals.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;255;85;85m\033[1m  󰔏  Temperatures\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    echo -e "  \033[38;2;189;147;249m\033[1m  CPU\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    sensors -A 2>/dev/null | grep -A 3 'k10temp\|coretemp\|zenpower' | grep -E 'Tctl|Tdie|Core|Package' | while IFS= read -r line; do
        temp=$(echo "$line" | grep -oP '\+\K[0-9]+' | head -1)
        tc="\033[38;2;80;250;123m"
        [ -n "$temp" ] && [ "$temp" -gt 65 ] && tc="\033[38;2;241;250;140m"
        [ -n "$temp" ] && [ "$temp" -gt 80 ] && tc="\033[38;2;255;85;85m"
        echo -e "    ${tc}${line}\033[0m"
    done

    echo
    echo -e "  \033[38;2;189;147;249m\033[1m 󰢮 GPU\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    for f in /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input; do
        [ -f "$f" ] || continue
        label_f="${f%_input}_label"
        label=$(cat "$label_f" 2>/dev/null || echo "Sensor")
        temp=$(($(cat "$f" 2>/dev/null || echo 0)/1000))
        tc="\033[38;2;80;250;123m"
        [ "$temp" -gt 70 ] && tc="\033[38;2;241;250;140m"
        [ "$temp" -gt 85 ] && tc="\033[38;2;255;85;85m"
        printf "    ${tc}%-15s %d°C\033[0m\n" "$label" "$temp"
    done

    echo
    echo -e "  \033[38;2;189;147;249m\033[1m 󰋊 NVMe\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    for dev in /sys/class/nvme/nvme*; do
        [ -d "$dev" ] || continue
        name=$(basename "$dev")
        temp_f=$(ls "$dev"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
        [ -f "$temp_f" ] || continue
        temp=$(($(cat "$temp_f")/1000))
        tc="\033[38;2;80;250;123m"
        [ "$temp" -gt 50 ] && tc="\033[38;2;241;250;140m"
        [ "$temp" -gt 70 ] && tc="\033[38;2;255;85;85m"
        model=$(cat "$dev/model" 2>/dev/null | xargs)
        printf "    ${tc}%-8s %d°C\033[0m  \033[38;2;98;114;164m%s\033[0m\n" "$name" "$temp" "$model"
    done

    echo
    echo -e "  \033[38;2;189;147;249m\033[1m  Fan\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    for f in /sys/class/drm/card*/device/hwmon/hwmon*/fan*_input; do
        [ -f "$f" ] || continue
        rpm=$(cat "$f" 2>/dev/null || echo 0)
        label_f="${f%_input}_label"
        label=$(cat "$label_f" 2>/dev/null || echo "Fan")
        fc="\033[38;2;80;250;123m"
        [ "$rpm" -gt 1500 ] && fc="\033[38;2;241;250;140m"
        [ "$rpm" -gt 2500 ] && fc="\033[38;2;255;85;85m"
        printf "    ${fc}%-8s %d RPM\033[0m\n" "$label" "$rpm"
    done

    sleep 2
done
SCRIPT

cat > "$D/cpu_freq.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;139;233;253m\033[1m   CPU Frequency\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    core=0
    for freq_f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -f "$freq_f" ] || continue
        cur=$(($(cat "$freq_f")/1000))
        max_f="${freq_f/scaling_cur_freq/scaling_max_freq}"
        max=$(($(cat "$max_f" 2>/dev/null || echo 1)/1000))
        [ "$max" -eq 0 ] && max=1
        pct=$((cur*100/max))

        fc="\033[38;2;80;250;123m"
        [ "$pct" -gt 60 ] && fc="\033[38;2;241;250;140m"
        [ "$pct" -gt 85 ] && fc="\033[38;2;255;184;108m"
        [ "$pct" -gt 95 ] && fc="\033[38;2;255;85;85m"

        bw=12; filled=$((pct*bw/100)); empty=$((bw-filled))
        bar=""; for ((i=0;i<filled;i++)); do bar+="█"; done; for ((i=0;i<empty;i++)); do bar+="░"; done

        printf "  ${fc}Core %2d  %4d MHz  [%s] %2d%%\033[0m\n" "$core" "$cur" "$bar" "$pct"
        core=$((core+1))
    done

    echo
    gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null)
    echo -e "  \033[38;2;189;147;249mGovernor:\033[0m \033[38;2;248;248;242m${gov:-?}\033[0m"
    if [ "$boost" = "1" ]; then
        echo -e "  \033[38;2;189;147;249mBoost:\033[0m    \033[38;2;80;250;123mEnabled\033[0m"
    else
        echo -e "  \033[38;2;189;147;249mBoost:\033[0m    \033[38;2;255;85;85mDisabled\033[0m"
    fi

    sleep 1
done
SCRIPT

# ═══════════════════════════════════════════════════════════════
#  UPDATES
# ═══════════════════════════════════════════════════════════════
cat > "$D/updates.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;189;147;249m\033[1m  󰏔  Pending Updates\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    if command -v checkupdates &>/dev/null; then
        updates=$(checkupdates 2>/dev/null)
        count=$(echo "$updates" | grep -c .)

        if [ "$count" -gt 0 ]; then
            uc="\033[38;2;255;184;108m"
            [ "$count" -gt 20 ] && uc="\033[38;2;255;85;85m"
            echo -e "  ${uc}\033[1m  $count packages available\033[0m"
            echo
            echo "$updates" | while read pkg old _ new; do
                printf "    \033[38;2;139;233;253m%-30s\033[0m \033[38;2;255;85;85m%-15s\033[0m \033[38;2;80;250;123m%s\033[0m\n" "$pkg" "$old" "$new"
            done | head -30
        else
            echo -e "  \033[38;2;80;250;123m\033[1m  System is up to date\033[0m"
        fi
    else
        echo -e "  \033[38;2;98;114;164m  checkupdates not available\033[0m"
        echo -e "  \033[38;2;241;250;140m  Install: sudo pacman -S pacman-contrib\033[0m"
    fi

    echo
    echo -e "  \033[38;2;255;85;85m\033[1m  CVE Exposure\033[0m"
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
    echo -e "  \033[38;2;98;114;164m  Refreshing every 30min  q=quit\033[0m"
    read -rsn1 -t 1800 key
    [ "$key" = "q" ] && break
done
SCRIPT

cat > "$D/pacman_log.sh" << 'SCRIPT'
#!/bin/bash
while true; do
    clear
    echo -e "\033[38;2;255;184;108m\033[1m   Recent Activity\033[0m"
    echo -e "\033[38;2;98;114;164m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo

    echo -e "  \033[38;2;241;250;140m\033[1m  Last 7 Days\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    cutoff=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
    grep -E '^\[' /var/log/pacman.log 2>/dev/null | while IFS= read -r line; do
        date=$(echo "$line" | grep -oP '^\[\K[0-9]{4}-[0-9]{2}-[0-9]{2}')
        [ -z "$date" ] && continue
        [[ "$date" < "$cutoff" ]] && continue
        if echo "$line" | grep -q 'installed'; then
            echo -e "    \033[38;2;80;250;123m$line\033[0m"
        elif echo "$line" | grep -q 'upgraded'; then
            echo -e "    \033[38;2;241;250;140m$line\033[0m"
        elif echo "$line" | grep -q 'removed'; then
            echo -e "    \033[38;2;255;85;85m$line\033[0m"
        fi
    done | tail -30

    echo
    echo -e "  \033[38;2;139;233;253m\033[1m  AUR Packages\033[0m"
    echo -e "  \033[38;2;98;114;164m  ────────────────────────\033[0m"
    aur_count=$(pacman -Qm 2>/dev/null | wc -l)
    echo -e "    \033[38;2;248;248;242m$aur_count AUR packages installed\033[0m"
    pacman -Qm 2>/dev/null | while read pkg ver; do
        printf "    \033[38;2;255;184;108m%-30s\033[0m \033[38;2;98;114;164m%s\033[0m\n" "$pkg" "$ver"
    done | head -15

    echo
    orphans=$(pacman -Qdtq 2>/dev/null | wc -l)
    if [ "$orphans" -gt 0 ]; then
        echo -e "  \033[38;2;255;85;85m  $orphans orphaned packages\033[0m"
    else
        echo -e "  \033[38;2;80;250;123m  No orphaned packages\033[0m"
    fi

    echo
    echo -e "  \033[38;2;98;114;164m  Refreshing every 30min  q=quit\033[0m"
    read -rsn1 -t 1800 key
    [ "$key" = "q" ] && break
done
SCRIPT

chmod +x "$D"/*.sh

# ═══════════════════════════════════════════════════════════════
#  SESSION FILE
# ═══════════════════════════════════════════════════════════════
SESSION="/tmp/kitty_claude_board.session"

# Get 4 most recently used project dirs for the AI tab
# Reads from the main kitty session file (saved every 30s) or falls back to recent dirs
PROJ_DIRS=()
if [ -f ~/.config/kitty/last_session.conf ]; then
    while IFS= read -r line; do
        [[ "$line" == cd\ * ]] && dir="${line#cd }" && [ -d "$dir" ] && PROJ_DIRS+=("$dir")
    done < ~/.config/kitty/last_session.conf
fi
# Pad with recent project dirs if we don't have enough
for d in $(stat --format '%Y %n' ~/projects/*/ 2>/dev/null | sort -rn | awk '{print $2}'); do
    [ ${#PROJ_DIRS[@]} -ge 4 ] && break
    # Skip if already in list
    skip=0; for p in "${PROJ_DIRS[@]}"; do [ "$p" = "$d" ] && skip=1; done
    [ "$skip" -eq 0 ] && [ -d "$d" ] && PROJ_DIRS+=("$d")
done
# Ensure we have at least 4
while [ ${#PROJ_DIRS[@]} -lt 4 ]; do PROJ_DIRS+=("$HOME"); done

printf '%s\n' \
  "new_tab [$(printf '\U000F011B') AI]" \
  "layout grid" \
  "cd ${PROJ_DIRS[0]}" \
  "launch" \
  "cd ${PROJ_DIRS[1]}" \
  "launch" \
  "cd ${PROJ_DIRS[2]}" \
  "launch" \
  "cd ${PROJ_DIRS[3]}" \
  "launch" \
  "new_tab [$(printf '\U000F0AB1') QA]" \
  "layout stack" \
  "launch /home/adj/.local/bin/qantum-tui" \
  "new_tab [$(printf '\U000F0E7E') SYS]" \
  "layout stack" \
  "launch btop" \
  "new_tab [$(printf '\U000F04CB') LOG]" \
  "layout horizontal" \
  "launch $D/logs_full.sh" \
  "launch $D/logs_warn.sh" \
  "new_tab [$(printf '\U000F06F3') NET]" \
  "layout horizontal" \
  "launch $D/net_conn.sh" \
  "launch $D/net_traffic.sh" \
  "new_tab [$(printf '\U000F0483') SEC]" \
  "layout horizontal" \
  "launch $D/sec_audit.sh" \
  "launch $D/sec_fw.sh" \
  "new_tab [$(printf '\U000F02A2') GIT]" \
  "layout horizontal" \
  "launch $D/git_status.sh" \
  "launch $D/git_log.sh" \
  "new_tab [$(printf '\U000F0868') DOC]" \
  "layout horizontal" \
  "launch $D/docker_ps.sh" \
  "launch $D/docker_img.sh" \
  "new_tab [$(printf '\U000F08AE') GPU]" \
  "layout horizontal" \
  "launch $D/gpu_stats.sh" \
  "launch $D/gpu_vram.sh" \
  "new_tab [$(printf '\U000F02CA') DSK]" \
  "layout horizontal" \
  "launch $D/disk_space.sh" \
  "launch $D/disk_io.sh" \
  "new_tab [$(printf '\U000F050F') TMP]" \
  "layout horizontal" \
  "launch $D/thermals.sh" \
  "launch $D/cpu_freq.sh" \
  "new_tab [$(printf '\U000F0A70') UPD]" \
  "layout horizontal" \
  "launch $D/updates.sh" \
  "launch $D/pacman_log.sh" \
  "new_tab [$(printf '\U000F018D') SH]" \
  "layout vertical" \
  "launch" \
  "launch" \
  > "$SESSION"

kitty --session "$SESSION" --override "startup_session=none" --title "Claude Board" &
disown

echo "Claude Board launched — 12 tabs"
