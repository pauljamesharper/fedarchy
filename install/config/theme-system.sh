source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/distro-secureblue.sh"

if ! is_ostree; then
  # Set links for Nautilus action icons
  mkdir -p /usr/share/icons/Yaru/scalable/actions
  ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg \
            /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
  ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg \
            /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg
  gtk-update-icon-cache /usr/share/icons/Yaru &>/dev/null || true
fi

# Chromium policy directory for theme - /etc, works unchanged on both.
mkdir -p /etc/chromium/policies/managed
chmod a+rw /etc/chromium/policies/managed

if ! is_ostree; then
  # Default Chromium to follow system appearance ("device") instead of dark.
  # Skipped on any OSTree/atomic Fedora target: this is a /usr/lib write,
  # and /usr is read-only there (same reason as system-files.sh) - not
  # because Chromium is a flatpak. It isn't: omarchy-base.packages.secureblue
  # deliberately keeps chromium on the system (rpm-ostree) tier, not
  # flatpak, precisely because a flatpak copy would complicate the
  # native-messaging-host registration install/user/chromium.sh does.
  mkdir -p /usr/lib/chromium
  echo '{"browser":{"theme":{"color_scheme":0,"color_scheme2":0}}}' > \
    /usr/lib/chromium/initial_preferences
fi
