#!/bin/bash
# Stage OS updates in the background on atomic Fedora: rpm-ostreed downloads
# and prepares the next deployment daily, and it takes over on the next reboot.
# secureblue schedules its own updates, so it is left alone. Runs as root.
source "$OMARCHY_PATH/install/helpers/distro-secureblue.sh"
is_ostree || exit 0
is_secureblue && exit 0

conf=/etc/rpm-ostreed.conf
if grep -qE '^#?AutomaticUpdatePolicy=' "$conf"; then
  sed -i -E 's/^#?AutomaticUpdatePolicy=.*/AutomaticUpdatePolicy=stage/' "$conf"
else
  printf '\n[Daemon]\nAutomaticUpdatePolicy=stage\n' >>"$conf"
fi

rpm-ostree reload
systemctl enable --now rpm-ostreed-automatic.timer
