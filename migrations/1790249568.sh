echo "Replace toolbox with distrobox"

source "$OMARCHY_PATH/install/helpers/distro-secureblue.sh"
if ! is_ostree; then
  omarchy-pkg-add distrobox
  if omarchy-pkg-present toolbox; then
    omarchy-pkg-drop toolbox
  fi
  exit 0
fi

source "$OMARCHY_PATH/install/helpers/packages-secureblue.sh"

# rpm -q only sees the booted deployment, so a change already queued for the
# next boot counts as done.
need_distrobox=0
if ! secureblue_package_installed distrobox && ! secureblue_deployment_requests requested-packages distrobox; then
  need_distrobox=1
fi

need_toolbox_removal=0
if secureblue_package_installed toolbox && ! secureblue_deployment_requests requested-base-removals toolbox; then
  need_toolbox_removal=1
fi

# One transaction when both are due, so there is only one authentication prompt.
if ((need_distrobox && need_toolbox_removal)); then
  rpm-ostree override remove toolbox --install distrobox
elif ((need_distrobox)); then
  rpm-ostree install --idempotent -y distrobox
elif ((need_toolbox_removal)); then
  rpm-ostree override remove toolbox
else
  exit 0
fi

echo "Reboot to switch from toolbox to distrobox"
