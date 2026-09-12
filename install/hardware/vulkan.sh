#!/bin/bash

# Install Vulkan drivers matching detected GPU hardware
# (NVIDIA Vulkan is handled by nvidia.sh via nvidia-utils)

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"

# vulkan-intel/vulkan-radeon are Arch package names, carried over from
# upstream. Fedora ships both ICDs from a single mesa-vulkan-drivers
# package - this went unnoticed on the Asahi fork since Apple Silicon never
# hits the Intel/AMD branches below.
if is_fedora; then
  declare -A VULKAN_DRIVERS=(
    [Intel]=mesa-vulkan-drivers
    [AMD]=mesa-vulkan-drivers
  )
else
  declare -A VULKAN_DRIVERS=(
    [Intel]=vulkan-intel
    [AMD]=vulkan-radeon
  )
fi

PACKAGES=()

if [[ $(uname -m) == "aarch64" ]] && [[ -f /proc/device-tree/compatible ]] && grep -qi "apple" /proc/device-tree/compatible 2>/dev/null; then
  PACKAGES+=(vulkan-asahi)
fi

for vendor in "${!VULKAN_DRIVERS[@]}"; do
  if lspci | grep -iE "(VGA|Display).*$vendor" > /dev/null; then
    PACKAGES+=("${VULKAN_DRIVERS[$vendor]}")
  fi
done

# Dedupe: an Intel+AMD hybrid-graphics machine on Fedora would otherwise
# request mesa-vulkan-drivers twice.
if (( ${#PACKAGES[@]} > 0 )); then
  mapfile -t PACKAGES < <(printf '%s\n' "${PACKAGES[@]}" | sort -u)
  omarchy-pkg-add "${PACKAGES[@]}"
fi
