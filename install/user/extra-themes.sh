#!/bin/bash
# Themes that ship outside the repo but belong in the default set. Cloned
# without applying them, and skipped when offline so the install carries on.
themes_dir="$HOME/.config/omarchy/themes"
mkdir -p "$themes_dir"

for repo in https://github.com/dhh/omarchy-giants-theme.git; do
  name=$(basename "$repo" .git | sed -E 's/^omarchy-//; s/-theme$//')
  [[ -d $themes_dir/$name ]] && continue
  git clone --depth 1 "$repo" "$themes_dir/$name" || echo "Could not clone the $name theme (continuing)"
done
