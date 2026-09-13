echo "Install missing Yaru split theme packages on Fedora"

if ! command -v dnf >/dev/null 2>&1; then
  exit 0
fi

packages=(
  yaru-icon-theme
  yaru-gtk3-theme
  yaru-gtk4-theme
  yaru-gtksourceview-theme
)

# yaru-gtk2-theme is deliberately absent: Fedora 44 ships no GTK2 theme at
# all any more (see migrations/1783927950.sh, which drops it for the same
# reason on machines that still carry it from an older release).

missing=()
for pkg in "${packages[@]}"; do
  if omarchy-pkg-missing "$pkg"; then
    missing+=("$pkg")
  fi
done

if (( ${#missing[@]} == 0 )); then
  echo "Yaru split theme packages already installed"
  exit 0
fi

omarchy-pkg-add "${missing[@]}"
