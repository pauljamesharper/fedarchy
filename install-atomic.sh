#!/bin/bash
#
# OSTree/rpm-ostree atomic Fedora installer entry point - secureblue
# (Lenovo X1 Carbon Gen 10 and similar x86_64 Intel hardware) and plain
# atomic Fedora (Silverblue/Kinoite/Sericea - "Fedora Atomic Sway" and
# similar spins) alike. Run from an already-configured, already-running
# session - not the Fedora Asahi ISO/TTY first-boot flow install.sh
# targets. Accounts, hostname, locale, and timezone are assumed already
# set up; this only installs the Omarchy desktop (Hyprland + Quickshell)
# on top of what's already there.
#
# Two structural differences from install.sh drive everything else in this
# file, and both are secureblue-only - plain atomic Fedora has a fully
# working sudo and behaves like install.sh on both counts:
#   - secureblue has no sudo at all, only run0 (per-invocation polkit auth,
#     no keepalive/sudoers trick possible the way install.sh's
#     sudo-keepalive loop works). Plain atomic Fedora ships a real sudo and
#     a real /etc/sudoers.d, confirmed empirically (a Fedora Sway Atomic /
#     Sericea machine), so it uses install.sh's sudo + keepalive +
#     passwordless-installer.sh approach unchanged.
#   - rpm-ostree layers a package for the *next* boot, not this one, on
#     both targets - neither has a host dnf (confirmed empirically: both
#     shadow it with "Use: rpm-ostree | flatpak | toolbox"). Every step
#     below is written to be safely re-run: package installs check
#     "already installed" before acting (see packages-secureblue.sh, which
#     despite its name now serves any OSTree/atomic Fedora target, not just
#     secureblue), and re-running this whole script after a reboot just
#     picks up wherever the previous run left off. Expect to run this,
#     reboot, and run it again at least once before Hyprland is actually
#     usable.
#
# Which of the two axes above a given step cares about is is_secureblue()
# (hardening: escalation command, PAM lockout, sudoers.d, autologin) vs.
# is_ostree() (package routing, /usr read-only, no dnf/@group syntax,
# podman-not-Docker) - see install/helpers/distro-secureblue.sh.

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
if ! is_ostree; then
  echo "❌ This entry point is for OSTree/atomic Fedora (secureblue, Silverblue, Kinoite, Sericea, ...). Use install.sh instead." >&2
  exit 1
fi

# Same requirement gate install.sh uses - leaves the machine untouched on
# failure.
bash "$OMARCHY_INSTALL/preflight/guard.sh" || exit 1

if is_secureblue && ! command -v run0 &>/dev/null; then
  echo "❌ run0 not found - is this really secureblue?" >&2
  exit 1
fi

bash "$OMARCHY_INSTALL/helpers/fedora-gum.sh"

source "$OMARCHY_INSTALL/helpers/presentation.sh"
source "$OMARCHY_INSTALL/preflight/identification.sh"

printf "%b" "$ANSI_HIDE_CURSOR"

if ! is_secureblue; then
  # Plain atomic Fedora has a working sudo - the same administrator-access
  # flow install.sh uses on mutable Fedora: one prompt up front,
  # passwordless-installer.sh then drops a temporary NOPASSWD sudoers rule
  # so the rest of the install doesn't re-ask.
  echo "🔐 Omarchy installation requires administrator access..."
  if ! sudo true; then
    echo "❌ Could not obtain sudo access." >&2
    echo "   Run this as a regular user in the 'wheel' group - not with 'sudo bash install-atomic.sh'." >&2
    echo "   If an earlier run left a broken rule behind, clear it and re-check:" >&2
    echo "     sudo rm -f /etc/sudoers.d/99-omarchy-installer && sudo visudo -c" >&2
    exit 1
  fi

  keep_sudo_alive() {
    while true; do
      sudo -n -v >/dev/null 2>&1
      sleep 50
    done
  }
  keep_sudo_alive &
  SUDO_KEEPALIVE_PID=$!
fi

cleanup_install() {
  declare -F stop_log_output >/dev/null && stop_log_output
  printf "%b" "$ANSI_SHOW_CURSOR"
  if ! is_secureblue; then
    sudo rm -f /etc/sudoers.d/99-omarchy-installer 2>/dev/null || true
    kill "${SUDO_KEEPALIVE_PID:-}" 2>/dev/null || true
  fi
}
trap cleanup_install EXIT
# Without the exit, an INT trap only kills the current child and the script
# stumbles on to the next step; Ctrl+C must abort the whole install.
trap 'exit 130' INT TERM

# /var/log is root-owned; creating the log file (and making it
# world-writable) needs escalation, the same way install.sh's original
# sudo mkdir/touch/chmod sequence does.
if is_secureblue; then
  run0 mkdir -p "$(dirname "$OMARCHY_INSTALL_LOG_FILE")"
  run0 touch "$OMARCHY_INSTALL_LOG_FILE"
  run0 chmod 666 "$OMARCHY_INSTALL_LOG_FILE" 2>/dev/null || true
