#!/usr/bin/env python3
"""
Save the current Kitty session to ~/.config/kitty/last_session.conf
so it can be restored on next launch via startup_session.

Captures: tab titles, working directories, tab order, active tab.
"""

import json
import os
import subprocess
import sys
import datetime

SESSION_FILE = os.path.expanduser("~/.config/kitty/last_session.conf")
LOG_FILE     = "/tmp/kitty_session_save.log"


def log(msg):
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"[{ts}] {msg}\n")


def find_kitty_socket():
    """
    Discover the kitty remote-control socket.  Tries, in order:
    1. KITTY_LISTEN_ON env var (set when we're already inside kitty)
    2. Child-process environ scan (KITTY_LISTEN_ON in shell children)
    3. /proc/net/unix scan for abstract sockets named @kitty-<PID>
    """
    # 1. Already inside kitty
    if "KITTY_LISTEN_ON" in os.environ:
        return os.environ["KITTY_LISTEN_ON"]

    # 2. Scan child processes of each kitty PID
    pids = subprocess.run(["pgrep", "-x", "kitty"],
                          capture_output=True, text=True).stdout.strip().splitlines()
    for pid in pids:
        try:
            with open(f"/proc/{pid}/environ", "rb") as f:
                env_data = f.read().decode("utf-8", errors="replace")
            for item in env_data.split("\x00"):
                if item.startswith("KITTY_LISTEN_ON="):
                    return item.split("=", 1)[1]
        except (PermissionError, FileNotFoundError, ValueError):
            pass

        # Also check children of this kitty PID
        children = subprocess.run(["pgrep", "-P", pid],
                                  capture_output=True, text=True).stdout.strip().splitlines()
        for cpid in children:
            try:
                with open(f"/proc/{cpid}/environ", "rb") as f:
                    env_data = f.read().decode("utf-8", errors="replace")
                for item in env_data.split("\x00"):
                    if item.startswith("KITTY_LISTEN_ON="):
                        return item.split("=", 1)[1]
            except (PermissionError, FileNotFoundError, ValueError):
                pass

    # 3. Parse /proc/net/unix for abstract sockets named @kitty-<digits>
    try:
        with open("/proc/net/unix") as f:
            for line in f:
                parts = line.strip().split()
                if parts:
                    name = parts[-1]
                    if name.startswith("@kitty-") and name[7:].isdigit():
                        return f"unix:{name}"
    except (PermissionError, FileNotFoundError):
        pass

    return None


def main():
    socket = find_kitty_socket()
    if not socket:
        log("No running kitty instance found (KITTY_LISTEN_ON not set).")
        sys.exit(0)   # exit 0 so the timer doesn't spam failures when kitty is closed

    cmd = ["kitty", "@", f"--to={socket}", "ls"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
    except Exception as e:
        log(f"ERROR running kitty @ ls: {e}")
        sys.exit(1)

    if result.returncode != 0:
        log(f"kitty @ ls failed (rc={result.returncode}): {result.stderr.strip()}")
        sys.exit(1)

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        log(f"JSON parse error: {e}")
        sys.exit(1)

    if not data:
        log("No OS windows found.")
        sys.exit(0)

    # Use the focused OS window; fall back to the first one
    focused_win = next((w for w in data if w.get("is_focused")), data[0])
    tabs = focused_win.get("tabs", [])

    if not tabs:
        log("No tabs in focused window.")
        sys.exit(0)

    lines = []

    for tab in tabs:
        title = (tab.get("title") or "shell").strip()
        is_active = tab.get("is_active", False)

        # Find the cwd from the focused/active window inside this tab
        windows = tab.get("windows", [])
        cwd = os.path.expanduser("~")
        for win in windows:
            w_cwd = win.get("cwd", "")
            if w_cwd and os.path.isdir(w_cwd):
                cwd = w_cwd
                if win.get("is_focused"):
                    break  # prefer focused window's cwd

        lines.append(f"new_tab {title}")
        lines.append("layout stack")
        lines.append(f"cd {cwd}")
        lines.append("launch")          # required: opens the shell in cwd
        if is_active:
            lines.append("focus_tab")   # mark this tab as the active one

    content = "\n".join(lines) + "\n"
    with open(SESSION_FILE, "w") as f:
        f.write(content)

    tab_count = sum(1 for l in lines if l.startswith("new_tab"))
    log(f"Saved {tab_count} tabs → {SESSION_FILE}")
    print(f"Session saved: {tab_count} tabs")


if __name__ == "__main__":
    main()
