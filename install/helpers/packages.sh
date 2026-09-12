#!/bin/bash

# Omarchy package abstraction layer.
#
# Two Fedora-family package backends live side by side here: plain Fedora
# (dnf, packages-fedora.sh) and secureblue/OSTree (rpm-ostree via run0,
# packages-secureblue.sh). is_secureblue is checked first since secureblue
# also sets is_fedora true (it ships /etc/fedora-release) - the more
# specific check has to win.
#
# On secureblue, "install a package" (this generic interface, and the
# omarchy-pkg-add/omarchy-pkg-drop commands built on it) means the system
# tier - an rpm-ostree layer - matching what omarchy-pkg-add's own summary
# ("Install packages with dnf") means on plain Fedora. GUI-app and CLI-tool
# packages that belong on flatpak/brew instead are a per-script editorial
# choice made by the caller (packaging/*.sh, hardware/*.sh), which calls
# secureblue_install_gui/secureblue_install_cli directly - this generic
# interface only ever reaches for the system tier.
source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/distro.sh"
source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/distro-secureblue.sh"

if is_secureblue; then
  source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/packages-secureblue.sh"

  omarchy_package_installed() { secureblue_package_installed "$1"; }
  omarchy_package_known_to_any_manager() { secureblue_package_installed "$1"; }
  omarchy_install_package() { secureblue_install_system "$1"; }
  omarchy_install_package_with_fallback() { secureblue_install_system "$1"; }
  omarchy_remove_package() { secureblue_remove_system "$1"; }
  omarchy_update_system() { secureblue_update_system; }
  omarchy_setup_aur_helpers() { return 0; }
elif is_fedora; then
  source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/packages-fedora.sh"

  omarchy_package_installed() { fedora_package_installed "$1"; }
  omarchy_package_known_to_any_manager() { dnf list --available "$1" >/dev/null 2>&1 || fedora_package_installed "$1"; }
  omarchy_install_package() { fedora_install_package "$1"; }
  omarchy_install_package_with_fallback() { fedora_install_package "$1"; }
  omarchy_remove_package() { fedora_remove_package "$1"; }
  omarchy_update_system() { fedora_update_system; }
  # Kept for compatibility with legacy scripts; no-op on Fedora-only builds.
  omarchy_setup_aur_helpers() { return 0; }
else
  echo "[Omarchy] Unsupported distro for package helpers: $OMARCHY_DISTRO" >&2
  return 1 2>/dev/null || exit 1
fi
