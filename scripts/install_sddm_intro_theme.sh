#!/usr/bin/env bash
set -e

THEME_NAME="evangelion-intro"
ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$ACTUAL_USER" 2>/dev/null | cut -d: -f6)
USER_HOME="${USER_HOME:-$HOME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -d "${REPO_DIR}/sddm/${THEME_NAME}" ]; then
    THEME_SRC="${REPO_DIR}/sddm/${THEME_NAME}"
else
    THEME_SRC="${USER_HOME}/.local/share/sddm/themes/${THEME_NAME}"
fi
THEME_DEST="/usr/share/sddm/themes/${THEME_NAME}"

echo "=== Installing Evangelion Intro (Sync Loop) SDDM Theme ==="

if [ "$EUID" -ne 0 ]; then
    echo "This script requires sudo privileges to install to /usr/share/sddm/themes."
    echo "Running sudo cp..."
    sudo mkdir -p "$THEME_DEST"
    sudo cp -r "$THEME_SRC"/* "$THEME_DEST"/
    sudo chmod -R a+rX "$THEME_DEST"
    echo "Configuring /etc/sddm.conf.d/theme.conf..."
    sudo mkdir -p /etc/sddm.conf.d/
    echo -e "[Theme]\nCurrent=${THEME_NAME}" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null
else
    mkdir -p "$THEME_DEST"
    cp -r "$THEME_SRC"/* "$THEME_DEST"/
    chmod -R a+rX "$THEME_DEST"
    mkdir -p /etc/sddm.conf.d/
    echo -e "[Theme]\nCurrent=${THEME_NAME}" > /etc/sddm.conf.d/theme.conf
fi

echo "✓ Evangelion Intro SDDM Theme installed and set as active in /etc/sddm.conf.d/theme.conf!"
echo "You can test it anytime with: sddm-greeter-qt6 --test-mode --theme $THEME_DEST"
