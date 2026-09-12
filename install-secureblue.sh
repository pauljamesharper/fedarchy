#!/bin/bash
#
# secureblue (OSTree/rpm-ostree, Lenovo X1 Carbon Gen 10 and similar x86_64
# Intel hardware) installer entry point, run from an already-configured,
# already-running secureblue session - not the Fedora Asahi ISO/TTY
# first-boot flow install.sh targets. Accounts, hostname, locale, and
# timezone are assumed already set up; this only installs the Omarchy
# desktop on top of what's already there.
#
# Two structural differences from install.sh drive everything else in this
# file:
#   - No sudo, only run0 (per-invocation polkit auth, no keepalive/sudoers
#     trick needed the way install.sh's sudo-keepalive loop was).
#   - rpm-ostree layers a package for the *next* boot, not this one. Every
#     step below is written to be safely re-run: package installs check
#     "already installed" before acting (see packages-secureblue.sh), and
#     re-running this whole script after a reboot just picks up wherever
#     the previous run left off. Expect to run this, reboot, and run it
#     again at least once before Hyprland is actually usable.

export ANSI_HIDE_CURSOR="\033[?25l"
export ANSI_SHOW_CURSOR="\033[?25h"

export OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
export OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
export OMARCHY_INSTALL_LOG_FILE="${OMARCHY_INSTALL_LOG_FILE:-/var/log/omarchy-install.log}"
export OMARCHY_INSTALL_USER="${OMARCHY_INSTALL_USER:-$USER}"
export OMARCHY_FIRST_INSTALL=1
export OMARCHY_ONLINE_INSTALL="${OMARCHY_ONLINE_INSTALL:-true}"
export PATH="$OMARCHY_PATH/bin:$PATH"

if [[ ! -d "$OMARCHY_INSTALL" ]]; then
  echo "❌ $OMARCHY_INSTALL not found." >&2
  echo "Run this from a cloned omadora repo in $OMARCHY_PATH." >&2
  exit 1
fi

source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if ! is_secureblue; then
  echo "❌ This entry point is for secureblue. Use install.sh instead." >&2
  exit 1
fi

# Same requirement gate install.sh uses - leaves the machine untouched on
# failure.
bash "$OMARCHY_INSTALL/preflight/guard.sh" || exit 1

if ! command -v run0 &>/dev/null; then
  echo "❌ run0 not found - is this really secureblue?" >&2
  exit 1
fi

bash "$OMARCHY_INSTALL/helpers/fedora-gum.sh"

source "$OMARCHY_INSTALL/helpers/presentation.sh"
source "$OMARCHY_INSTALL/preflight/identification.sh"

printf "%b" "$ANSI_HIDE_CURSOR"
cleanup_install() { printf "%b" "$ANSI_SHOW_CURSOR"; }
trap cleanup_install EXIT
trap 'exit 130' INT TERM

# /var/log is root-owned; creating the log file (and making it
# world-writable) needs run0, the same way install.sh's original sudo
# mkdir/touch/chmod sequence does.
run0 mkdir -p "$(dirname "$OMARCHY_INSTALL_LOG_FILE")"
run0 touch "$OMARCHY_INSTALL_LOG_FILE"
run0 chmod 666 "$OMARCHY_INSTALL_LOG_FILE" 2>/dev/null || true

# install.sh's logging model (run_logged's unconditional `</dev/null`, and
# presentation.sh's start_log_output redrawing a background tail of the log
# file over a static screen) both assume escalation never needs the real
# terminal mid-script - true for sudo, which authenticates once up front
# (see install.sh's `sudo true` + keepalive loop) and is cached for
# everything after. run0 has no such cache: every single invocation
# authenticates fresh via polkit and needs real stdin/stdout to prompt and
# read the password. So here: no `</dev/null`, no live-tail redraw, no
# per-step log-file redirect. Instead, `exec` splices this shell's own
# stdout/stderr through `tee` once, up front - output still reaches the
# real terminal exactly as if unredirected (so run0's prompt renders and
# reads normally), while a full transcript still lands in the log file for
# review, without ever touching stdin.
source "$OMARCHY_INSTALL/helpers/logging.sh"
export OMARCHY_LOG_TO_STDOUT=1
exec > >(tee -a "$OMARCHY_INSTALL_LOG_FILE") 2>&1
start_install_log

clear_logo
gum style --foreground 3 --padding "1 0 0 $PADDING_LEFT" "Installing (secureblue)..."
echo

# run_user: source a script in-process as the current user (self-escalating
# via run0 internally where needed). run_root: run a root-context script
# under run0, threading the OMARCHY_* environment through explicitly.
# Neither redirects stdin/stdout - see the comment above.
run_user() {
  local script="$1" exit_code
  omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script"
  bash -eE -c 'source "$1"' bash "$script"
  exit_code=$?
  if ((exit_code == 0)); then
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
  else
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
  fi
  return $exit_code
}

run_root() {
  local script="$1" exit_code
  omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting (root): $script"
  run0 bash -eE -c 'export OMARCHY_INSTALL="$1" OMARCHY_PATH="$2" OMARCHY_INSTALL_USER="$3" OMARCHY_FIRST_INSTALL="$4" PATH="$2/bin:$PATH"; shift 4; source "$1"' \
    _ "$OMARCHY_INSTALL" "$OMARCHY_PATH" "$OMARCHY_INSTALL_USER" "$OMARCHY_FIRST_INSTALL" "$script"
  exit_code=$?
  if ((exit_code == 0)); then
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed (root): $script"
  else
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed (root): $script (exit code: $exit_code)"
  fi
  return $exit_code
}

