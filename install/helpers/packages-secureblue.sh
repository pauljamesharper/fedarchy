#!/bin/bash

# secureblue package-management helpers for Omarchy.
#
# secureblue has no dnf (it's shadowed with a message pointing at
# rpm-ostree/flatpak/toolbox) and no sudo (only run0). Unlike the Fedora
# helper (packages-fedora.sh), which treats every package as one
# `dnf install`, this file exposes four separate install functions - one per
# tier - because the right mechanism depends on what the package actually is,
# not just what distro it's on. Callers (packaging/*.sh, hardware/*.sh)
# choose the tier explicitly per package/group; there is no auto-detection.
#
#   secureblue_install_system  - rpm-ostree layer, last resort: compositor,
#                                 portals, PAM/greeter, kernel modules,
#                                 systemd-service-backed daemons - anything
#                                 that can't be sandboxed. Deliberately NOT
#                                 run under run0: rpm-ostree is a D-Bus
#                                 client to the already-root rpm-ostreed
#                                 daemon, and polkit authorizes the D-Bus
#                                 call itself - it was never meant to be
#                                 re-executed as root. Wrapping it in run0
#                                 instead produces a generic root process
#                                 that secureblue's SELinux policy
#                                 correctly refuses to let exec
#                                 /usr/bin/rpm-ostree at all (confirmed via
#                                 `ausearch -m avc`: an `entrypoint` denial
#                                 on install_exec_t) - plain `rpm-ostree
#                                 install ...` as the regular user is both
#                                 correct and the only thing that actually
#                                 works here.
#   secureblue_install_gui     - flatpak --user: GUI apps.
#   secureblue_install_cli     - brew (linuxbrew): CLI tools with no
#                                 systemd/kernel coupling.
#   secureblue_install_toolbox - escape hatch for a build environment that
#                                 genuinely needs a full mutable userspace.
#                                 Not used by default; most things fit one of
#                                 the three tiers above.

secureblue_package_installed() {
  rpm -q "$1" &>/dev/null
}

secureblue_install_system() {
  local package="$1"
  if secureblue_package_installed "$package"; then
    return 0
  fi
  rpm-ostree install --idempotent --allow-inactive -y "$package"
}

# Batched install: one rpm-ostree transaction (one polkit auth) for many
# packages, instead of secureblue_install_system called once per package.
# Not just an optimization - calling secureblue_install_system in a loop
# over a long package list means one fresh polkit authentication per
# package; run0's per-invocation auth has no cache the way sudo does, and
# in practice a single slow/retried fingerprint scan is enough to blow past
# whatever timeout governs starting that invocation's transient unit, so
# the auth itself completes but the install never actually runs. Batching
# also means the transaction is atomic: either every package here resolves
# and gets queued, or the whole call fails with one clear rpm-ostree error
# naming what didn't resolve - much easier to debug than a wall of silent
# per-package failures.
secureblue_install_system_batch() {
  local pkgs=() pkg
  for pkg in "$@"; do
    secureblue_package_installed "$pkg" || pkgs+=("$pkg")
  done
  ((${#pkgs[@]})) || return 0
  rpm-ostree install --idempotent --allow-inactive -y "${pkgs[@]}"
}

secureblue_remove_system() {
  rpm-ostree uninstall -y "$1"
}

secureblue_update_system() {
  rpm-ostree upgrade -y
}

# GUI apps, one Flatpak application ID at a time. --user matches the
# existing flathub-remote pattern already established in fedora-manual.sh:
# no sudo, no dependency on /var/lib/flatpak existing yet.
secureblue_gui_installed() {
  flatpak info --user "$1" &>/dev/null
}

secureblue_install_gui() {
  local app_id="$1"
  if secureblue_gui_installed "$app_id"; then
    return 0
  fi
  # base.sh installs GUI apps before fedora-manual.sh runs, so the user
  # flathub remote may not exist yet on a first install.
  flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo || return 1
  flatpak install -y --user flathub "$app_id"
}

# CLI tools via linuxbrew. Assumes brew is already on PATH (Omarchy's own
# shell setup puts it there); this file doesn't bootstrap brew itself.
secureblue_cli_installed() {
  brew list --formula "$1" &>/dev/null
}

secureblue_install_cli() {
  local formula="$1"
  if secureblue_cli_installed "$formula"; then
    return 0
  fi
  # Safety net, not the primary check: catches a brew formula that shares
  # its name with a package already natively layered on the host (found
  # the hard way - fastfetch and tmux were each installed twice, once
  # native and once via brew, before this check existed). This only
  # catches same-name cases; it can't know a differently-named native
  # package provides the same tool, so a genuine duplicate is still
  # possible if a future addition's rpm name and brew formula name differ.
  if secureblue_package_installed "$formula"; then
    echo "[secureblue] $formula already natively layered - skipping brew (would duplicate it)"
    return 0
  fi
  brew install "$formula"
}

# Escape hatch: run a package install inside a toolbox container instead of
# layering it on the host. Creates the container on first use. The
# container is a regular (non-atomic) Fedora image, so dnf/sudo work
# normally *inside* it - this is not another run0 call.
secureblue_install_toolbox() {
  local package="$1" container="${2:-omarchy}"
  toolbox list --containers 2>/dev/null | grep -qw "$container" ||
    toolbox create -y "$container"
  toolbox run --container "$container" sudo dnf install -y "$package"
}
