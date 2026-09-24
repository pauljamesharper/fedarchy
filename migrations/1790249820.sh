echo "Point ~/.XCompose at the Omarchy checkout instead of /usr/share/omarchy"

# The installer wrote the packaged path, which does not exist on a git-clone
# install, so the emoji compose table never loaded.
xcompose="$HOME/.XCompose"
stale='include "/usr/share/omarchy/default/xcompose"'

[[ -f $xcompose ]] || exit 0
[[ -e /usr/share/omarchy/default/xcompose ]] && exit 0
grep -qxF "$stale" "$xcompose" || exit 0

sed -i "s|^include \"/usr/share/omarchy/default/xcompose\"\$|include \"$OMARCHY_PATH/default/xcompose\"|" "$xcompose"
omarchy-restart-xcompose
