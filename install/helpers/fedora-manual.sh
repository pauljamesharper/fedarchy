#!/bin/bash
# Fedora manual install steps for Omarchy
# Installs packages not available in Fedora repos or COPR

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"
source "$OMARCHY_INSTALL/helpers/distro-secureblue.sh"
if is_secureblue; then ESC=run0; else ESC=sudo; fi

if ! is_fedora; then
  exit 0
fi

# 0. Enable Flathub remote (required for Flatpak installs)
#
# Everything Flatpak here stays in the user installation. dnf pulls flatpak in during this same run,
# and its system repository under /var/lib/flatpak is only created on the next boot - so a system
# scoped install during a fresh Omarchy install fails with "opening repo: No such file or directory"
# and leaves the apps missing. --user needs no such repository, and no sudo either.
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# 1. lazydocker - skipped entirely on secureblue: this user runs podman
# instead, Docker (and its tooling) is deliberately not installed at all.
if is_secureblue; then
  :
elif ! command -v lazydocker &>/dev/null; then
  echo "Installing lazydocker (GitHub binary)..."
  OS_NAME=$(uname -s)
  ARCH_NAME=$(uname -m)
  case "$ARCH_NAME" in
    aarch64) ARCH_NAME="arm64" ;;
    x86_64) ARCH_NAME="x86_64" ;;
  esac

  latest_tag=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -1)

  if [[ -z "$latest_tag" ]]; then
    echo "[WARN] Could not determine lazydocker latest version, skipping..."
  else
    LAZYDOCKER_URL="https://github.com/jesseduffield/lazydocker/releases/download/${latest_tag}/lazydocker_${latest_tag#v}_${OS_NAME}_${ARCH_NAME}.tar.gz"

    tmpdir=$(mktemp -d)
    if curl -fL "$LAZYDOCKER_URL" -o "$tmpdir/lazydocker.tar.gz" && tar -xzf "$tmpdir/lazydocker.tar.gz" -C "$tmpdir"; then
      $ESC mv "$tmpdir/lazydocker" /usr/local/bin/
      $ESC chmod +x /usr/local/bin/lazydocker
    else
      echo "[WARN] Failed to install lazydocker, skipping..."
    fi
    rm -rf "$tmpdir"
  fi
fi

# 2. terminaltexteffects (tte) - for install animations
if ! command -v tte &>/dev/null; then
  echo "Installing terminaltexteffects (pip)..."
  pip3 install --user terminaltexteffects
fi

# 3. mise (brew on secureblue - it's a plain CLI tool with a formula, no
# reason to reach for its own curl|bash installer instead)
if is_secureblue; then
  if ! command -v mise &>/dev/null; then
    echo "Installing mise (brew)..."
    command -v brew &>/dev/null && brew install mise
  fi
elif ! command -v mise &>/dev/null; then
  echo "Installing mise (install script)..."
  curl https://mise.jdx.dev/install.sh | bash
fi

# 4. typora (Flatpak)
if ! command -v typora &>/dev/null && ! flatpak info io.typora.Typora &>/dev/null; then
  echo "Installing typora (Flatpak)..."
  flatpak install -y --user flathub io.typora.Typora
fi

# 5. localsend (Flatpak)
if ! command -v localsend &>/dev/null && ! flatpak info org.localsend.localsend_app &>/dev/null; then
  echo "Installing localsend (Flatpak)..."
  flatpak install -y --user flathub org.localsend.localsend_app
fi

# 5b. obsidian (Flatpak) - quattro preinstalls it; Fedora has no obsidian rpm
if ! command -v obsidian &>/dev/null && ! flatpak info md.obsidian.Obsidian &>/dev/null; then
  echo "Installing obsidian (Flatpak)..."
  flatpak install -y --user flathub md.obsidian.Obsidian || echo "[WARN] Optional obsidian install failed, continuing..."
fi

# 5c. moonlight (Flatpak) - quattro preinstalls moonlight-qt; Fedora has no aarch64 rpm
if ! command -v moonlight &>/dev/null && ! flatpak info com.moonlight_stream.Moonlight &>/dev/null; then
  echo "Installing moonlight (Flatpak)..."
  flatpak install -y --user flathub com.moonlight_stream.Moonlight || echo "[WARN] Optional moonlight install failed, continuing..."
fi

# 6. JetBrainsMono Nerd Font - the Quickshell shell, foot and the SDDM theme all render with
# "JetBrainsMono Nerd Font", and Fedora only packages the plain jetbrains-mono-fonts (no glyphs).
if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
  echo "Installing JetBrainsMono Nerd Font (nerd-fonts release)..."
  nf_tag=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -1)
  if [[ -z "$nf_tag" ]]; then
    echo "[WARN] Could not determine nerd-fonts latest version, skipping..."
  else
    tmpdir=$(mktemp -d)
    if curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/${nf_tag}/JetBrainsMono.tar.xz" -o "$tmpdir/JetBrainsMono.tar.xz" &&
      mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd" &&
      tar -xJf "$tmpdir/JetBrainsMono.tar.xz" -C "$HOME/.local/share/fonts/JetBrainsMonoNerd"; then
      fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    else
      echo "[WARN] Failed to install JetBrainsMono Nerd Font, skipping..."
    fi
    rm -rf "$tmpdir"
  fi
fi

# 6b. starship (fallback if package install missed it - base.sh already
# installs it via brew on secureblue, see omarchy-base.packages.secureblue)
if ! command -v starship &>/dev/null; then
  echo "Installing starship (fallback path)..."
  if is_secureblue; then
    command -v brew &>/dev/null && brew install starship
  elif dnf list --available starship &>/dev/null; then
    sudo dnf install -y starship || true
  fi

  if ! command -v starship &>/dev/null && command -v cargo &>/dev/null; then
    cargo install --locked starship || echo "[WARN] starship fallback install failed, continuing..."
  fi
fi

# 6c. eza (optional - base.sh already installs it via brew on secureblue)
if ! command -v eza &>/dev/null; then
  if is_secureblue; then
    echo "Installing eza (optional)..."
    command -v brew &>/dev/null && brew install eza
  elif dnf list --available eza &>/dev/null; then
    echo "Installing eza (optional)..."
    sudo dnf install -y eza || echo "[WARN] Optional eza install failed, continuing..."
  fi

  if ! command -v eza &>/dev/null && command -v cargo &>/dev/null; then
    echo "Installing eza via cargo (fallback path)..."
    cargo install --locked eza || echo "[WARN] Optional eza cargo install failed, continuing..."
  fi

  if ! command -v eza &>/dev/null; then
    echo "[INFO] Optional eza package is unavailable"
  fi
fi

echo "Fedora manual install steps complete."
