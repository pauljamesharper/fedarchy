echo "Show Fedora and per-source update times in About, and update every source automatically"

# About's logo, unless the user replaced the stock Omarchy one.
about="$HOME/.config/omarchy/branding/about.txt"
if [[ -f $about ]] && [[ $(sha256sum <"$about" | cut -d' ' -f1) == "5fe8adced2fe67e410e177477a7272d1807b3fedc81fbc3f030dd479bc046b76" ]]; then
  cp "$OMARCHY_PATH/icon.txt" "$about"
fi

# The About config lives in /etc, the Distrobox upgrade timer ships beside the
# other user units there, and rpm-ostree automatic updates are a daemon setting.
sudo env OMARCHY_PATH="$OMARCHY_PATH" bash -c '
  install -Dm644 "$OMARCHY_PATH/etc/fastfetch/config.jsonc" /etc/fastfetch/config.jsonc
  for unit in "$OMARCHY_PATH"/default/systemd/user/omarchy-update-distrobox.{service,timer}; do
    sed -e "s|/usr/bin/omarchy-|$OMARCHY_PATH/bin/omarchy-|g" "$unit" >"/etc/systemd/user/$(basename "$unit")"
  done
  bash "$OMARCHY_PATH/install/config/ostree-auto-updates.sh"
'

systemctl --user daemon-reload
systemctl --user enable --now omarchy-update-distrobox.timer
