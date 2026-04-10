# TODO — Kitty Plugins Roadmap

## Bugs to Fix

- [ ] **Session restore: tabs open with wrong title** — `save_session.py` uses `tab.get("title")` which returns the shell's dynamic title (e.g. `zsh: /home/adj`) instead of the user-set tab name. Need to use `tab.get("title")` only when it matches user-set name, or find a way to distinguish user-set titles from auto-generated ones. Kitty `@ls` returns `title` (user-set) and the window's `title` separately — need to check which field carries the user-set name.

- [ ] **Session restore: new tab opens on startup even when session file exists** — When `startup_session` is set but the session file has issues (empty lines, encoding), Kitty may ignore it silently and open a default tab. Add validation to `save_session.py` output.

- [ ] **Context menu: right-click on Russian layout** — The mouse_map binding may not fire correctly when Cyrillic keyboard layout is active. Test and verify.

- [ ] **Session restore: layout not preserved** — Currently hardcodes `layout stack` for every tab. Should save and restore the actual layout (tall, grid, horizontal, etc.) per tab.

- [ ] **Session restore: multiple windows per tab not saved** — If a tab has splits (multiple windows), only the first window's cwd is saved. Need to iterate all windows and generate `launch` directives for each.

- [ ] **Systemd shutdown service: may not fire reliably** — `Before=logout.target` may not trigger on all shutdown paths (e.g. `systemctl poweroff`). Consider also hooking into `shutdown.target`.

## Enhancements

- [ ] **Session restore: save/restore scroll position** — Remember where user was scrolled in each tab's scrollback buffer.

- [ ] **Session restore: save running command** — If a tab was running `htop` or `claude`, try to restore that command on startup.

- [ ] **Tab bar: show git branch** — Display current git branch in the tab title or status bar for tabs that are in a git repo.

- [ ] **Tab bar: show active virtualenv** — Show Python venv name in tab bar when one is activated.

- [ ] **Context menu: add "Open in Yazi"** — Quick access to file manager from right-click menu.

- [ ] **Context menu: add "Split Vertical/Horizontal"** — Quick split from context menu.

- [ ] **Context menu: dynamic items based on selection** — If text is selected, show "Search Google", "Open URL", etc.

- [ ] **Hotkey overlay: make it searchable** — Press F1, then type to filter hotkeys (like VS Code command palette).

- [ ] **Claude Board: auto-reconnect** — If tmux session dies, Ctrl+Alt+0 should recreate it rather than erroring.

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
