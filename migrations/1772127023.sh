set -euo pipefail

echo "Ensure screenshot dependencies are installed"

# omarchy-pkg-add already dispatches per-distro (dnf on Fedora, rpm-ostree on
# secureblue/OSTree via packages.sh); a raw `dnf list --available` probe here
# used to always fail on secureblue, since dnf is stubbed there to error out.
if ! command -v satty >/dev/null 2>&1; then
  echo "Installing satty"
  omarchy-pkg-add satty || echo "[WARN] satty is unavailable in enabled repositories"
fi

if ! command -v wayfreeze >/dev/null 2>&1; then
  echo "Installing wayfreeze"
  if ! omarchy-pkg-add wayfreeze; then
    echo "Installing wayfreeze-git"
    omarchy-pkg-add wayfreeze-git || echo "[INFO] wayfreeze package not available; screenshot capture still works without screen freeze"
  fi
fi
