echo "Migrating initial login to SDDM"

# findmnt reports a btrfs root as /dev/mapper/x[/@]; the subvolume has to come
# off or lsblk cannot resolve it and an encrypted machine reads as unencrypted.

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

# secureblue never writes autologin.conf in the first place (see
# migrations/1771010000.sh and install/login/sddm.sh) - this file's own
# crypt-vs-plain detection below is for the traditional Fedora/Arch Btrfs+LUKS
# case, which doesn't describe secureblue's composefs-backed OSTree root and
# makes lsblk fail loudly (`lsblk: composefs: No such file or directory`) for
# no benefit, since the file it would conditionally remove never exists here.
is_secureblue && exit 0

root_source=$(findmnt -no SOURCE / | sed 's/\[.*\]//')

if [[ $(lsblk -no TYPE "$root_source") != "crypt" ]]; then
  $ESC rm -f /etc/sddm.conf.d/autologin.conf
fi
