#!/bin/bash
# Extracts this machine's VBT (the BIOS video table) and generates a patched copy
# that unlocks 594 MHz (HDMI 2.0) on the HDMI port.
#
# Usage:
#   sudo bash generate_vbt.sh           -> reads the VBT in use by the i915 driver
#   bash generate_vbt.sh <vbt_file>     -> uses an already-extracted VBT (no root needed)
#
# Generates, in this folder:
#   vbt_original.bin   copy of the factory VBT
#   vbt_hdmi594.bin    patched VBT, used by apply_vbt.sh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$1"

if [ -z "$SRC" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        echo "Run with sudo, or pass a VBT file as an argument." >&2
        exit 1
    fi
    if grep -q 'i915.vbt_firmware=' /proc/cmdline; then
        echo "An alternative VBT is already loaded (i915.vbt_firmware on the kernel command line)." >&2
        echo "The driver would expose that VBT, not the factory one. Revert with" >&2
        echo "'sudo bash apply_vbt.sh --revert', reboot and run this script again." >&2
        exit 1
    fi
    SRC=$(ls /sys/kernel/debug/dri/*/i915_vbt 2>/dev/null | head -1)
    if [ -z "$SRC" ]; then
        echo "i915_vbt not found in debugfs. Is the i915 driver in use?" >&2
        exit 1
    fi
fi

python3 -I - "$SRC" "$DIR/vbt_original.bin" "$DIR/vbt_hdmi594.bin" <<'EOF'
import sys, struct

src, out_orig, out_fix = sys.argv[1:4]
d = bytearray(open(src, 'rb').read())

if not d.startswith(b'$VBT'):
    sys.exit("File does not look like a VBT (missing $VBT signature).")
bdb = d.find(b'BIOS_DATA_BLOCK')
if bdb < 0:
    sys.exit("BDB not found in the VBT.")
ver, hsz, bsz = struct.unpack_from('<HHH', d, bdb + 16)
print(f"VBT: {d[5:20].decode(errors='ignore').strip()}, BDB version {ver}")
if ver < 228:
    sys.exit("BDB older than version 228: the 594 MHz value does not exist in this format.")

RATES = {0: 'platform default', 1: '297 MHz', 2: '165 MHz', 3: '594 MHz', 4: '340 MHz', 5: '300 MHz'}
TMDS, NOT_HDMI = 1 << 4, 1 << 11
RATE_594 = 3

orig = bytes(d)
changed = 0
p = bdb + hsz
while p < bdb + bsz:
    bid = d[p]
    sz = struct.unpack_from('<H', d, p + 1)[0]
    base = p + 3
    if bid == 2:  # General Definitions: list of outputs (child devices)
        csz = d[base + 4]
        off = base + 5
        while off + csz <= base + sz:
            handle, dtype = struct.unpack_from('<HH', d, off)
            if dtype and (dtype & TMDS) and not (dtype & NOT_HDMI):
                port = d[off + 16]
                cur = d[off + 7] >> 5
                print(f"HDMI output: handle={handle:#x} dvo_port={port} "
                      f"current limit={RATES.get(cur, cur)}")
                if cur != RATE_594:
                    d[off + 7] = (d[off + 7] & 0x1F) | (RATE_594 << 5)
                    print(f"  offset {off + 7:#x}: {orig[off + 7]:#04x} -> {d[off + 7]:#04x} (594 MHz)")
                    changed += 1
            off += csz
    p += 3 + sz

if not changed:
    sys.exit("No HDMI output needed changing. Nothing was generated.")

open(out_orig, 'wb').write(orig)
open(out_fix, 'wb').write(d)
print(f"\nGenerated:\n  {out_orig}\n  {out_fix}")
EOF

echo "Now apply it with: sudo bash \"$DIR/apply_vbt.sh\""
