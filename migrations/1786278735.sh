echo "Detect dropped SSH connections quickly instead of leaving terminals hung"

conf="/etc/ssh/ssh_config.d/20-omarchy-keepalive.conf"

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

if [[ ! -f $conf ]]; then
  $ESC install -d -m 755 /etc/ssh/ssh_config.d
  # An explicit mode so a restrictive user umask cannot leave the root-owned
  # drop-in unreadable to the unprivileged ssh client.
  $ESC tee "$conf" >/dev/null <<'EOF'
# Omarchy: notice dropped connections quickly instead of hanging until TCP
# times out. Settings in ~/.ssh/config take precedence over these defaults.
Host *
  ServerAliveInterval 15
  ServerAliveCountMax 3
  ConnectTimeout 10
EOF
  $ESC chmod 644 "$conf"
fi
