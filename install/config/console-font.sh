#!/bin/bash
set -e

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

echo "[Omarchy] Setting up console font for TTY..."

if ! command -v setfont &>/dev/null; then
  echo "[Omarchy] Installing kbd package..."
  if is_ostree; then
    rpm-ostree install --idempotent -y kbd
  else
    sudo dnf install -y kbd
  fi
fi

echo "[Omarchy] Installing console-font.service..."
$ESC cp "$OMARCHY_PATH/config/systemd/system/console-font.service" /etc/systemd/system/
$ESC systemctl daemon-reload
$ESC systemctl enable console-font.service

# The TTY font is cosmetic, and loading it needs a real VT: it fails on a serial or virtio console
# (and in an ISO chroot there is no systemd to start it at all). Enabling it is what matters - the
# service runs on the installed system at boot - so a failed immediate start must not stop the
# install.
$ESC systemctl start console-font.service ||
  echo "[Omarchy] Console font could not be applied now; it will be set at boot."

echo "[Omarchy] Console font service installed and enabled."
