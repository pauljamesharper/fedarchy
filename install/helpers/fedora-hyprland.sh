#!/bin/bash
# Hyprland core package selection for Fedora aarch64.
#
# lionheartp/Hyprland is the only aarch64 source for the compositor: Fedora proper ships hyprlang and
# hyprutils, but no hyprland, aquamarine or uwsm. Its stable `hyprland` package is built once per
# release, so when the COPR rebuilds hyprutils/aquamarine across an soname bump, stable stops
# resolving until it is rebuilt too. hyprland-0.55.4 was built 2026-06-11 against libhyprutils.so.12
# and libaquamarine.so.11; the 2026-07-18 library rebuilds moved those to .13 and .12 and left
# stable uninstallable.
#
# hyprland-git is rebuilt from git daily against the current libraries, so it covers those windows.
# The two packages conflict, so exactly one is ever installed.
#
# The uwsm session file is in a separate subpackage on both sides - hyprland-uwsm and
# hyprland-git-uwsm - and each is only a Recommends, not a Requires. Both are installed explicitly
# here rather than left to weak dependencies, because install/login/sddm.sh points SDDM at the
# hyprland-uwsm session and silently falls back to the plain hyprland session when that .desktop is
# missing. A machine installed with install_weak_deps=False would otherwise get the wrong session.
#
# Stable is always preferred. This runs from the installer and from omarchy-update-manual-pkgs, so a
# machine parked on hyprland-git returns to stable on its own as soon as the COPR ships a working
# build - the user never has to do anything. The compositor swap is a single dnf transaction: dnf
# resolves it fully before touching any package, so an attempt made while stable is still broken
# fails without disturbing the working hyprland-git install. Only once that has succeeded is the
# session subpackage swapped, because the two subpackages own the same .desktop path and would
# collide if both were installed.

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"

is_fedora || exit 0

# Any OSTree/atomic Fedora target (secureblue and plain atomic alike): same
# stable/git selection and swap logic as below, but every install/swap is
# an rpm-ostree layer that only takes effect on the *next* boot - `rpm -q`
# here still reflects the currently booted deployment, not a pending one,
# so re-running this script before rebooting is a safe no-op (the pending
# change is already queued) and re-running it after rebooting picks up
# wherever the swap left off. `rpm-ostree install X --uninstall Y` is the
# atomic-swap equivalent of `dnf swap Y X` - one transaction, resolved
# fully before anything is written, same safety property as dnf's swap.
# No escalation wrapper either way: rpm-ostree is a D-Bus client to the
# already-root rpm-ostreed daemon, which authorizes the call itself.
if is_ostree; then
  if rpm -q hyprland &>/dev/null; then
    rpm -q hyprland-uwsm &>/dev/null || rpm-ostree install --idempotent -y hyprland-uwsm
    echo "[hyprland] stable hyprland installed"
    exit 0
  fi

  if rpm -q hyprland-git &>/dev/null; then
    echo "[hyprland] on hyprland-git - checking whether stable has been rebuilt"
    if rpm-ostree install --idempotent -y hyprland --uninstall hyprland-git >/dev/null 2>&1; then
      echo "[hyprland] stable hyprland is available again - queued swap off hyprland-git (takes effect next reboot)"
      if rpm -q hyprland-git-uwsm &>/dev/null; then
        rpm-ostree install --idempotent -y hyprland-uwsm --uninstall hyprland-git-uwsm ||
          echo "[hyprland] WARNING: hyprland-git-uwsm still owns the uwsm session file"
      else
        rpm -q hyprland-uwsm &>/dev/null || rpm-ostree install --idempotent -y hyprland-uwsm
      fi
    else
      echo "[hyprland] stable hyprland still does not resolve - staying on hyprland-git"
    fi
    exit 0
  fi

  echo "[hyprland] queuing the Hyprland core (takes effect next reboot)"
  if rpm-ostree install --idempotent -y hyprland hyprland-uwsm; then
    exit 0
  fi

  echo "[hyprland] stable hyprland does not resolve - falling back to hyprland-git"
  if rpm-ostree install --idempotent -y hyprland-git hyprland-git-uwsm; then
    exit 0
  fi

  # Neither variant could be layered. Fail loudly: install-atomic.sh treats this as fatal, because
  # every later step assumes a compositor is queued and the closing "reboot and re-run" advice
  # would otherwise loop forever without Hyprland ever reaching SDDM.
  echo "[hyprland] ERROR: rpm-ostree could not layer hyprland or hyprland-git (see the rpm-ostree output above)" >&2
  exit 1
fi

if rpm -q hyprland &>/dev/null; then
  # Repair the case where the session subpackage was skipped as a weak dependency.
  rpm -q hyprland-uwsm &>/dev/null || sudo dnf install -y hyprland-uwsm
  echo "[hyprland] stable hyprland installed"
  exit 0
fi

if rpm -q hyprland-git &>/dev/null; then
  echo "[hyprland] on hyprland-git - checking whether stable has been rebuilt"
  if sudo dnf swap -y --refresh --allowerasing hyprland-git hyprland >/dev/null 2>&1; then
    echo "[hyprland] stable hyprland is available again - swapped off hyprland-git"
    if rpm -q hyprland-git-uwsm &>/dev/null; then
      sudo dnf swap -y --allowerasing hyprland-git-uwsm hyprland-uwsm ||
        echo "[hyprland] WARNING: hyprland-git-uwsm still owns the uwsm session file"
    else
      rpm -q hyprland-uwsm &>/dev/null || sudo dnf install -y hyprland-uwsm
    fi
  else
    echo "[hyprland] stable hyprland still does not resolve - staying on hyprland-git"
  fi
  exit 0
fi

echo "[hyprland] installing the Hyprland core"
if sudo dnf install -y --refresh --allowerasing hyprland hyprland-uwsm; then
  exit 0
fi

echo "[hyprland] stable hyprland does not resolve - falling back to hyprland-git"
sudo dnf install -y --refresh --allowerasing hyprland-git hyprland-git-uwsm
