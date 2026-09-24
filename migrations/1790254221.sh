echo "Point the LazyVim theme link at the current theme's state directory"

# omarchy-lazyvim-setup linked the theme under ~/.config/omarchy/current, which
# no longer exists, so Neovim failed to start with "cannot open ... omarchy-theme.lua".
theme_link="$HOME/.config/nvim/lua/plugins/omarchy-theme.lua"
[[ -L $theme_link ]] || exit 0

case "$(readlink "$theme_link")" in
  "$HOME/.local/state/omarchy/current/theme/neovim.lua") exit 0 ;;
  */omarchy/current/theme/neovim.lua) ;;
  *) exit 0 ;;
esac

ln -sfn "$HOME/.local/state/omarchy/current/theme/neovim.lua" "$theme_link"
