#!/bin/bash

# secureblue / OSTree detection, layered alongside distro.sh's Fedora detection.
#
# secureblue ships /etc/fedora-release (a symlink into /usr/lib/fedora-release)
# even though its own NAME/ID in /etc/os-release is "secureblue", so
# is_fedora() and is_fedora_supported_version() in distro.sh already return
# true here unmodified - VERSION_ID matches the underlying Fedora release.
# This file adds the finer-grained checks the installer needs on top of that,
# split across two independent axes call sites should pick the right one
# from:
#   - is_ostree(): package routing (rpm-ostree/flatpak/brew, not dnf) and
#     OSTree filesystem facts (/usr read-only, no @group syntax, no
#     btrfs-snapper, podman not Docker). Applies identically to secureblue
#     AND plain atomic Fedora (Silverblue/Kinoite/Sericea) - confirmed
#     empirically on a Fedora Sway Atomic machine (no host dnf, no Docker,
#     tuned-ppd active).
#   - is_secureblue(): hardening-only behavior - privilege escalation
#     (run0, not sudo), leaving PAM lockout/sudoers.d/autologin alone. Plain
#     atomic Fedora has none of that hardening posture and should behave
#     like install.sh (mutable Fedora) on all of it.
# Getting these two crossed is the single most common mistake when adding a
# new OSTree-aware branch - see install-atomic.sh's header for the fuller
# rationale.

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
