# Update localdb so locate can find the installed system files immediately.
# On OSTree targets plocate is layered for the next boot, so updatedb may not
# exist yet on the first pass.
if command -v updatedb &>/dev/null; then
  updatedb
else
  echo "[localdb] updatedb not available yet - skipping (re-run after reboot)"
fi
