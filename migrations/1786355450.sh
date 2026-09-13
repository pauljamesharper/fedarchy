echo "Replace terminaltexteffects with ttfx"

# ttfx is unavailable in enabled repositories on some Fedora configurations;
# an optional terminal effects tool, so don't fail the migration chain over
# it, and don't drop the old package unless its replacement actually landed
# (leaving the user with neither would be a regression, not a replacement).
if omarchy-pkg-add ttfx; then
  omarchy-pkg-drop python-terminaltexteffects
else
  echo "[WARNING] ttfx is unavailable in enabled repositories; leaving python-terminaltexteffects in place"
fi
