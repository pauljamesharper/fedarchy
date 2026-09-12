#!/bin/bash
# Enable required COPR repositories for Omarchy Fedora

# Only run on Fedora
OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"

if ! is_fedora; then
  exit 0
fi

# secureblue has no dnf, so no `dnf copr enable` - but rpm-ostree reads the
# same /etc/yum.repos.d/*.repo files dnf does, so a COPR repo just needs its
# repo file written by hand instead of fetched via the dnf-copr plugin. Only
# lionheartp/Hyprland is still needed here: atim/starship and atim/lazygit
# are superseded by brew (see packages-secureblue.sh / packaging rework),
# and the two optional COPRs (nclundell/fedora-extras, scottames/ghostty)
# are dnf-plugin conveniences with no non-dnf equivalent worth building for
# an optional repo - skipped outright on this path.
if is_secureblue; then
  LIONHEARTP_REPO_URL="https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/repo/fedora-$(fedora_version)/"
  LIONHEARTP_REPO_FILE="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lionheartp:Hyprland.repo"

  echo "Fetching lionheartp/Hyprland COPR repo file (secureblue: no dnf copr enable)..."
  if curl -fsSL "$LIONHEARTP_REPO_URL" | run0 tee "$LIONHEARTP_REPO_FILE" >/dev/null; then
    echo "✓ Wrote $LIONHEARTP_REPO_FILE"
  else
    echo "✗ Failed to fetch/write the lionheartp/Hyprland COPR repo file" >&2
    echo "  No usable chroot for Fedora $(fedora_version) $(uname -m), or the COPR project is gone." >&2
    exit 1
  fi

  source "$OMARCHY_INSTALL/helpers/fedora-copr-protect.sh"
  echo "Applying repo protections for Hyprland stability..."
  fedora_remove_dead_copr_repos
  fedora_apply_copr_protections

  # No `dnf distro-sync` equivalent: rpm-ostree resolves and layers packages
  # from this repo directly when packaging/base.sh calls
  # secureblue_install_system, there's no separate "sync the transaction"
  # step to run here.
  exit 0
fi

# Required COPR repos: the install cannot proceed without these.
# lionheartp/Hyprland is the single source for the whole Hyprland stack (hyprland, uwsm,
# hyprland-guiutils, gpu-screen-recorder, portal) - it is the Asahi-safe build and is rebuilt
# continuously. quickshell itself comes from the official Fedora repos, not a COPR.
COPR_REPOS=(
  "lionheartp/Hyprland"
  "atim/starship"
  "atim/lazygit"
)

# Optional COPR repos (may not be available for all Fedora versions)
# scottames/ghostty is only needed by `omarchy-install-terminal ghostty`; the default
# terminal is alacritty, so a missing ghostty must never fail the install.
OPTIONAL_COPR_REPOS=(
  "nclundell/fedora-extras"
  "scottames/ghostty"
)

echo "Enabling required COPR repositories..."
for repo in "${COPR_REPOS[@]}"; do
  echo "Enabling COPR repo: $repo"
  if sudo dnf copr enable -y "$repo"; then
    echo "✓ Successfully enabled: $repo"
  else
    echo "✗ Failed to enable: $repo (required)"
    echo "  No usable chroot for Fedora $(fedora_version) $(uname -m), or the COPR project is gone."
    exit 1
  fi
done

echo "Enabling optional COPR repositories..."
for repo in "${OPTIONAL_COPR_REPOS[@]}"; do
  echo "Attempting to enable optional COPR repo: $repo"
  if sudo dnf copr enable -y "$repo" 2>/dev/null; then
    echo "✓ Successfully enabled: $repo"
  else
    echo "⚠ Skipping unavailable repo: $repo (optional)"
  fi
done

echo "COPR repositories enabled."

# -------------------------------------------------------------
# HYPRLAND REPOSITORY PROTECTION
# Lionheartp must provide Hyprland core to keep Asahi compat.
# -------------------------------------------------------------
source "$OMARCHY_INSTALL/helpers/fedora-copr-protect.sh"

echo "Applying repo protections for Hyprland stability..."
fedora_remove_dead_copr_repos
fedora_apply_copr_protections

echo "Running Fedora package reconciliation after COPR setup..."
if [[ "${OMARCHY_DRY_RUN:-0}" == "1" ]]; then
  echo "[DRY-RUN] Would run: sudo dnf distro-sync -y --refresh --allowerasing"
else
  if ! sudo dnf distro-sync -y --refresh --allowerasing; then
    echo "✗ Fedora distro-sync failed after COPR setup"
    exit 1
  fi
fi
