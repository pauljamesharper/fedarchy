#!/bin/bash

# Fedora requirement gate for the git-clone install. Runs as the target user
# before anything is installed or changed, so a machine that fails a check is
# left exactly as it was.
#
# This fork originally targeted Fedora Asahi Remix on aarch64 (Apple Silicon)
# only. It also now supports any OSTree/atomic Fedora on x86_64 - secureblue
# (run0 instead of sudo) and plain atomic Fedora (Silverblue/Kinoite/Sericea,
# sudo like install.sh) alike - the aarch64-only and Asahi-kernel checks that
# used to be here applied only to the Apple Silicon path and are gone; every
# other check (Fedora, Fedora 44+, not root) applies to all three targets
# unchanged.

source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/distro.sh"
source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/distro-secureblue.sh"

fail() {
  echo -e "\e[31m[Omarchy] Requirement not met: $1\e[0m" >&2
  exit 1
}

# Fedora (or a Fedora-based image, e.g. secureblue - it ships
# /etc/fedora-release too) only.
is_fedora || fail "Unsupported distro (Fedora required)"

# Fedora 44+ is a hard stop, not a soft warning: half-installing quattro on an
# older release would leave the machine broken. Bail before any change and print
# the upgrade steps (we never upgrade Fedora for the user).
if ! is_fedora_supported_version; then
  fedora_upgrade_instructions
  exit 1
fi

if is_secureblue; then
  echo "Guards: secureblue detected - privilege escalation is run0, packages route through rpm-ostree/flatpak/brew."
elif is_ostree; then
  echo "Guards: atomic Fedora detected - privilege escalation is sudo, packages route through rpm-ostree/flatpak/brew."
fi

# install.sh escalates with sudo/run0 where it needs to; running the whole
# thing as root would seed configs into root's home instead of the user's.
if ((EUID == 0)); then
  fail "Run the installer as your regular user, not root (it escalates privilege itself when needed)"
fi

echo "Guards: OK"
