# Fedarchy — Quattro

Omarchy (DHH's Hyprland desktop) ported to Fedora. Built and used on **secureblue** — hardened,
immutable Fedora Atomic built on Fedora Sway Atomic (`rpm-ostree`, no `sudo`, only `run0`) — and it
should also work on plain **Fedora Sway Atomic** / Silverblue / Kinoite.

> ### 🆕 This is Omarchy "Quattro"
> This branch tracks **Omarchy quattro** — a major rework of the desktop. The bar, launcher,
> notifications, and OSD (waybar / walker / mako / swayosd) are replaced by a single **Quickshell**
> shell, and all Hyprland config — including every keybinding — moves to **Lua** (`.conf` → `.lua`).
> **→ See [QUATTRO-CHANGES.md](QUATTRO-CHANGES.md) for the full list of what changed.**

_This project is an extension of [Omarchy Mac](https://github.com/malik-na/omarchy-mac) project._


[![License](https://img.shields.io/github/license/malik-na/omadora)](LICENSE) [![Stars](https://img.shields.io/github/stars/malik-na/omadora?style=social)](https://github.com/malik-na/omadora/stargazers)

---

## Quick links

- Fedora Atomic Desktops: https://fedoraproject.org/atomic-desktops/
- secureblue: https://secureblue.dev/
- Omarchy: https://omarchy.org/

---

## Set up on secureblue

This assumes you already have a running secureblue system (any variant — Sway, GNOME, KDE) with
accounts, hostname, locale, and timezone already configured; see https://secureblue.dev/ if you
still need to install secureblue itself first. `install-atomic.sh` only installs the Omarchy
desktop (Hyprland + Quickshell) on top of what's already there.

Requirements:

- secureblue (x86_64), any desktop variant
- Fedora 44 or newer underneath (secureblue tracks current Fedora; check with `cat /etc/os-release`)
- A regular user, not root — the installer escalates privilege itself when it needs to
- Internet connectivity
- `git` installed

Clone and run the installer:

```bash
git clone https://github.com/pauljamesharper/fedarchy.git ~/.local/share/omarchy
cd ~/.local/share/omarchy
bash install-atomic.sh
```

A few things that behave differently here than on a normal Fedora install, because secureblue has
no `sudo` (only `run0`) and no host `dnf` (packages route through `rpm-ostree`/flatpak/brew):

- **You'll be prompted by `run0`/polkit repeatedly.** Unlike `sudo`, `run0` has no auth cache — every
  privileged step in the installer asks again. That's expected.
- **Plan on running the installer twice, with a reboot in between.** `rpm-ostree` layers a package
  (like `hyprland-uwsm`) for the *next* boot, not the current one, so the first pass can't actually
  finish setting up Hyprland. The installer is written to be safely re-run: it skips anything already
  done and picks up where it left off. Run it, reboot when it says so, then run
  `bash install-atomic.sh` again from the same directory. Once `hyprland-uwsm` shows up as a session
  option at the SDDM login screen, you're done — your previous session (e.g. Sway) is untouched and
  still selectable if something's wrong.
- **The full transcript is logged** to `/var/log/omarchy-install.log` if you need to check what a
  step actually did.

### The post-install step

Near the end of each pass, the installer runs two small root-context scripts under
`install/post-install/`:

- `udev.sh` runs `udevadm control --reload` and re-triggers `power_supply` events, so udev rules
  shipped by the packages just installed take effect in the *current* session immediately, instead
  of waiting for the next reboot to be noticed.
- `localdb.sh` runs `updatedb`, so `locate` can find the files the installer just wrote right away
  instead of waiting for its next scheduled run.

Both are idempotent and safe to run on every pass, including the repeat run after rebooting.

### Fedora Sway Atomic (plain atomic Fedora)

The same `install-atomic.sh` entry point should also work on plain atomic Fedora spins that aren't
secureblue-hardened — Fedora Sway Atomic, Silverblue, Kinoite. It already detects this
automatically (`is_secureblue`/`is_ostree` in `install/helpers/distro-secureblue.sh`) and switches
from `run0` to a normal `sudo` prompt-once-then-keepalive flow — the same approach `install.sh`
uses on mutable Fedora — so no manual editing between `sudo` and `run0` should be needed. That said,
this fork has mainly been exercised on secureblue itself; treat the plain-atomic-Fedora branch as
probably-working-but-less-proven until confirmed on your own machine, and if privilege escalation
ever picks the wrong tool, `install/helpers/distro-secureblue.sh` is where that decision is made.

---

## Post-install tasks

- On secureblue/atomic Fedora, make sure you've completed the reboot-and-rerun cycle described
  above before expecting a working session.
- Reboot and log into your Hyprland session.
- Press `Cmd + K`  to learn all the Keybindings. 
- Validate core desktop behavior: app launcher opens, terminal keybind works, Wi-Fi/Bluetooth menus open, and lock screen works.

## Troubleshooting and FAQ

### Installer refuses to continue

`install-atomic.sh` requires secureblue or plain atomic Fedora (Silverblue/Kinoite/Sway Atomic) on
x86_64. Verify distro/architecture and rerun.

On a Fedora release older than 44, the installer, `omarchy-update`, and `omarchy-migrate` all stop
on purpose and print the upgrade steps. Upgrade Fedora to 44 first, then re-run.

### Session launches but keybinds fail

Run this to confirm Omarchy commands resolve in your login shell:

```bash
bash -lc 'echo "$PATH"'
bash -lc 'command -v omarchy-menu omarchy-cmd-terminal-cwd uwsm-app'
```

---

## Update and maintenance

- `Menu > Update > Omarchy` pulls the Omarchy repository, runs any pending migrations, and updates system packages — `dnf upgrade --refresh` on mutable Fedora, `rpm-ostree upgrade` on secureblue/atomic Fedora (see below).
- It also covers what the package manager can't reach: the `--user` Flatpak apps (Obsidian, Moonlight), the npx-wrapped CLI tools, and the mise runtimes. `DEPENDENCIES.md` lists every external source and the mechanism that updates it.
- Update availability is tracked as git divergence from your configured upstream branch.

Check branch/upstream state:

```bash
git -C ~/.local/share/omarchy status -sb
```

---

## Fedora Sway Atomic / secureblue: update pipeline fix

On a secureblue (Fedora Sway Atomic, hardened) machine, `Menu > Update > Omarchy` failed
immediately with `sudo: command not found` while "Updating time..." was printing. secureblue
ships no `sudo` at all (privilege escalation goes through `run0` instead) and shadows the host
`dnf` (package changes route through `rpm-ostree`/flatpak/brew), so two scripts in the update
pipeline that assumed a mutable-Fedora `sudo dnf` world broke outright:

- `bin/omarchy-update-time` called `sudo systemctl restart systemd-timesyncd` unconditionally.
- `bin/omarchy-update-system-pkgs` called `sudo dnf upgrade -y --refresh` / `sudo dnf autoremove -y`
  unconditionally.

Both now branch on `is_secureblue`/`is_ostree` (from `install/helpers/distro-secureblue.sh` and
`install/helpers/packages.sh`, the same helpers the rest of the codebase's secureblue migrations
already use): `omarchy-update-time` picks `run0` or `sudo` for the escalation, and
`omarchy-update-system-pkgs` goes through the existing `omarchy_update_system` abstraction, which
resolves to `rpm-ostree upgrade -y` on any OSTree deployment and to `sudo dnf upgrade` elsewhere;
the `dnf autoremove` step is skipped on OSTree, which has no equivalent concept.

Because both checks are automatic, these two scripts already do the right thing on plain Fedora
Sway Atomic (non-secureblue, still `sudo`-capable) with no edits needed there. What genuinely
still needs porting: a large number of other `bin/omarchy-*` scripts call `sudo` directly and
haven't been run through this same `is_secureblue`/`is_ostree` check yet, so other commands can
still hit the same "sudo: command not found" failure on secureblue until they're updated the same
way (see the `migrations/*.sh` files for the established pattern).

This fix was scoped and applied by Claude Code from a screenshot of the failing update dialog and
a plain-language description of the problem, in one interactive session. The reporter's own
review of the change was "vibe coded" — accepted on the strength of the explanation and a
successful test run, not independently verified line by line — so treat this section as
unverified until it's been confirmed on a second secureblue machine.

## Support

Need help or want to share your setup?

- Discord: https://discord.gg/jdqjcPxxJe
- Support the project: [![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/malik2015no)

---

## External resources

- External monitor discussion: https://github.com/malik-na/omarchy-mac-fedora/discussions/73

---

## Acknowledgements

Thanks to DHH for Omarchy, to the Omadora developer for this fork, and to the Fedora project for
the base this all runs on.

If this project helped you, please star the repository and share feedback on X by tagging [@tiredkebab](https://x.com/tiredkebab).

---
