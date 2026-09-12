#!/bin/bash
# Install the optional/build package set from
# omarchy-other.packages.{fedora,secureblue} in a single transaction. Unlike
# base.sh's per-package loop, nothing here is critical enough to fail the
# install over.
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"

if is_secureblue; then
  source "$OMARCHY_INSTALL/helpers/packages-secureblue.sh"
  package_file="$OMARCHY_INSTALL/omarchy-other.packages.secureblue"
else
  package_file="$OMARCHY_INSTALL/omarchy-other.packages.fedora"
fi

packages=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  packages+=("$line")
done <"$package_file"

if is_secureblue; then
  # Everything in omarchy-other.packages.secureblue (including the
  # development-tools approximation - see that file's header for why it's
  # here on the host rather than in a toolbox) goes through the system
  # tier: one location for the build toolchain, not split across host and
  # container.
  #
  # One batched rpm-ostree transaction, not one call per package: run0 has
  # no sudo-style auth cache, so a call per package means a fresh polkit
  # authentication per package (see packages-secureblue.sh's
  # secureblue_install_system_batch for the full reasoning - this bit the
  # very first real run of this installer).
  ((${#packages[@]})) || exit 0
  echo "[Omarchy] Installing optional/build packages in one rpm-ostree transaction..."
  secureblue_install_system_batch "${packages[@]}" ||
    echo "[WARNING] batched optional/build install had failures - continuing"
  exit 0
fi

((${#packages[@]})) || exit 0

echo "[Omarchy] Installing optional and build packages..."
if ! sudo dnf install -y --skip-unavailable "${packages[@]}"; then
  echo "[WARNING] Some optional packages could not be installed - continuing"
fi
