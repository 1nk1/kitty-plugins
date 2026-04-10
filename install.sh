#!/bin/bash
# install.sh — Symlink kitty-plugins into ~/.config/kitty/
# Safe: backs up existing files before overwriting.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
KITTY_DIR="$HOME/.config/kitty"
SYSTEMD_DIR="$HOME/.config/systemd/user"
BACKUP_DIR="$KITTY_DIR/.backup-$(date +%Y%m%d-%H%M%S)"

GREEN='\033[38;2;80;250;123m'
YELLOW='\033[38;2;241;250;140m'
PURPLE='\033[38;2;189;147;249m'
RESET='\033[0m'

link_file() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
        echo -e "  ${YELLOW}backed up${RESET} $(basename "$dst")"
    fi
    ln -s "$src" "$dst"
    echo -e "  ${GREEN}linked${RESET} $(basename "$dst")"
}

echo -e "${PURPLE}Installing kitty-plugins...${RESET}"
mkdir -p "$KITTY_DIR" "$SYSTEMD_DIR"

# Config
link_file "$REPO_DIR/config/kitty.conf" "$KITTY_DIR/kitty.conf"

# Plugins
for f in "$REPO_DIR"/plugins/*.py; do
    link_file "$f" "$KITTY_DIR/$(basename "$f")"
done

# Scripts
for f in "$REPO_DIR"/scripts/*.sh; do
    link_file "$f" "$KITTY_DIR/$(basename "$f")"
done

# Systemd units
for f in "$REPO_DIR"/systemd/*; do
    link_file "$f" "$SYSTEMD_DIR/$(basename "$f")"
done

# Enable systemd timer
systemctl --user daemon-reload
systemctl --user enable --now kitty-session-save.timer
systemctl --user enable kitty-session-shutdown.service

echo -e "\n${GREEN}Done!${RESET} Reload kitty config: kitty @ load-config"