else
  sudo mkdir -p "$(dirname "$OMARCHY_INSTALL_LOG_FILE")"
  sudo touch "$OMARCHY_INSTALL_LOG_FILE"
  sudo chmod 666 "$OMARCHY_INSTALL_LOG_FILE"
fi

source "$OMARCHY_INSTALL/helpers/logging.sh"

if is_secureblue; then
  # install.sh's logging model (run_logged's unconditional `</dev/null`, and
  # presentation.sh's start_log_output redrawing a background tail of the
  # log file over a static screen) both assume escalation never needs the
  # real terminal mid-script - true for sudo, which authenticates once up
  # front (see the keepalive loop above) and is cached for everything
  # after. run0 has no such cache: every single invocation authenticates
  # fresh via polkit and needs real stdin/stdout to prompt and read the
  # password. So here: no `</dev/null`, no live-tail redraw, no per-step
  # log-file redirect. Instead, `exec` splices this shell's own
  # stdout/stderr through `tee` once, up front - output still reaches the
  # real terminal exactly as if unredirected (so run0's prompt renders and
  # reads normally), while a full transcript still lands in the log file
  # for review, without ever touching stdin.
  export OMARCHY_LOG_TO_STDOUT=1
  exec > >(tee -a "$OMARCHY_INSTALL_LOG_FILE") 2>&1
  start_install_log

  clear_logo
  gum style --foreground 3 --padding "1 0 0 $PADDING_LEFT" "Installing (secureblue)..."
  echo
else
  # Plain atomic Fedora has a real sudo auth cache, so install.sh's simpler
  # logging model works unchanged: run_logged redirects each step's stdout
  # into the log file, and start_log_output tails it live under the logo.
  start_install_log

  clear_logo
  gum style --foreground 3 --padding "1 0 0 $PADDING_LEFT" "Installing (atomic Fedora)..."
  echo
  start_log_output
fi

# run_user: source a script in-process as the current user (self-escalating
# via run0/sudo internally where needed). run_root: run a root-context
# script under run0 (secureblue) or sudo (plain atomic), threading the
# OMARCHY_* environment through explicitly.
if is_secureblue; then
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
else
  run_user() { run_logged "$1"; }

  run_root() {
    local script="$1" exit_code
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting (root): $script"

    if omarchy_log_to_stdout; then
      sudo bash -eE -c 'export OMARCHY_INSTALL="$1" OMARCHY_PATH="$2" OMARCHY_INSTALL_USER="$3" OMARCHY_FIRST_INSTALL="$4" PATH="$2/bin:$PATH"; shift 4; source "$1"' \
        _ "$OMARCHY_INSTALL" "$OMARCHY_PATH" "$OMARCHY_INSTALL_USER" "$OMARCHY_FIRST_INSTALL" "$script" </dev/null 2>&1
    else
      sudo bash -eE -c 'export OMARCHY_INSTALL="$1" OMARCHY_PATH="$2" OMARCHY_INSTALL_USER="$3" OMARCHY_FIRST_INSTALL="$4" PATH="$2/bin:$PATH"; shift 4; source "$1"' \
        _ "$OMARCHY_INSTALL" "$OMARCHY_PATH" "$OMARCHY_INSTALL_USER" "$OMARCHY_FIRST_INSTALL" "$script" </dev/null >>"$OMARCHY_INSTALL_LOG_FILE" 2>&1
    fi
    exit_code=$?

    if ((exit_code == 0)); then
      omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed (root): $script"
    else
      omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed (root): $script (exit code: $exit_code)"
    fi
    return $exit_code
  }
fi

abort_install() {
  declare -F stop_log_output >/dev/null && stop_log_output
  printf "%b" "$ANSI_SHOW_CURSOR"
  echo "❌ Install failed at: $1 (see $OMARCHY_INSTALL_LOG_FILE)" >&2
  # On plain atomic Fedora each step's output only goes to the log file, so
  # show the tail here - otherwise the actual rpm-ostree error is invisible.
  if ! omarchy_log_to_stdout; then
    echo >&2
    tail -n 30 "$OMARCHY_INSTALL_LOG_FILE" >&2
  fi
  exit 1
}

# --- Preflight ---------------------------------------------------------------
# No locale.sh / identification's timezone/hostname pieces (already
# configured on this machine per the owner). fedora-copr.sh is called
# directly rather than through preflight/dnf.sh: the @development-tools
# group it also installed now lives in packaging/other.sh's OSTree branch
# instead (see that file and omarchy-other.packages.secureblue's header for
# why). passwordless-installer.sh only applies to plain atomic Fedora
# (real sudo/sudoers.d) - secureblue has neither, and skips straight to
# fedora-copr.sh like before. Placed here (not before logging starts) so
# it runs through run_user/run_logged the same way install.sh runs it,
# while the sudo cache from the "administrator access" prompt above (and
# the keepalive loop already running) is still warm.
if ! is_secureblue; then
  run_user "$OMARCHY_INSTALL/preflight/passwordless-installer.sh"
