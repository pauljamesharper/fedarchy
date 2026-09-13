echo "Install util-linux-script required by omarchy-update-perform"

if ! rpm -q util-linux-script >/dev/null 2>&1; then
  omarchy-pkg-add util-linux-script
fi