abort_install() {
  printf "%b" "$ANSI_SHOW_CURSOR"
  echo "❌ Install failed at: $1 (see $OMARCHY_INSTALL_LOG_FILE)" >&2
  exit 1
}

# --- Preflight ---------------------------------------------------------------
# No passwordless-installer.sh (no sudoers, no sudo), no locale.sh /
# identification's timezone/hostname pieces (already configured on this
# machine per the owner). fedora-copr.sh is called directly rather than
# through preflight/dnf.sh: the @development-tools group it also installed
# now lives in packaging/other.sh's secureblue branch instead (see that
# file and omarchy-other.packages.secureblue's header for why).
run_user "$OMARCHY_INSTALL/helpers/fedora-copr.sh" || abort_install "helpers/fedora-copr.sh (COPR setup)"

# --- Packaging ---------------------------------------------------------------
run_user "$OMARCHY_INSTALL/helpers/fedora-hyprland.sh"
run_user "$OMARCHY_INSTALL/packaging/base.sh"
run_user "$OMARCHY_INSTALL/packaging/other.sh"
run_user "$OMARCHY_INSTALL/packaging/fonts.sh"
run_user "$OMARCHY_INSTALL/helpers/fedora-manual.sh"
run_user "$OMARCHY_INSTALL/helpers/fedora-first-party.sh"
# No fedora-grub-btrfs.sh: OSTree has its own atomic rollback, see
# install/config/btrfs-snapper.sh and grub-btrfs.sh below.

# --- System configuration ----------------------------------------------------
run_root "$OMARCHY_INSTALL/config/system-files.sh"
run_root "$OMARCHY_INSTALL/config/etc-files.sh"
run_root "$OMARCHY_INSTALL/config/theme-system.sh"
echo "[Omarchy] Skipping increase-lockout-limit.sh (loosens pam_faillock; at odds with secureblue's hardening - left alone on purpose)"
run_root "$OMARCHY_INSTALL/config/lockscreen-pam.sh"
run_user "$OMARCHY_INSTALL/config/fix-powerprofilesctl-shebang.sh" # no-op here (Arch-only), kept for parity
# No docker.sh: this user runs podman instead, Docker is deliberately not
# installed at all (see omarchy-base.packages.secureblue's Containers
# section, and the matching skips in enable-services.sh/firewall.sh/
# etc-files.sh).
# No btrfs-snapper.sh / grub-btrfs.sh: both assume a mutable Btrfs root
# snapshotted by snapper + GRUB menu entries. rpm-ostree rollback already
# covers this; a second snapshot scheme on top would fight it.
run_root "$OMARCHY_INSTALL/config/enable-services.sh"
run_root "$OMARCHY_INSTALL/config/firewall.sh"
run_user "$OMARCHY_INSTALL/config/console-font.sh"

# --- Hardware (self-gating; Intel-relevant leaves only, see hardware/all.sh) -
omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting (root): omarchy-apply-hardware"
run0 bash -eE -c 'export OMARCHY_PATH="$1" OMARCHY_INSTALL="$2" OMARCHY_INSTALL_USER="$3"; export PATH="$OMARCHY_PATH/bin:$PATH"; exec omarchy-apply-hardware --install-user "$3"' \
  _ "$OMARCHY_PATH" "$OMARCHY_INSTALL" "$OMARCHY_INSTALL_USER" >>"$OMARCHY_INSTALL_LOG_FILE" 2>&1 ||
  omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: omarchy-apply-hardware reported an error (continuing)"

# --- User configs and finalization -------------------------------------------
run_user "$OMARCHY_INSTALL/config/config.sh"
run_user "$OMARCHY_INSTALL/config/xdg-user-dirs.sh"
# No timezone-detection.sh: already configured on this machine.
run_user "$OMARCHY_INSTALL/config/zsh.sh"
run_user "$OMARCHY_INSTALL/config/lazyvim.sh"
omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: omarchy-finalize-user"
omarchy-finalize-user --first-install </dev/null >>"$OMARCHY_INSTALL_LOG_FILE" 2>&1 ||
  omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: omarchy-finalize-user reported an error (continuing)"

# --- Login (SDDM) -------------------------------------------------------------
# SDDM is already secureblue's active display manager - login/sddm.sh's
# secureblue branch reviews/adjusts its config rather than installing it
# fresh. No dracut.sh: OSTree regenerates its own initramfs; a raw `dracut
# --force` against /boot/initramfs-<kver>.img doesn't match how that works.
run_user "$OMARCHY_INSTALL/login/sddm.sh"

# --- Post-install ------------------------------------------------------------
run_root "$OMARCHY_INSTALL/post-install/udev.sh"
run_root "$OMARCHY_INSTALL/post-install/localdb.sh"
# No hibernation.sh: built entirely around Limine + mkinitcpio, 100% dead
# code on Fedora/GRUB/BLS today regardless of distro.

stop_install_log

printf "%b" "$ANSI_SHOW_CURSOR"

echo
echo "=========================================================================="
echo " First pass complete."
echo
echo " If this is the first time hyprland/hyprland-uwsm were installed above,"
echo " that package is only layered for the *next* boot - rpm-ostree needs a"
echo " reboot before the binary actually exists. Re-run this script after"
echo " rebooting: already-installed packages are skipped automatically, and"
echo " it will pick up from wherever this run left off."
echo
echo " Once hyprland-uwsm shows up at the SDDM login screen, log in there."
echo " Your existing Sway session is untouched and still selectable if"
echo " something's wrong."
echo "=========================================================================="
