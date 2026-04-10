#!/usr/bin/python3
"""
Compact right-click context menu for Kitty.
Runs as --type=overlay kitten.
Appears at the click position; click outside or Esc/q closes it.

Usage: context_menu.py [mouse_x] [mouse_y]   (0-indexed cell coords from kitty)
"""

import os
import select
import subprocess
import sys
import termios
import tty

# ---------------------------------------------------------------------------
# Remote-control helpers
# ---------------------------------------------------------------------------

def krc(*args):
    subprocess.run(["kitty", "@"] + list(args), capture_output=True, text=True)


def krc_parent(*args):
    krc(*args, "--match=recent:1")


def do_copy():
    r = subprocess.run(
        ["kitty", "@", "get-text", "--match=recent:1", "--extent=selection"],
        capture_output=True, text=True,
    )
    if r.stdout.strip():
        for cmd in (["wl-copy"], ["xclip", "-selection", "clipboard"]):
            try:
                subprocess.run(cmd, input=r.stdout, text=True,
                               capture_output=True, check=True)
                return
            except (FileNotFoundError, subprocess.CalledProcessError):
                continue


# ---------------------------------------------------------------------------
# Menu definition  (None = separator)
# ---------------------------------------------------------------------------

MENU = [
    ("  Copy",            do_copy),
    ("  Paste",           lambda: krc_parent("paste-from-clipboard")),
    ("  Paste Selection", lambda: krc_parent("paste-from-selection")),
    None,
    ("  New Tab",         lambda: krc("new-window", "--new-tab", "--cwd=current")),
    ("  New Window",      lambda: krc("new-window", "--cwd=current", "--match=recent:1")),
    ("  Close Tab",       lambda: krc_parent("close-tab")),
    None,
    ("  Scroll Up",       lambda: krc_parent("scroll-window", "scroll-up", "3")),
    ("  Scroll Down",     lambda: krc_parent("scroll-window", "scroll-down", "3")),
    ("  Scroll to Top",   lambda: krc_parent("scroll-window", "start")),
    None,
    ("  Clear",           lambda: krc_parent("send-text", "--", "clear\n")),
    ("  Reload Config",   lambda: krc("load-config")),
]

# ---------------------------------------------------------------------------
# ANSI helpers
# ---------------------------------------------------------------------------

ESC = "\x1b"


def cup(row, col):
    return f"{ESC}[{row};{col}H"


def rgb_fg(r, g, b):
    return f"{ESC}[38;2;{r};{g};{b}m"


def rgb_bg(r, g, b):
    return f"{ESC}[48;2;{r};{g};{b}m"


RESET = ESC + "[0m"
BOLD  = ESC + "[1m"
DIM   = ESC + "[2m"

# Dracula palette
C_BOX_BG = (40,  42,  54)     # #282A36  box interior
C_BORDER = (189, 147, 249)    # #BD93F9  purple border
C_SEL_BG = (68,  71,  90)     # #44475A  selected bg
C_SEL_FG = (189, 147, 249)    # #BD93F9  selected fg
C_NORMAL = (248, 248, 242)    # #F8F8F2  normal text
C_TITLE  = (255, 184, 108)    # #FFB86C  orange title
C_SEP    = (98,  114, 164)    # #6272A4  dim
C_HINT   = (98,  114, 164)

INNER_W  = 24   # content width inside border chars
BOX_W    = INNER_W + 2  # total box width incl. borders


# ---------------------------------------------------------------------------
# Terminal size
# ---------------------------------------------------------------------------

def get_term_size():
    import struct, fcntl
    try:
        result = fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, b"0000")
        rows, cols = struct.unpack("hh", result)
        return max(rows, 10), max(cols, 40)
    except Exception:
        return 24, 80


# ---------------------------------------------------------------------------
# Layout — calculated from click position
# ---------------------------------------------------------------------------

def calc_box_pos(click_col, click_row, term_rows, term_cols):
    """
    Place box so it appears near the click position.
    Shift left/up if it would go off-screen.
    """
    box_height = 2 + 1 + len(MENU) + 1  # top border + title + title-sep + items + bottom border
    # Try to appear just below and at the click column
    left = click_col
    top  = click_row

    # Clamp right edge
    if left + BOX_W > term_cols:
        left = max(1, term_cols - BOX_W)

    # Clamp bottom edge
    if top + box_height + 1 > term_rows:
        top = max(1, term_rows - box_height - 1)

    return left, top


def box_row_at(box_top, content_row):
    """content_row 0=title, 1=title-sep, 2..=items -> terminal row."""
    return box_top + 1 + content_row


