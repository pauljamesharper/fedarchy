echo "Apple Silicon: make seamless-login wait for apple-drm so boot doesn't blank on simpledrm"

# Apple Silicon (Asahi) only. simpledrm owns the screen until apple-drm (the DCP
# display driver) takes over ~10s into boot. If omarchy-seamless-login starts the
# compositor inside that window it binds simpledrm, which can't scan out GPU
# buffers -> blank 0x0 screen. Gate seamless-login on the handoff being done.
modinfo appledrm &>/dev/null || exit 0

unit=/etc/systemd/system/omarchy-seamless-login.service
[[ -f $unit ]] || exit 0 # seamless-login not installed on this machine

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

# Install the wait helper (idempotent — always refresh to latest content).
$ESC tee /usr/local/bin/omarchy-wait-for-display >/dev/null <<'WAITEOF'
#!/bin/bash
# Wait for the real KMS display driver (apple-drm) to replace the early
# simpledrm boot framebuffer before the Wayland compositor starts. simpledrm is
# the platform device *.framebuffer bound to the "simple-framebuffer" driver; it
# owns card0 until apple-drm takes over ~10s in. Starting the compositor while
# simpledrm still holds a card binds it and can't scan out GPU buffers ->
# blank/crash. Fail-open after ~15s so login is never blocked on a broken display.
apple_drm=/dev/dri/by-path/platform-soc:display-subsystem-card
for _ in $(seq 1 150); do
  # simpledrm still active if a device is bound to the simple-framebuffer driver
  if [ -e "$apple_drm" ] && ! ls /sys/bus/platform/drivers/simple-framebuffer/*.framebuffer >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.1
done
exit 0
WAITEOF
$ESC chmod +x /usr/local/bin/omarchy-wait-for-display

# Add ExecStartPre via drop-in, unless the base unit already has it (fresh installs).
if ! grep -q omarchy-wait-for-display "$unit"; then
  dropin=/etc/systemd/system/omarchy-seamless-login.service.d
  $ESC mkdir -p "$dropin"
  $ESC tee "$dropin/wait-for-display.conf" >/dev/null <<'DROPEOF'
[Service]
ExecStartPre=/usr/local/bin/omarchy-wait-for-display
DROPEOF
  $ESC systemctl daemon-reload
fi
