# kitty-plugins

Custom Kitty terminal configuration, plugins, and integrations for Arch Linux / KDE Wayland.

## Structure

```
kitty-plugins/
├── config/
│   └── kitty.conf              # Main Kitty config (Dracula Pro, Nerd Fonts)
├── plugins/
│   ├── tab_bar.py              # Custom tab bar: powerline + CPU/RAM/clock
│   ├── context_menu.py         # Right-click TUI context menu (overlay)
│   ├── save_session.py         # Session save/restore (tab names, cwd, order)
│   ├── magic_dust.py           # Particle effects (sand/fireworks/matrix)
│   └── weather.py              # Ambient overlays (snow/rain)
├── scripts/
│   ├── claude_board.sh         # 4-window tmux Claude Code workspace
│   └── show_hotkeys.sh         # F1 hotkey reference overlay
├── systemd/
│   ├── kitty-session-save.timer    # 30s periodic session save
│   ├── kitty-session-save.service  # Session save oneshot
│   └── kitty-session-shutdown.service  # Save before logout/reboot
├── install.sh                  # Symlink installer
└── TODO.md                     # Roadmap and feature wishlist
```

## Install

```bash
./install.sh
```

Creates symlinks from `~/.config/kitty/` to this repo. Does not overwrite — backs up existing files.

## Dependencies

```bash
sudo pacman -S ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-mono
sudo pacman -S python-gobject gtk4 gtk4-layer-shell  # for weather/magic_dust
sudo pacman -S wl-clipboard  # for context menu copy
```

## Session Restore

Systemd timer saves session every 30s. On Kitty startup, `startup_session` loads the last saved state.

Saves: tab names, working directories, tab order, active tab.

## Keybindings

Press **F1** in Kitty for the full hotkey reference.