fi
run_user "$OMARCHY_INSTALL/helpers/fedora-copr.sh" || abort_install "helpers/fedora-copr.sh (COPR setup)"

# --- Packaging ---------------------------------------------------------------
run_user "$OMARCHY_INSTALL/helpers/fedora-hyprland.sh" || abort_install "helpers/fedora-hyprland.sh (Hyprland core)"
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
if is_secureblue; then
  echo "[Omarchy] Skipping increase-lockout-limit.sh (loosens pam_faillock; at odds with secureblue's hardening - left alone on purpose)"
else
  run_user "$OMARCHY_INSTALL/config/increase-lockout-limit.sh"
fi
run_root "$OMARCHY_INSTALL/config/lockscreen-pam.sh"
run_user "$OMARCHY_INSTALL/config/fix-powerprofilesctl-shebang.sh" # no-op here (Arch-only), kept for parity
# No docker.sh: podman is used instead, Docker is deliberately not
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
if is_secureblue; then
  run0 bash -eE -c 'export OMARCHY_PATH="$1" OMARCHY_INSTALL="$2" OMARCHY_INSTALL_USER="$3"; export PATH="$OMARCHY_PATH/bin:$PATH"; exec omarchy-apply-hardware --install-user "$3"' \
    _ "$OMARCHY_PATH" "$OMARCHY_INSTALL" "$OMARCHY_INSTALL_USER" >>"$OMARCHY_INSTALL_LOG_FILE" 2>&1 ||
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: omarchy-apply-hardware reported an error (continuing)"
else
  sudo bash -eE -c 'export OMARCHY_PATH="$1" OMARCHY_INSTALL="$2" OMARCHY_INSTALL_USER="$3"; export PATH="$OMARCHY_PATH/bin:$PATH"; exec omarchy-apply-hardware --install-user "$3"' \
    _ "$OMARCHY_PATH" "$OMARCHY_INSTALL" "$OMARCHY_INSTALL_USER" >>"$OMARCHY_INSTALL_LOG_FILE" 2>&1 ||
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: omarchy-apply-hardware reported an error (continuing)"
fi

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
# SDDM is already the active display manager on both targets -
# login/sddm.sh reviews/adjusts its config rather than installing it
# fresh. No dracut.sh: OSTree regenerates its own initramfs; a raw `dracut
# --force` against /boot/initramfs-<kver>.img doesn't match how that
# works.
run_user "$OMARCHY_INSTALL/login/sddm.sh"

# --- Post-install ------------------------------------------------------------
run_root "$OMARCHY_INSTALL/post-install/udev.sh"
run_root "$OMARCHY_INSTALL/post-install/localdb.sh"
# No hibernation.sh: built entirely around Limine + mkinitcpio, 100% dead
# code on Fedora/GRUB/BLS today regardless of distro.

if is_secureblue; then
  stop_install_log
else
  stop_log_output
  stop_install_log
fi

printf "%b" "$ANSI_SHOW_CURSOR"

# Report where Hyprland actually stands instead of always telling the user
# to reboot and re-run: that advice loops forever when the compositor was
# never queued in the first place.
hyprland_session_installed() {
  [[ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop || -f /usr/share/wayland-sessions/hyprland.desktop ]]
}

rpm-ostree status --pending-exit-77 >/dev/null 2>&1
pending_status=$?

echo
echo "=========================================================================="
if hyprland_session_installed; then
  echo " Install complete - Hyprland is installed in the running deployment."
  echo
  echo " Log out and pick the Hyprland (uwsm) session at the SDDM login screen."
  if ((pending_status == 77)); then
    echo " A newer deployment is also staged; reboot to pick up the rest of the"
    echo " layered packages."
  fi
elif ((pending_status == 77)); then
  echo " First pass complete - Hyprland is staged for the next boot."
  echo
  echo " rpm-ostree layers packages into a new deployment, so the Hyprland"
  echo " session only appears after a reboot. Reboot now, then re-run this"
  echo " script once to finish the steps that need the new binaries."
  echo
  echo " Your existing Sway session is untouched and still selectable if"
  echo " something's wrong."
else
  echo " ❌ Hyprland is NOT installed and nothing is staged for the next boot."
  echo
  echo " Rebooting will not help. Check what rpm-ostree reported:"
  echo "   grep -n -A5 '\\[hyprland\\]' $OMARCHY_INSTALL_LOG_FILE"
  echo "   rpm-ostree status"
fi
echo "=========================================================================="
