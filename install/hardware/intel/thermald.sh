#!/usr/bin/env bash
# Enable thermald for Intel laptops (Sandy Bridge and newer)
# Thermald is useful for Intel Sandy Bridge (2nd gen Core, model 42/45) and newer CPUs.

if omarchy-hw-intel; then
  # Check if Sandy Bridge or newer (model >= 42). Sandy Bridge: model 42 (mobile), 45 (desktop)
  cpu_model=$(grep -m1 "^model\s*:" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | tr -d ' ')
  cpu_model=${cpu_model:-0}
  if ((cpu_model >= 42)) && omarchy-battery-present; then
    omarchy-pkg-add thermald
    # No sudo: this whole file only ever runs already-root, via
    # omarchy-apply-hardware (which asserts EUID==0) - redundant on Fedora,
    # an outright failure on secureblue (no sudo binary at all).
    #
    # secureblue masks thermald.service outright (hardening baseline);
    # enabling a masked unit errors, so check first rather than fight it.
    if [[ "$(systemctl is-enabled thermald.service 2>/dev/null)" == masked ]]; then
      echo "[thermald] thermald.service is masked - leaving it alone"
    else
      systemctl enable thermald.service
    fi
  fi
fi
