#!/bin/bash

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

# Ensure the Fedora login path is SDDM-only.
$ESC systemctl disable --now omarchy-seamless-login.service >/dev/null 2>&1 || true
$ESC rm -f /etc/systemd/system/omarchy-seamless-login.service
$ESC rm -f /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf
$ESC systemctl unmask plymouth-quit-wait.service >/dev/null 2>&1 || true
$ESC systemctl daemon-reload

# Undo tty1 changes from legacy seamless-login setups.
$ESC systemctl enable getty@tty1.service >/dev/null 2>&1 || true

$ESC mkdir -p /etc/sddm.conf.d

if is_secureblue; then
  # Two things deliberately skipped here on secureblue, both conservative
  # defaults rather than settled decisions:
  #   - Autologin: secureblue was chosen specifically for its hardening: an
  #     unattended sudo/root-analog rule was already ripped out for the same
  #     reason (see install/preflight/passwordless-installer.sh). Silently
  #     enabling autologin here would be the same category of regression.
  #     Revisit explicitly if wanted - it is not a technical blocker.
  #   - The "omarchy" SDDM theme: install/config/system-files.sh's
  #     /usr/share/sddm/themes install is out of scope for v1 (read-only
  #     /usr on a booted OSTree deployment - see that script's secureblue
  #     branch). Leaving SDDM on its stock theme means it actually renders,
  #     instead of pointing it at a `Current=` theme that was never
  #     installed.
  echo "[sddm] secureblue: leaving autologin off and SDDM on its stock theme (see comments in this script)."
else
  AUTOLOGIN_USER="${SUDO_USER:-$USER}"
  if [[ "$AUTOLOGIN_USER" == "root" ]] || [[ -z "$AUTOLOGIN_USER" ]]; then
    AUTOLOGIN_USER="$(logname 2>/dev/null || true)"
  fi
  if [[ "$AUTOLOGIN_USER" == "root" ]] || [[ -z "$AUTOLOGIN_USER" ]]; then
    AUTOLOGIN_USER="$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd)"
  fi

  SESSION_NAME="hyprland-uwsm"
  if [[ ! -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]] && [[ -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
    SESSION_NAME="hyprland"
  fi

  cat <<EOF | $ESC tee /etc/sddm.conf.d/10-omarchy-autologin.conf >/dev/null
[Autologin]
User=$AUTOLOGIN_USER
Session=$SESSION_NAME
EOF

  cat <<EOF | $ESC tee /etc/sddm.conf.d/theme.conf >/dev/null
[Theme]
Current=omarchy
EOF
fi

$ESC systemctl set-default graphical.target

# Prevent password-based SDDM logins from creating an encrypted login keyring
# (which conflicts with the passwordless Default_keyring used for auto-unlock)
$ESC sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
$ESC sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm

# Don't use chrootable here as --now will cause issues for manual installs
$ESC systemctl enable sddm.service
