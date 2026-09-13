echo "Tune reclaim for swap on zram"

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

# Everything here only applies the shipped config early; boot picks it up
# regardless. Nothing is worth failing the migration chain over, so each step
# falls back to asking for a reboot.

# Load our file specifically rather than --system, which returns nonzero for
# any invalid key in any admin sysctl file on the machine.
$ESC sysctl -p /etc/sysctl.d/99-omarchy-sysctl.conf >/dev/null || true

if $ESC systemctl daemon-reload; then
  # Resizing swaps the device off first, which faults every stored page back
  # into memory. That's only cheap while it's empty, so a device under
  # pressure keeps its old size until the next boot. A device that doesn't
  # exist yet reads as empty, which is what we want: the restart brings it up
  # against the unit daemon-reload just generated.
  zram_used=$(awk '$1 == "/dev/zram0" {print $4}' /proc/swaps)

  if [[ ${zram_used:-0} == 0 ]] && $ESC systemctl restart dev-zram0.swap; then
    exit 0
  fi
fi

omarchy-state set reboot-required
