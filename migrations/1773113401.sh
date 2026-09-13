echo "Install and configure zram swap for memory-constrained systems"

if omarchy-pkg-missing zram-generator; then
  omarchy-pkg-add zram-generator
fi

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

if [[ ! -f /etc/systemd/zram-generator.conf ]]; then
  $ESC mkdir -p /etc/systemd
  $ESC tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
fi

$ESC systemctl daemon-reload
$ESC systemctl start systemd-zram-setup@zram0.service
