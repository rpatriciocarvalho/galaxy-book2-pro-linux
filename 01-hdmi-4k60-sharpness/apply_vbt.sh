#!/bin/bash
# Unlocks 594 MHz (HDMI 2.0) on the HDMI port of the Galaxy Book2 Pro (i915 / Alder Lake-P)
# Usage: sudo bash apply_vbt.sh           -> apply
#        sudo bash apply_vbt.sh --revert  -> undo
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
FW=/lib/firmware/i915/vbt_hdmi594.bin
DRACUT=/etc/dracut.conf.d/i915-vbt.conf
ARG="i915.vbt_firmware=i915/vbt_hdmi594.bin"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo." >&2
    exit 1
fi

if [ "$1" = "--revert" ]; then
    grubby --update-kernel=ALL --remove-args="$ARG"
    rm -f "$FW" "$DRACUT"
    dracut -f --regenerate-all
    echo "Reverted. Reboot."
    exit 0
fi

if [ ! -f "$DIR/vbt_hdmi594.bin" ]; then
    echo "vbt_hdmi594.bin not found. Generate it first with: sudo bash \"$DIR/generate_vbt.sh\"" >&2
    exit 1
fi
install -m 0644 "$DIR/vbt_hdmi594.bin" "$FW"
echo "install_items+=\" $FW \"" > "$DRACUT"
dracut -f --regenerate-all
grubby --update-kernel=ALL --args="$ARG"
echo "Applied. Reboot and set the monitor to 3840x2160 @ 60 Hz."
