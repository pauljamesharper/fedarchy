# Install qalculate (Walker calculator) and plocate (Walker file search) if missing

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

packages=()
rpm -q libqalculate >/dev/null 2>&1 || packages+=(libqalculate)
rpm -q qalculate >/dev/null 2>&1 || packages+=(qalculate)
rpm -q plocate >/dev/null 2>&1 || packages+=(plocate)

if ((${#packages[@]} > 0)); then
  omarchy-pkg-add "${packages[@]}"
fi

mkdir -p ~/.config/qalculate
touch ~/.config/qalculate/qalc.cfg

if command -v updatedb >/dev/null 2>&1; then
  $ESC updatedb || true
fi

# Restart elephant so calc/files providers pick up newly installed qalculate/plocate
systemctl --user restart elephant 2>/dev/null || true

# Refresh walker config (adds missing [[providers.prefixes]] for files provider) and restart.
# Neither helper is shipped by this fork yet (no config/walker/config.toml, no
# bin/omarchy-restart-walker) - best-effort until they are, matching the same
# `|| true` this file already uses above for updatedb/elephant.
omarchy-refresh-config walker/config.toml 2>/dev/null || true
omarchy-restart-walker 2>/dev/null || true
