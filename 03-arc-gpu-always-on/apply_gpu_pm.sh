#!/bin/bash
# Galaxy Book2 Pro: let the dedicated Intel Arc A350M GPU sleep when it is not in use
# Usage: sudo bash apply_gpu_pm.sh           -> apply
#        sudo bash apply_gpu_pm.sh --revert  -> undo
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
RULE=/etc/udev/rules.d/99-intel-arc-runtime-pm.rules

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo." >&2
    exit 1
fi

GPU=$(grep -l 0x5694 /sys/bus/pci/devices/*/device 2>/dev/null | head -1 | xargs -r dirname)

if [ "$1" = "--revert" ]; then
    rm -f "$RULE"
    udevadm control --reload
    [ -n "$GPU" ] && echo on > "$GPU/power/control"
    echo "Reverted: the Arc stays always on again."
    exit 0
fi

[ -n "$GPU" ] || { echo "Intel Arc A350M (8086:5694) not found." >&2; exit 1; }
install -m 0644 "$DIR/99-intel-arc-runtime-pm.rules" "$RULE"
udevadm control --reload
echo auto > "$GPU/power/control"
sleep 3
echo "Applied. Arc ($(basename "$GPU")): $(cat "$GPU/power/runtime_status"), $(cat "$GPU/power_state")"