def build_item_rows(box_top):
    mapping = {}
    content_row = 2   # 0=title, 1=sep, 2..=items
    for idx, item in enumerate(MENU):
        tr = box_row_at(box_top, content_row)
        if item is not None:
            mapping[tr] = idx
        content_row += 1
    return mapping


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def render(sel_idx, box_left, box_top, out):
    buf = []

    bdr = rgb_fg(*C_BORDER) + rgb_bg(*C_BOX_BG)
    box = rgb_bg(*C_BOX_BG)

    # Top border
    buf.append(cup(box_top, box_left))
    buf.append(bdr + "\u256d" + "\u2500" * INNER_W + "\u256e" + RESET)

    # Title
    title_text = "  Context Menu"
    buf.append(cup(box_top + 1, box_left))
    buf.append(bdr + "\u2502" + RESET)
    buf.append(box + rgb_fg(*C_TITLE) + BOLD)
    buf.append(title_text.ljust(INNER_W))
    buf.append(RESET + bdr + "\u2502" + RESET)

    # Title separator
    buf.append(cup(box_top + 2, box_left))
    buf.append(bdr + "\u251c" + "\u2500" * INNER_W + "\u2524" + RESET)

    # Items
    content_row = 2
    for idx, item in enumerate(MENU):
        tr = box_row_at(box_top, content_row)
        buf.append(cup(tr, box_left))
        if item is None:
            buf.append(bdr + "\u2502" + RESET)
            buf.append(rgb_fg(*C_SEP) + DIM + "\u2500" * INNER_W + RESET)
            buf.append(bdr + "\u2502" + RESET)
        else:
            label, _ = item
            is_sel = (idx == sel_idx)
            buf.append(bdr + "\u2502" + RESET)
            if is_sel:
                display = ("\u276f " + label.lstrip())[:INNER_W].ljust(INNER_W)
                buf.append(rgb_bg(*C_SEL_BG) + rgb_fg(*C_SEL_FG) + BOLD + display + RESET)
            else:
                display = label[:INNER_W].ljust(INNER_W)
                buf.append(box + rgb_fg(*C_NORMAL) + display + RESET)
            buf.append(bdr + "\u2502" + RESET)
        content_row += 1

    # Bottom border
    bottom_tr = box_row_at(box_top, content_row)
    buf.append(cup(bottom_tr, box_left))
    buf.append(bdr + "\u2570" + "\u2500" * INNER_W + "\u256f" + RESET)

    # Hint
    buf.append(cup(bottom_tr + 1, box_left))
    buf.append(rgb_fg(*C_HINT) + DIM + "  \u2191\u2193 Enter  Esc/click outside" + RESET)

    buf.append(ESC + "[?25l")  # hide cursor
    buf.append(RESET)

    out.write("".join(buf))
    out.flush()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

def read_key(fd):
    first = os.read(fd, 1)
    if first != b"\x1b":
        return first.decode("utf-8", errors="replace")

    if not select.select([fd], [], [], 0.05)[0]:
        return "ESC"

    second = os.read(fd, 1)
    if second == b"[":
        seq = b""
        while True:
            if not select.select([fd], [], [], 0.1)[0]:
                break
            ch = os.read(fd, 1)
            seq += ch
            if 0x40 <= ch[0] <= 0x7E:
                break
        return "\x1b[" + seq.decode("utf-8", errors="replace")
    elif second == b"O":
        if select.select([fd], [], [], 0.05)[0]:
            ch = os.read(fd, 1)
            return "\x1bO" + ch.decode("utf-8", errors="replace")
        return "\x1bO"
    else:
        return "\x1b" + second.decode("utf-8", errors="replace")


def parse_sgr_mouse(seq):
    if not seq.startswith("\x1b[<"):
        return None
    body = seq[3:]
    if not body:
        return None
    pressed = body.endswith("M")
    if not pressed and not body.endswith("m"):
        return None
    body = body[:-1]
    parts = body.split(";")
    if len(parts) != 3:
        return None
    try:
        return int(parts[0]), int(parts[1]), int(parts[2]), pressed
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

def selectable_indices():
    return [i for i, item in enumerate(MENU) if item is not None]


def next_sel(current):
    idxs = selectable_indices()
    for i in idxs:
        if i > current:
            return i
    return current


def prev_sel(current):
    idxs = selectable_indices()
    for i in reversed(idxs):
        if i < current:
            return i
    return current


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    # Get click position from kitty's {mouse_x} {mouse_y} template vars (0-indexed cells)
    try:
        click_col = int(sys.argv[1]) + 1  # convert to 1-indexed
        click_row = int(sys.argv[2]) + 1
    except (IndexError, ValueError):
        click_col, click_row = 2, 2

    out = sys.stdout
    fd  = sys.stdin.fileno()
    old = termios.tcgetattr(fd)

    term_rows, term_cols = get_term_size()
    box_left, box_top = calc_box_pos(click_col, click_row, term_rows, term_cols)

    item_rows   = build_item_rows(box_top)
    num_content = 2 + len(MENU)
    box_bottom  = box_row_at(box_top, num_content)

    sel_idx = selectable_indices()[0]

    try:
        out.write(ESC + "[?1049h")                    # alt screen (saves/restores terminal)
        out.write(ESC + "[?1000h" + ESC + "[?1006h")  # SGR mouse on
        out.flush()

        tty.setraw(fd)
        render(sel_idx, box_left, box_top, out)

        action_fn = None

        while True:
            key = read_key(fd)

            # Mouse
            if key.startswith("\x1b[<"):
                parsed = parse_sgr_mouse(key)
                if parsed:
                    btn, col, row, pressed = parsed
                    if pressed and btn == 0:
                        in_box = (box_left <= col <= box_left + BOX_W - 1 and
                                  box_top  <= row <= box_bottom)
                        if in_box and row in item_rows:
                            sel_idx = item_rows[row]
                            render(sel_idx, box_left, box_top, out)
                            action_fn = MENU[sel_idx][1]
                            break
                        elif not in_box:
                            break
                continue

            # Keyboard
            if key in ("\x1b[A", "\x1bOA", "k"):
                sel_idx = prev_sel(sel_idx)
                render(sel_idx, box_left, box_top, out)
            elif key in ("\x1b[B", "\x1bOB", "j"):
                sel_idx = next_sel(sel_idx)
                render(sel_idx, box_left, box_top, out)
            elif key in ("\r", "\n"):
                action_fn = MENU[sel_idx][1]
                break
            elif key in ("ESC", "\x1b", "q", "Q"):
                break

    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        out.write(ESC + "[?1006l" + ESC + "[?1000l")
        out.write(ESC + "[?25h")
        out.write(ESC + "[?1049l")
        out.flush()

    if action_fn:
        action_fn()


if __name__ == "__main__":
    main()
