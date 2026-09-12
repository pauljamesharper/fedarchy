#!/bin/bash
# Seed the shipped user configs. On Arch these come from a package-populated
# /etc/skel; the git-clone fork has no package, so copy them out of the clone.
# Runs as the user.
OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"

# Shipped ~/.config tree. Never overwrite an entry that already exists
# (symlink or otherwise) - a stow-managed dotfiles setup (this fork's target
# user included) puts real, user-owned configs at these same paths, and a
# blind `cp -R .../* ~/.config/` would either error trying to overwrite a
# symlink with a directory, or - had it not errored - write straight through
# the symlink into whatever it points at.
mkdir -p ~/.config
for entry in "$OMARCHY_PATH"/config/*; do
  name="$(basename "$entry")"
  if [[ -e ~/.config/$name || -L ~/.config/$name ]]; then
    echo "[config] ~/.config/$name already exists - leaving it alone"
    continue
  fi
  cp -R "$entry" ~/.config/
done

# The shipped chromium flags load extensions from the Arch package path;
# point them into the clone.
[[ -f ~/.config/chromium-flags.conf ]] &&
  sed -i "s|/usr/share/omarchy/|$OMARCHY_PATH/|g" ~/.config/chromium-flags.conf

# Shipped bashrc (it sources the rest of the shell setup from $OMARCHY_PATH).
# Its env-bootstrap line also carries the Arch package path, and with it left
# in place non-login shells never get OMARCHY_PATH. Skipped if ~/.bashrc
# already exists (e.g. a dotfiles-managed symlink): OMARCHY_PATH still
# reaches every shell via the ~/.profile export below and the ~/.bash_profile
# sourcing hook, so this is a convenience layer only, not load-bearing - and
# `cp` writing through an existing symlink would otherwise silently overwrite
# whatever file it points at.
if [[ -e ~/.bashrc || -L ~/.bashrc ]]; then
  echo "[config] ~/.bashrc already exists - leaving it alone"
else
  cp "$OMARCHY_PATH/default/bashrc" ~/.bashrc
  sed -i "s|/usr/share/omarchy/|$OMARCHY_PATH/|g" ~/.bashrc
fi

# Make Omarchy commands available in login sessions (e.g. the SDDM Wayland
# session), not just interactive bash.
if ! grep -q 'OMARCHY_PATH=' ~/.profile 2>/dev/null; then
  cat >>~/.profile <<EOF

export OMARCHY_PATH="$OMARCHY_PATH"
export PATH="\$OMARCHY_PATH/bin:\$PATH"
EOF
fi

# User-local pip/npm tools on PATH as well.
if ! grep -q 'PATH="$HOME/.local/bin:$PATH"' ~/.profile 2>/dev/null; then
  cat >>~/.profile <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
fi

# Ensure bash login shells (used by the SDDM session wrapper) load ~/.profile.
if ! grep -q 'if \[ -f ~/.profile \]; then' ~/.bash_profile 2>/dev/null; then
  cat >>~/.bash_profile <<'EOF'

if [ -f ~/.profile ]; then
    . ~/.profile
fi
EOF
fi
