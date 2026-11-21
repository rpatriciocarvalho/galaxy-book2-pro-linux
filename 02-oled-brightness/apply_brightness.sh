#!/bin/bash
# OLED screen brightness on the Galaxy Book2 Pro (i915): force the Intel DPCD brightness interface
# Usage: sudo bash apply_brightness.sh           -> apply
#        sudo bash apply_brightness.sh --revert  -> undo
set -e
ARG="i915.enable_dpcd_backlight=3"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo." >&2
    exit 1
fi

if [ "$1" = "--revert" ]; then
    grubby --update-kernel=ALL --remove-args="$ARG"
    echo "Reverted. Reboot."
    exit 0
fi
grubby --update-kernel=ALL --remove-args="i915.enable_dpcd_backlight"
grubby --update-kernel=ALL --args="$ARG"
echo "Applied. Reboot."
