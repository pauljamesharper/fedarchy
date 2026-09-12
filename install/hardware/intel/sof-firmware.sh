# Install Sound Open Firmware for Intel audio DSPs. The sof-audio-pci-intel-*
# driver family requires this firmware; without it PipeWire exposes only a
# Dummy Output sink.

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"

if omarchy-hw-intel-sof; then
  # sof-firmware is the Arch package name; Fedora ships the same firmware as
  # alsa-sof-firmware (already present on most Fedora spins by default).
  if is_fedora; then
    omarchy-pkg-add alsa-sof-firmware
  else
    omarchy-pkg-add sof-firmware
  fi
fi
