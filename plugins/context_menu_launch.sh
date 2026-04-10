#!/bin/bash
# Launch context menu at mouse cursor position.
# Uses GDK_BACKEND=x11 so xdotool can find and move the window.

# Kill previous instance
OLD_PID=$(cat /tmp/kitty_context_menu.pid 2>/dev/null)
[ -n "$OLD_PID" ] && kill "$OLD_PID" 2>/dev/null
sleep 0.05

# Get mouse position
eval $(xdotool getmouselocation --shell 2>/dev/null)

# Launch menu (stays in foreground for the background python process)
GDK_BACKEND=x11 /usr/bin/python3 /home/adj/.config/kitty/context_menu.py &
MENU_PID=$!
echo "$MENU_PID" > /tmp/kitty_context_menu.pid

# Wait for X11 window to appear, then move it
(
    for i in $(seq 1 40); do
        WID=$(xdotool search --pid "$MENU_PID" 2>/dev/null | head -1)
        if [ -n "$WID" ]; then
            xdotool windowmove "$WID" "${X:-100}" "${Y:-100}" 2>/dev/null
            xdotool windowactivate "$WID" 2>/dev/null
            xdotool windowfocus "$WID" 2>/dev/null
            exit 0
        fi
        sleep 0.025
    done
) &

# Don't wait — exit immediately so kitty's --type=background doesn't block
exit 0
