#!/bin/bash
# OSTree/atomic Fedora: Homebrew is the CLI tier (see packages-secureblue.sh), and gum, zsh, nvim and
# the rest of the `cli:` entries all route through it, so it has to exist before any of them run.
# Nothing else bootstraps it: without this, every cli-tier install fails and the installer carries on
# with no gum UI.
#
# The official installer only needs root to create /home/linuxbrew. Creating that prefix here and
# handing it to the user lets it run with NONINTERACTIVE=1 and no sudo of its own, which is also the
# only way it works on secureblue, where there is no sudo at all.

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"

is_ostree || exit 0

BREW_PREFIX=/home/linuxbrew/.linuxbrew

if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
  echo "[Omarchy] Homebrew already installed."
else
  echo "[Omarchy] Installing Homebrew..."
  if is_secureblue; then ESC=run0; else ESC=sudo; fi
  $ESC mkdir -p "$BREW_PREFIX"
  $ESC chown -R "$USER:$(id -gn)" /home/linuxbrew

  if ! NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    echo "[ERROR] Homebrew install failed." >&2
    exit 1
  fi
fi

# Interactive bash on an existing machine keeps the user's own ~/.bashrc (config.sh leaves it alone),
# so brew has to be put on PATH there explicitly.
shellenv_line="eval \"\$($BREW_PREFIX/bin/brew shellenv bash)\""
if [[ -f $HOME/.bashrc ]] && ! grep -Fq "$BREW_PREFIX/bin/brew shellenv" "$HOME/.bashrc"; then
  printf '\n# Homebrew (added by Omarchy)\n%s\n' "$shellenv_line" >>"$HOME/.bashrc"
  echo "[Omarchy] Added Homebrew to ~/.bashrc"
fi
