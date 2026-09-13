echo "Ensure zram-generator is installed for configured zram swap"

if omarchy-pkg-missing zram-generator; then
  omarchy-pkg-add zram-generator
fi

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

# Installing the package after boot does not run the generated unit until the
# manager reloads. Start it now so upgraded machines get the same zram device a
# fresh install gets on its next boot.
$ESC systemctl daemon-reload
$ESC systemctl start systemd-zram-setup@zram0.service
