# Linux on the Samsung Galaxy Book2 Pro 15" (950XEE)

Fixes and tweaks to make Linux run well on the **Samsung Galaxy Book2 Pro 15" (NP950XEE)**.
Each fix lives in its own folder, with the diagnosis, an explanation of the cause, a script to apply
and revert it, and how to verify it.

## About this project

This is a **personal experiment**: I wanted to find out how far [Claude Code](https://claude.com/claude-code)
could help me solve the problems I noticed after installing Fedora (and other Linux distributions)
on my laptop.

**Everything in this repository was done with Claude Code**: the diagnosis (reading sysfs, debugfs
and logs), the analysis of the root causes, the scripts and this documentation. My part was
describing the symptoms, running the commands that need root, testing each change on my own
machine and confirming that it worked before it became permanent.

The [`CLAUDE.md`](CLAUDE.md) file is the context Claude Code uses when working on this repository.

## Tested environment

| Item | Details |
|---|---|
| Laptop | Samsung Galaxy Book2 Pro 15" (NP950XEE) |
| CPU / GPU | Intel Core 12th gen (Alder Lake-P), Iris Xe (i915) + Intel Arc A350M |
| Internal display | Samsung OLED ATNA56YX02 (eDP) |
| System | Fedora 45, kernel 7.3, GNOME 51 (Wayland) |
| External monitor | 4K monitor over HDMI (HDMI 2.0) |

## Fixes

| # | Problem | Cause | Solution | Status |
|---|---|---|---|---|
| 01 | [Blurry text on a 4K monitor at 60 Hz over HDMI](01-hdmi-4k60-sharpness/) | Samsung's VBT limits HDMI to 340 MHz, so i915 sends 4K60 as YCbCr 4:2:0 | The machine's own VBT patched (1 byte) by `generate_vbt.sh` and loaded with `i915.vbt_firmware` | ✅ Working |
| 02 | [Brightness keys don't change the OLED screen](02-oled-brightness/) | i915 uses the wrong protocol to control the OLED brightness over DPCD | `i915.enable_dpcd_backlight=3` | ✅ Working |
| 03 | [Fan spinning up for no reason / laptop running hot](03-arc-gpu-always-on/) | The dedicated Arc A350M GPU is always on (runtime PM disabled) | udev rule setting `power/control=auto`: the Arc powers off (D3cold) when idle | ✅ Working |

## How to use

1. Read the fix's `README.md` and make sure your problem and your hardware are the same.
2. Follow the steps in the folder. Usually: `sudo bash apply_*.sh` and reboot.
   Fix 01 has an extra step first (`sudo bash generate_vbt.sh`), which generates the VBT from your own machine.
3. To undo: `sudo bash apply_*.sh --revert` and reboot.

Before making a kernel parameter permanent, you can test it for a single boot:
in the GRUB menu press `e`, append the parameter to the end of the `linux` line and boot with `Ctrl+X`.

**Other distributions:** the scripts were written for Fedora (`grubby` for kernel parameters,
`dracut` for the initramfs). On other distributions the fixes are the same, but add the kernel
parameters through your bootloader (e.g. `GRUB_CMDLINE_LINUX` in `/etc/default/grub`,
or systemd-boot entries) and include the VBT file in the initramfs with your distribution's tool.

## Kernel parameters used

```
i915.vbt_firmware=i915/vbt_hdmi594.bin   # fix 01
i915.enable_dpcd_backlight=3             # fix 02
```

To check the active parameters: `cat /proc/cmdline`.

## Useful diagnostic tools

```bash
# Video output state (format, clock): requires root
sudo cat /sys/kernel/debug/dri/0000:00:02.0/i915_display_info

# VBT in use (the BIOS video table)
sudo cat /sys/kernel/debug/dri/0000:00:02.0/i915_vbt > vbt.bin

# Internal display brightness
cat /sys/class/backlight/intel_backlight/{brightness,max_brightness}

# Dedicated GPU (Arc) power state
D=/sys/bus/pci/devices/0000:04:00.0; cat $D/power/control $D/power/runtime_status $D/power_state
```

## Disclaimer

These fixes change video driver parameters and use a modified copy of the manufacturer's VBT.
They were only tested on the hardware above. Use them at your own risk and always keep a way to
revert (the scripts have `--revert`, and kernel parameters can be removed from GRUB in an emergency).

No Samsung firmware is distributed here: the VBT is extracted and patched on each person's own machine.

## License

[MIT](LICENSE)
