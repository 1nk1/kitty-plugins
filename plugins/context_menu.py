#!/usr/bin/python3
"""
Kitty right-click context menu — native GTK4 popup at mouse cursor.
Works on KDE Wayland. Appears as a floating window at cursor position.
Click item to execute, click outside or Escape to dismiss.
Single instance — kills previous menu before opening new one.
"""

import subprocess
import os
import signal

# ── Single instance: kill previous menu ──────────────────────
_PIDFILE = '/tmp/kitty_context_menu.pid'

def _kill_previous():
    try:
        with open(_PIDFILE) as f:
            old_pid = int(f.read().strip())
        os.kill(old_pid, signal.SIGTERM)
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        pass

def _write_pid():
    with open(_PIDFILE, 'w') as f:
        f.write(str(os.getpid()))

_kill_previous()
_write_pid()

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib


# ── Dracula Pro palette ──────────────────────────────────────
CSS = """
window.context-menu {
    background-color: #282A36;
    border: 2px solid #BD93F9;
    border-radius: 10px;
    padding: 4px 0;
}
window.context-menu .title-label {
    color: #FFB86C;
    font-weight: bold;
    font-size: 13px;
    padding: 6px 16px 4px 16px;
}
window.context-menu .menu-row {
    padding: 6px 16px;
    border-radius: 6px;
    margin: 1px 6px;
    transition: background-color 100ms;
}
window.context-menu .menu-row:hover {
    background-color: #44475A;
}
window.context-menu .menu-row .icon-label {
    color: #BD93F9;
    font-size: 18px;
    min-width: 28px;
}
window.context-menu .menu-row:hover .icon-label {
    color: #FF79C6;
}
window.context-menu .menu-row .text-label {
    color: #F8F8F2;
    font-size: 14px;
}
window.context-menu .menu-row:hover .text-label {
    color: #BD93F9;
    font-weight: bold;
}
window.context-menu .sep {
    min-height: 1px;
    background-color: #6272A4;
    margin: 3px 14px;
    opacity: 0.35;
}
"""

def find_kitty_socket():
    try:
        r = subprocess.run(['pgrep', '-x', 'kitty'],
                           capture_output=True, text=True, timeout=2)
        for pid in r.stdout.strip().split('\n'):
            pid = pid.strip()
            if pid:
                return f'unix:@kitty-{pid}'
    except Exception:
        pass
    return None


def kcmd(*args):
    sock = find_kitty_socket()
    if not sock:
        return
    subprocess.Popen(['kitty', '@', '--to', sock] + list(args),
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def do_copy():
    sock = find_kitty_socket()
    if not sock:
        return
    try:
        r = subprocess.run(
            ['kitty', '@', '--to', sock, 'get-text', '--extent=selection'],
            capture_output=True, text=True, timeout=3)
        if r.stdout.strip():
            subprocess.run(['wl-copy'], input=r.stdout, text=True,
                           capture_output=True, timeout=3)
    except Exception:
        pass


# (icon, label, callback) or None = separator
MENU = [
    ('\U000F0190', 'Copy',            do_copy),
    ('\U000F0192', 'Paste',           lambda: kcmd('send-key', 'ctrl+shift+v')),
    ('\U000F0193', 'Paste Sel',       lambda: kcmd('paste-from-selection')),
    None,
    ('\U000F0425', 'New Tab',         lambda: kcmd('launch', '--type=tab', '--cwd=current')),
    ('\U000F0425', 'New Window',      lambda: kcmd('launch', '--cwd=current')),
    ('\U000F0156', 'Close Tab',       lambda: kcmd('close-tab')),
    None,
    ('\U000F0485', 'Split V',         lambda: kcmd('launch', '--cwd=current', '--location=vsplit')),
    ('\U000F0484', 'Split H',         lambda: kcmd('launch', '--cwd=current', '--location=hsplit')),
    None,
    ('\U000F005D', 'Scroll Up',       lambda: kcmd('scroll-window', '3')),
    ('\U000F005E', 'Scroll Down',     lambda: kcmd('scroll-window', '-3')),
    ('\U000F005C', 'Top',             lambda: kcmd('scroll-window', 'start')),
    None,
    ('\U000F0234', 'Clear',           lambda: kcmd('send-text', 'clear\n')),
    ('\U000F0453', 'Reload Cfg',      lambda: kcmd('load-config')),
    None,
    ('\U000F024B', 'Yazi',            lambda: kcmd('launch', '--cwd=current', '--type=window', 'yazi')),
]


class MenuWindow(Gtk.ApplicationWindow):

    def __init__(self, app):
        super().__init__(application=app)
        self.add_css_class('context-menu')
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(260, -1)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # Title
        title = Gtk.Label(label='Context Menu')
        title.add_css_class('title-label')
        title.set_halign(Gtk.Align.START)
        vbox.append(title)

        # Items
        for item in MENU:
            if item is None:
                sep = Gtk.Box()
                sep.add_css_class('sep')
                vbox.append(sep)
                continue

            icon_str, label_str, cb = item
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            row.add_css_class('menu-row')

            icon = Gtk.Label(label=icon_str)
            icon.add_css_class('icon-label')
            icon.set_halign(Gtk.Align.CENTER)
            icon.set_size_request(22, -1)

            label = Gtk.Label(label=label_str)
            label.add_css_class('text-label')
            label.set_halign(Gtk.Align.START)
            label.set_hexpand(True)

            row.append(icon)
            row.append(label)

            # Mouse click handler
            gesture = Gtk.GestureClick()
            gesture.connect('released', self._on_item_click, cb)
            row.add_controller(gesture)

            vbox.append(row)

        self.set_child(vbox)

        # Escape to close
        key_ctl = Gtk.EventControllerKey()
        key_ctl.connect('key-pressed', self._on_key)
        self.add_controller(key_ctl)

        # Close when clicking outside (focus loss)
        self._alive = True
        focus_ctl = Gtk.EventControllerFocus()
        focus_ctl.connect('leave', self._on_focus_out)
        self.add_controller(focus_ctl)

        # Safety timeout — close after 15s
        GLib.timeout_add(15000, self._timeout)

    def _on_item_click(self, gesture, n_press, x, y, callback):
        self._alive = False
        self.close()
        # Run callback after window closes
        GLib.timeout_add(50, lambda: (callback(), False)[-1])

    def _on_key(self, ctl, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self._alive = False
            self.close()
            return True
        return False

    def _on_focus_out(self, ctl):
        if self._alive:
            GLib.timeout_add(150, self._maybe_close)

    def _maybe_close(self):
        if self._alive:
            self._alive = False
            self.close()
        return False

    def _timeout(self):
        if self._alive:
            self._alive = False
            self.close()
        return False


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='dev.kitty.context.menu')

    def do_activate(self):
        # Load CSS
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        win = MenuWindow(self)
        win.present()


if __name__ == '__main__':
    App().run([])
