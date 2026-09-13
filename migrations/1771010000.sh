echo "Enable SDDM autologin with Hyprland session"

set -euo pipefail

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"

if is_secureblue; then
  # Autologin is deliberately left off on secureblue (see install/login/sddm.sh) -
  # writing it here would silently undo that hardening decision on every
  # existing secureblue install this migration reaches. secureblue also has
  # no sudo (only run0), so this used to just crash here instead.
  echo "secureblue: leaving autologin off (see install/login/sddm.sh)."
  exit 0
fi

autologin_user="${SUDO_USER:-$USER}"
if [[ "$autologin_user" == "root" ]] || [[ -z "$autologin_user" ]]; then
  autologin_user="$(logname 2>/dev/null || true)"
fi
if [[ "$autologin_user" == "root" ]] || [[ -z "$autologin_user" ]]; then
  autologin_user="$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd)"
fi

session_name="hyprland-uwsm"
if [[ ! -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]] && [[ -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
  session_name="hyprland"
fi

sudo mkdir -p /etc/sddm.conf.d
cat <<EOF | sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null
[Autologin]
User=$autologin_user
Session=$session_name
EOF

echo "Wrote /etc/sddm.conf.d/autologin.conf"
