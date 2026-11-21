# CLAUDE.md

Context for Claude Code when working on this repository.
Machine-specific details (exact model, BIOS, peripherals) live in `CLAUDE.local.md`, which is not committed.

## What this repository is
Fixes to make Linux run well on the **Samsung Galaxy Book2 Pro 15" (NP950XEE)**, documented for
public sharing on GitHub. It is a personal experiment by the author to see how far Claude Code can help
solve problems found after installing Fedora (and other Linux distributions) on the laptop.

**Language:** all files in the repository are in **English**. Talk to the user in **Portuguese**.

## Hardware and system
- Samsung Galaxy Book2 Pro 15" (NP950XEE)
- Intel Core i7-1260P (Alder Lake-P), 12 cores / 16 threads
- Integrated GPU: Iris Xe `0000:00:02.0` (i915, card1). It drives the displays (eDP and HDMI).
- Dedicated GPU: Intel Arc A350M `0000:04:00.0` (`8086:5694`, i915, card0/renderD129). Render only (PRIME).
- Internal display: Samsung OLED ATNA56YX02 (eDP-1). External 4K monitor over HDMI (HDMI-A-1, DDI TC4).
- Fedora 45, kernel 7.3, GNOME 51 (Wayland), 150% scaling
- Power: `tuned` + `tuned-ppd` (GNOME modes → tuned profiles → Samsung `platform_profile` `quiet|balanced|performance`), thermald
- `samsung-galaxybook` platform driver loaded

## Fixes (all active on the system)
| # | Folder | Problem → solution | What is installed |
|---|---|---|---|
| 01 | `01-hdmi-4k60-sharpness/` | Blurry text at 4K60 over HDMI: the VBT limited HDMI to 340 MHz, so i915 used YCbCr 4:2:0 → patched VBT (594 MHz) | `/lib/firmware/i915/vbt_hdmi594.bin`, `/etc/dracut.conf.d/i915-vbt.conf`, `i915.vbt_firmware=i915/vbt_hdmi594.bin` |
| 02 | `02-oled-brightness/` | Brightness keys didn't change the OLED → Intel DPCD protocol | `i915.enable_dpcd_backlight=3` |
| 03 | `03-arc-gpu-always-on/` | Noisy fan: the Arc never suspended → runtime PM `auto` (D3cold when idle) | `/etc/udev/rules.d/99-intel-arc-runtime-pm.rules` |

Expected kernel command line: `i915.enable_psr=0 i915.vbt_firmware=i915/vbt_hdmi594.bin i915.enable_dpcd_backlight=3`
(`i915.enable_psr=0` was already there before this work).

Observed and documented behaviors:
- GNOME automatic brightness is turned off (`ambient-enabled=false`). This is the user's preference, not a bug fix:
  with it on, GNOME keeps the minimum around ~18%, which is expected behavior of the feature.
- `steam.desktop` has `PrefersNonDefaultGPU=true`: all of Steam runs on the Arc, which stays on while the Steam window draws. The user chose to keep it that way. After quitting Steam (Steam → Exit), the Arc returns to D3cold.
- Games (e.g. via Proton) run on the Arc automatically. The image is copied to the Iris Xe (Xwayland/gnome-shell).
- Power modes: Performance = governor/EPP `performance` + turbo, high clock even when idle (57–65 °C, peaks of 85 °C). Balanced = daily use. Power Saver = `quiet`, no turbo (~1.4 GHz max, ~49 °C).
- Heavy Firefox tabs keep the CPU busy. Firefox uses GPU WebRender (ok).
- Ruled out: ACPI interrupt storm (SCI ~4/s, normal). The `acpi_fan` sensor returns an I/O error (no RPM reading).

## Repository conventions
- One folder per fix, numbered: `NN-short-name/` (the next one is `04-...`).
- Each folder has:
  - `README.md` with Symptom, Cause, Fix, Verify and Notes, including numbers measured before and after;
  - an `apply_*.sh` script, run with `sudo bash`, with a `--revert` option;
  - configuration files (udev rules, etc.) when needed.
- Each new fix gets a row in the "Fixes" table of the root `README.md` (and in "Kernel parameters used", if applicable).
- No personal data (names, e-mail, `/home/<user>` paths) and no data that identifies the specific machine
  (full SKU with region suffix, BIOS version/date, serial numbers, peripheral models) in committed files.
- No Samsung firmware in the repository: `*.bin` is in `.gitignore`. The VBT is generated on the machine with `01-hdmi-4k60-sharpness/generate_vbt.sh`.
- MIT license ("galaxy-book2-pro-linux contributors").
- **Never commit or push unless the user asks.**

## How to work with the user
- Diagnose with evidence (sysfs, debugfs, logs) before proposing a fix. Show the numbers.
- Test temporarily first (e.g. write to sysfs, kernel parameter via GRUB `e` for a single boot). Only make it permanent and document it **after the user confirms it worked**.
- Commands that need root: the user runs them (`sudo` asks for a password). To read root-only files, ask the user to copy them to a readable folder (e.g. `sudo cp ... && sudo chown <user> ...`).

## Useful diagnostics
```bash
cat /proc/cmdline
sudo cat /sys/kernel/debug/dri/0000:00:02.0/i915_display_info   # output format/clock (port_clock)
D=/sys/bus/pci/devices/0000:04:00.0; cat $D/power/control $D/power/runtime_status $D/power_state   # Arc
cat /sys/firmware/acpi/platform_profile; tuned-adm active
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference /sys/devices/system/cpu/intel_pstate/no_turbo
for z in /sys/class/thermal/thermal_zone*; do echo "$(cat $z/type): $(cat $z/temp)"; done
cat /sys/class/backlight/intel_backlight/{brightness,max_brightness}
# Per-process GPU usage: /proc/<pid>/fdinfo/* (drm-pdev, drm-engine-*)
```
