# Brightness keys don't change the laptop screen (OLED)

## System
- Samsung Galaxy Book2 Pro 15" (950XEE), Intel Alder Lake-P (i915 driver), Fedora, kernel 7.3, GNOME Wayland
- Internal Samsung OLED panel **ATNA56YX02** (eDP)

## Symptom
GNOME showed the brightness changing and `/sys/class/backlight/intel_backlight/brightness` changed,
but the screen itself did not. On Windows 11 brightness worked.

## Cause
OLED panels have no PWM backlight: brightness is set by sending commands to the panel over DPCD/AUX.
i915 picks the protocol based on the VBT (`enable_dpcd_backlight=-1`), and for this panel that choice
doesn't work. Tests:
- `i915.enable_dpcd_backlight=2` (VESA): **doesn't work**
- `i915.enable_dpcd_backlight=3` (Intel interface): **works**

## Fix
Kernel parameter `i915.enable_dpcd_backlight=3`, added to all kernels with grubby.

```bash
sudo bash apply_brightness.sh           # apply
sudo bash apply_brightness.sh --revert  # undo
```

Temporary test without touching the system: in GRUB, press `e`, append the parameter to the `linux` line, `Ctrl+X`.

## Verify
```bash
cat /sys/class/backlight/intel_backlight/{actual_brightness,max_brightness}
```
With the fix, `max_brightness` is `400` and the screen follows the brightness keys.

## Notes
- With `=3`, the driver's scale is 0–400 (probably the panel's nits) instead of 0–65535.
- Independent of the HDMI fix ([01-hdmi-4k60-sharpness](../01-hdmi-4k60-sharpness/)); the problem existed before it.
- On other distributions, add the parameter through your bootloader instead of using the script (which uses `grubby`).

### GNOME automatic brightness (personal preference, not a bug)
With GNOME's **automatic screen brightness** on, the lowest value reachable with the keys was
~72/400 (~18%): GNOME adjusts the brightness based on the ambient light sensor and rewrites lower
values in under 0.5 s. That is the expected behavior of the feature, not a defect.
I prefer to control brightness manually, so I turned it off; with it off, the keys cover the
full range of **4 to 400**.
```
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false   # off
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled true    # on
```
(This is the Settings → Power → "Automatic Screen Brightness" switch.)
