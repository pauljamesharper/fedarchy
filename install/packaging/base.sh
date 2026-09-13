#!/bin/bash
# Install the base package set from omarchy-base.packages.{fedora,secureblue}.
# Runs as the user; the package helpers escalate internally (sudo on plain
# mutable Fedora, run0 on secureblue, sudo again on plain atomic Fedora -
# see packages-secureblue.sh, which despite its name now serves any
# OSTree/atomic Fedora target, not just secureblue).
source "$OMARCHY_INSTALL/helpers/packages.sh"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"

if is_ostree; then
  package_file="$OMARCHY_INSTALL/omarchy-base.packages.secureblue"

  # This user's own ~/dotfiles/Brewfile is the canonical "command-line
  # programs come from Homebrew" list for this machine (predates this
  # install, already relied on by their own dotfiles/install.sh, and
  # explicitly documents itself as the same list on Fedora Sway Atomic and
  # secureblue). Several CLI tools Omarchy wants (starship, eza, fzf,
  # ripgrep, bat, fd, zoxide, jq, tldr, neovim, yt-dlp) are already in it -
  # deliberately not duplicated in omarchy-base.packages.secureblue (see
  # that file's Shell & CLI tools section). Running the Brewfile here means
  # both lists end up satisfied from one source of truth instead of two
  # copies drifting apart. Safe if the file doesn't exist (e.g. testing
  # this fork without that dotfiles repo present) or if brew isn't ready
  # yet.
  if [[ -f "$HOME/dotfiles/Brewfile" ]] && command -v brew &>/dev/null; then
    echo "[Omarchy] Running brew bundle against ~/dotfiles/Brewfile first..."
    brew bundle --file="$HOME/dotfiles/Brewfile" || echo "[WARNING] brew bundle had failures - continuing"
  fi
else
  package_file="$OMARCHY_INSTALL/omarchy-base.packages.fedora"
fi

core_packages=()
optional_packages=()
in_optional=0
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  if [[ "$line" == "OPTIONAL:" ]]; then
    in_optional=1
    continue
  fi
  if ((in_optional)); then
    optional_packages+=("$line")
  else
    core_packages+=("$line")
  fi
done <"$package_file"

# Let the user pick from the optional packages when gum and a TTY are available;
# otherwise take them all (unattended / curl installs).
if command -v gum &>/dev/null && ((${#optional_packages[@]} > 0)) && [[ -t 0 ]]; then
  echo -e "\e[34m[Omarchy] Select optional packages (space to toggle, enter to confirm):\e[0m"
  selected_optional=$(printf '%s\n' "${optional_packages[@]}" | gum choose --no-limit --height 20)
  mapfile -t selected_optional_pkgs <<<"$selected_optional"
else
  selected_optional_pkgs=("${optional_packages[@]}")
fi

packages=("${core_packages[@]}" "${selected_optional_pkgs[@]}")

# Install each package, skipping ones already present and collecting failures so
# a single missing package never aborts the whole base install. On any
# OSTree/atomic target, each entry may carry a `gui:`/`cli:` tier prefix (see
# omarchy-base.packages.secureblue's header) routing it to flatpak/brew
# instead of the default rpm-ostree system tier - entirely idempotent either
# way, since every tier function checks "already installed" before acting.
#
# OSTree system-tier packages are collected here and installed in one batched
# rpm-ostree transaction after this loop, not one call per package: on
# secureblue this also works around run0 having no sudo-style auth cache (a
# separate call per package means a separate polkit authentication per
# package, and a single slow/retried fingerprint scan is enough to blow past
# the timeout on starting that call's transient unit - the auth completes
# but the install never runs). On plain atomic Fedora (sudo, which does
# cache) that specific failure mode doesn't apply, but batching is still
# worth keeping: one rpm-ostree transaction is atomic and gives one clear
# error naming what didn't resolve, instead of a wall of per-package output.
# gui/cli installs don't have this problem (flatpak --user and brew need no
# root at all), so those stay as individual calls in this loop.
failed_packages=()
system_pending=()
for pkg in "${packages[@]}"; do
  [[ -z "$pkg" ]] && continue

  tier="system"
  name="$pkg"
  if is_ostree; then
    case "$pkg" in
    gui:*) tier="gui" name="${pkg#gui:}" ;;
    cli:*) tier="cli" name="${pkg#cli:}" ;;
    esac
  fi

  case "$tier" in
  gui)
    if secureblue_gui_installed "$name"; then
      echo "[SKIPPED] $name (already installed)"
    elif secureblue_install_gui "$name"; then
      echo "[OK] $name (flatpak)"
    else
      echo "[FAILED] $name (flatpak)"
      failed_packages+=("$name (flatpak)")
    fi
    ;;
  cli)
    if secureblue_cli_installed "$name"; then
      echo "[SKIPPED] $name (already installed)"
    elif secureblue_install_cli "$name"; then
      echo "[OK] $name (brew)"
    else
      echo "[FAILED] $name (brew)"
      failed_packages+=("$name (brew)")
    fi
    ;;
  *)
    if is_ostree; then
      if omarchy_package_installed "$name"; then
        echo "[SKIPPED] $name (already installed)"
      else
        system_pending+=("$name")
      fi
      continue
    fi

    if omarchy_package_installed "$name"; then
      echo "[SKIPPED] $name (already installed)"
      continue
    fi

    if omarchy_install_package "$name"; then
      echo "[OK] $name"
    else
      echo "[FAILED] $name"
      if dnf list --available "$name" &>/dev/null; then
        failed_packages+=("$name")
      else
        failed_packages+=("$name (not found in dnf)")
      fi
    fi
    ;;
  esac
done

if is_ostree && ((${#system_pending[@]} > 0)); then
  echo "[Omarchy] Installing ${#system_pending[@]} system-tier package(s) in one rpm-ostree transaction..."
  if secureblue_install_system_batch "${system_pending[@]}"; then
    printf '[OK] %s\n' "${system_pending[@]}"
  else
    echo "[FAILED] batched system-tier install (see above for which package rpm-ostree could not resolve)"
    failed_packages+=("${system_pending[@]}")
  fi
fi

echo
if ((${#failed_packages[@]} > 0)); then
  echo "==============================="
  echo "The following base packages could not be installed:"
  for pkg in "${failed_packages[@]}"; do
    echo "  - $pkg"
  done
  echo "==============================="
else
  echo -e "\e[32mAll base packages installed successfully!\e[0m"
fi
