#!/bin/bash
# Wrapper: grab mouse position, launch menu, then move it via xdotool
# Must use X11 backend so xdotool windowmove works on KDE Wayland

# 1. Kill previous instance
OLD_PID=$(cat /tmp/kitty_context_menu.pid 2>/dev/null)
[ -n "$OLD_PID" ] && kill "$OLD_PID" 2>/dev/null

# 2. Get mouse position NOW (before any window steals focus)
eval $(xdotool getmouselocation --shell 2>/dev/null)
# Sets X, Y, SCREEN, WINDOW

# 3. Launch GTK menu with X11 backend
GDK_BACKEND=x11 /usr/bin/python3 /home/adj/.config/kitty/context_menu.py &
MENU_PID=$!
echo "$MENU_PID" > /tmp/kitty_context_menu.pid

# 4. Wait for window to appear, then move it
for i in $(seq 1 20); do
    WID=$(xdotool search --pid "$MENU_PID" 2>/dev/null | head -1)
    if [ -n "$WID" ]; then
        xdotool windowmove "$WID" "$X" "$Y" 2>/dev/null
        xdotool windowactivate "$WID" 2>/dev/null
        exit 0
    fi
    sleep 0.05
done
