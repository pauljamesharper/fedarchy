#!/bin/bash
# Seed the fonts that aren't packaged: the Omarchy glyph font used by the shell,
# plus an icon-capable fallback on Fedora. Runs as the user.
OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
source "$OMARCHY_INSTALL/helpers/distro.sh"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"

# Omarchy glyph font (quattro ships it under default/fonts/omarchy/).
mkdir -p ~/.local/share/fonts
cp "$OMARCHY_PATH/default/fonts/omarchy/omarchy.ttf" ~/.local/share/fonts/

# Ensure an icon-capable font fallback exists so shell module glyphs render
# at a consistent size. (On secureblue this is also already listed in
# omarchy-base.packages.secureblue - this is just a belt-and-suspenders
# check, same as the Fedora path, and just as idempotent either way.)
if is_fedora && ! rpm -q cascadia-mono-nf-fonts &>/dev/null; then
  if is_secureblue; then
    rpm-ostree install --idempotent -y cascadia-mono-nf-fonts || true
  else
    sudo dnf install -y cascadia-mono-nf-fonts || true
  fi
fi

fc-cache
