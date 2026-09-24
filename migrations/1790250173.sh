echo "Keep bash as the interactive shell and install tmux"

# The installer used to prepend a block to ~/.bashrc that exec'd zsh in every
# interactive terminal. Drop it; zsh stays available via omarchy-setup-zsh.
bashrc="$HOME/.bashrc"
if [[ -f $bashrc ]] && grep -q '^# Auto-launch zsh shell if in interactive bash$' "$bashrc"; then
  cp "$bashrc" "$bashrc.backup-$(date +%Y%m%d-%H%M%S)"
  awk '
    /^# Auto-launch zsh shell if in interactive bash$/ { skipping = 1; next }
    skipping && /^fi$/ { depth--; if (depth < 0) { skipping = 0; drop_blank = 1 }; next }
    skipping && /^if / { depth++; next }
    skipping { next }
    drop_blank && /^$/ { drop_blank = 0; next }
    { drop_blank = 0; print }
  ' depth=-1 "$bashrc" >"$bashrc.tmp"
  mv "$bashrc.tmp" "$bashrc"
fi

# The Learn > Tmux keybindings page needs tmux itself.
if omarchy-cmd-missing tmux; then
  source "$OMARCHY_PATH/install/helpers/distro-secureblue.sh"
  if is_ostree; then
    brew install tmux
  else
    omarchy-pkg-add tmux
  fi
fi
