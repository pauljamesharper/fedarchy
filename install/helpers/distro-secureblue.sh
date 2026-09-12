#!/bin/bash

# secureblue / OSTree detection, layered alongside distro.sh's Fedora detection.
#
# secureblue ships /etc/fedora-release (a symlink into /usr/lib/fedora-release)
# even though its own NAME/ID in /etc/os-release is "secureblue", so
# is_fedora() and is_fedora_supported_version() in distro.sh already return
# true here unmodified - VERSION_ID matches the underlying Fedora release.
# This file adds the finer-grained checks the installer needs on top of that
# to route privilege escalation (run0, not sudo) and package installation
# (rpm-ostree/flatpak/brew, not dnf) differently.

# True on any OSTree-based system (secureblue, plain Silverblue/Kinoite,
# other atomic Fedora spins, bootc images) - /run/ostree-booted is the
# standard, distro-agnostic marker for "the root filesystem is an OSTree
# deployment", not something specific to secureblue.
is_ostree() {
  [[ -f /run/ostree-booted ]]
}

# True specifically on secureblue (any variant/image: sericea, silverblue,
# kinoite, etc.) - ID=secureblue is the same across all of them.
is_secureblue() {
  [[ -r /etc/os-release ]] && grep -q '^ID=secureblue$' /etc/os-release
}
