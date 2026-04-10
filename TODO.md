# TODO — Kitty Plugins Roadmap

## Bugs to Fix

- [ ] **Context menu: full-screen overlay instead of popup** — Right-click opens a full-screen terminal overlay with the menu in the corner. Should behave like a native popup: compact floating box at cursor position, mouse-clickable items, auto-close on outside click. Current `--type=overlay` takes over entire terminal. Needs either: (a) GTK4 popup window approach (like magic_dust.py) positioned at cursor coords, or (b) fix the TUI overlay to actually handle mouse clicks on items. Mouse SGR tracking seems broken in overlay mode.

- [x] ~~Session restore: tabs open with wrong title~~ — NOT A BUG. `tab["title"]` in `kitty @ ls` IS the user-set title. Window-level `title` is the dynamic one.

- [x] ~~Session restore: new tab opens on startup~~ — FIXED. Added validation to save_session.py.

- [x] ~~Context menu: right-click on Russian layout~~ — NOT A BUG. Mouse buttons are layout-independent.

- [x] ~~Session restore: layout not preserved~~ — FIXED. Now saves actual layout per tab.

- [x] ~~Session restore: multiple windows per tab~~ — FIXED. Iterates all windows.

- [x] ~~Systemd shutdown service unreliable~~ — FIXED. RemainAfterExit + ExecStop pattern.

## Enhancements

- [ ] **Session restore: save/restore scroll position** — Remember where user was scrolled in each tab's scrollback buffer.

- [ ] **Session restore: save running command** — If a tab was running `htop` or `claude`, try to restore that command on startup.

- [ ] **Tab bar: show git branch** — Display current git branch in the tab title or status bar for tabs that are in a git repo.

- [ ] **Tab bar: show active virtualenv** — Show Python venv name in tab bar when one is activated.

- [ ] **Context menu: add "Open in Yazi"** — Quick access to file manager from right-click menu.

- [ ] **Context menu: add "Split Vertical/Horizontal"** — Quick split from context menu.

- [ ] **Context menu: dynamic items based on selection** — If text is selected, show "Search Google", "Open URL", etc.

- [ ] **Hotkey overlay: make it searchable** — Press F1, then type to filter hotkeys (like VS Code command palette).

- [x] ~~Claude Board: rewrite as native Kitty~~ — DONE. Replaced tmux with kitty --session file. Opens new OS window with 4 tabs: grid claude, btop, logs, shell.

## New Plugins Wishlist

- [ ] **SSH session manager** — Quick connect to saved SSH hosts from a picker menu.

- [ ] **Snippet manager** — Store and quickly paste code snippets / commands from a searchable overlay.

- [ ] **Notification integration** — Show desktop notifications when a long-running command finishes in a background tab.

- [ ] **Theme switcher** — Toggle between Dracula Pro variants (or other themes) from a picker.

- [ ] **Tab grouping / workspaces** — Save and restore named workspace presets (e.g. "trading", "security", "dev").

- [ ] **Image preview in terminal** — Auto-preview images when hovering file paths (using icat kitten).

## Infrastructure

- [ ] **Automated tests** — Test session save/restore round-trip with mock `kitty @ ls` output.

- [ ] **CI: lint Python** — Add ruff/flake8 check in GitHub Actions.

- [ ] **Version pinning** — Track minimum Kitty version required for each feature.

- [ ] **Uninstall script** — Remove symlinks and restore backups.
