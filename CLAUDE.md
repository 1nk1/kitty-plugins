# CLAUDE.md — kitty-plugins

## Project

Custom Kitty terminal plugins and configuration for Arch Linux / KDE Wayland.
Repo: `1nk1/kitty-plugins`

## Agent

Use `kitty_terminal_wizard` (Neon / Yara Okonkwo) for all Kitty work.

## Stack

- **Terminal:** Kitty 0.46.2+
- **OS:** Arch Linux, KDE Plasma 6, Wayland
- **Shell:** zsh
- **Font:** JetBrainsMono Nerd Font Mono
- **Theme:** Dracula Pro
- **GPU:** AMD RX 7900 XT (radeonsi)
- **Python:** /usr/bin/python3 (system) — NEVER use `#!/usr/bin/env python3` in shims (pyenv conflict)

## Structure

```
config/kitty.conf           — Main config (symlinked to ~/.config/kitty/kitty.conf)
plugins/tab_bar.py          — Custom tab bar: powerline + CPU/RAM/clock status
plugins/context_menu.py     — Right-click TUI context menu (overlay kitten)
plugins/save_session.py     — Session save/restore (tabs, cwds, names, order)
plugins/magic_dust.py       — Particle effects (sand/fireworks/matrix)
plugins/weather.py          — Ambient overlays (snow/rain)
scripts/claude_board.sh     — 4-window tmux Claude workspace
scripts/show_hotkeys.sh     — F1 hotkey reference overlay
systemd/                    — Timer + services for auto session save
install.sh                  — Symlink installer
```

## Rules

- All Python scripts MUST use `#!/usr/bin/python3` (not `#!/usr/bin/env python3`)
- Colors: Dracula Pro palette only (#282A36, #BD93F9, #F8F8F2, #44475A, #FF5555, #50FA7B, #8BE9FD, #FFB86C, #FF79C6, #F1FA8C, #6272A4)
- Remote control: `kitty @` commands, socket at `unix:@kitty-{pid}`
- Session file format: `new_tab TITLE` → `layout <name>` → `cd /path` → `launch` → optional `focus_tab`
- Tab bar: `tab_bar_style custom` with `tab_bar.py`
- Keybindings must support both Latin AND Cyrillic (Russian ЙЦУКЕН) layouts
- Systemd units go in `~/.config/systemd/user/`
- Test in Kitty overlay mode (`--type=overlay`) before committing UI changes
