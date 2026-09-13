# Enable services only. Installs are followed by reboot, so don't start/reload
# daemons mid-install. UFW and hardware-gated services stay in their own scripts.
source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/distro-secureblue.sh"

# secureblue masks several stock daemons outright for hardening (cups,
# avahi-daemon, thermald, ...) rather than just leaving them disabled -
# enabling a masked unit errors, and since every install/config/*.sh step
# runs with set -e, that aborted every enable after the first masked one
# hit. Skip a masked unit with a note instead of fighting the mask; this
# self-adapts to whichever units a given secureblue image masks, rather
# than hardcoding one distro's mask list here.
enable_service() {
  if [[ "$(systemctl is-enabled "$1" 2>/dev/null)" == masked ]]; then
    echo "[enable-services] $1 is masked - leaving it alone"
    return 0
  fi
  systemctl enable "$1"
}

enable_service cups.service
enable_service cups-browsed.service
enable_service avahi-daemon.service
# docker.socket NOT enabled on any OSTree/atomic Fedora target (secureblue
# and plain atomic alike): these images ship podman instead, Docker is
# deliberately not installed at all there (see
# omarchy-base.packages.secureblue's Containers section; confirmed
# empirically - no docker.socket unit exists on plain atomic Fedora either).
is_ostree || enable_service docker.socket
enable_service systemd-resolved.service
enable_service NetworkManager.service
# Don't let network-online.target (pulled in by cups-browsed) hold up
# graphical.target waiting for DHCP/Wi-Fi association. Nothing in the session
# needs to block on the network. Mirrors the systemd-networkd-wait-online mask
# in install/hardware/network.sh.
systemctl mask NetworkManager-wait-online.service
# power-profiles-daemon.service NOT enabled on any OSTree/atomic Fedora
# target: these images ship tuned-ppd instead (same ppd-service D-Bus
# interface, hard-conflicts with power-profiles-daemon - see
# omarchy-base.packages.secureblue), and its service is already enabled by
# default (confirmed empirically on plain atomic Fedora too).
is_ostree || enable_service power-profiles-daemon.service
enable_service sddm.service
# Kill one runaway app scope instead of letting reclaim thrashing take the
# whole session down. [Install] pulls in systemd-oomd.socket via Also=, which
# is what the user manager reports app.slice candidacy over.
enable_service systemd-oomd.service
