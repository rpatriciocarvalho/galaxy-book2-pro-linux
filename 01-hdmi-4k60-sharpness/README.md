# Blurry text on a 4K monitor at 60 Hz over HDMI

## System
- Samsung Galaxy Book2 Pro 15" (950XEE), Intel Alder Lake-P (Iris Xe, i915 driver) + Arc A350M
- Fedora, kernel 7.3, GNOME Wayland, 150% scaling
- 4K monitor over HDMI (EDID advertises HDMI 2.0, max TMDS 600 MHz, 4:2:0 support)

## Symptom
Text with blurry edges and color fringes at 4K 60 Hz; sharp at 30 Hz. On Windows 11, 4K60 looked perfect.

## Cause
- `i915_display_info` at 60 Hz: mode with a 594000 pixel clock, but `port_clock=297000` and the scaler
  active, meaning the output is **YCbCr 4:2:0** (color at 1/4 of the resolution, which ruins text).
- Samsung's VBT (the BIOS video table) limits the HDMI port (dvo_port 20 / DDI TC4)
  to `hdmi_max_data_rate = 4` (**340 MHz**). i915 honors that limit; 4K60 RGB needs 594 MHz,
  so it falls back to 4:2:0. At 30 Hz (297 MHz) RGB 4:4:4 fits.
- The Windows driver ignores this limit, which is why it worked there.

## Fix
A copy of the VBT with a single field changed: on the HDMI output, `hdmi_max_data_rate` goes from
4 (340 MHz) to 3 (**594 MHz**). Everything else stays the same, including the level shifter (9).
The BIOS is not modified: the driver just loads this copy instead of the factory table.
On the tested unit, the change is the byte at offset `0x1de`: `0x89 -> 0x69`.

The VBT files are **not in the repository** (they are Samsung firmware).
Each person generates their own from their machine:

```bash
# 1. Extract the factory VBT and generate the patched copy (vbt_original.bin and vbt_hdmi594.bin in this folder)
sudo bash generate_vbt.sh

# 2. Install and enable it
sudo bash apply_vbt.sh

# 3. Reboot and set the monitor to 3840x2160 @ 60 Hz
```

`generate_vbt.sh`:
- reads the VBT in use by i915 (`/sys/kernel/debug/dri/*/i915_vbt`);
- looks for native HDMI outputs (TMDS, without the "not HDMI" flag) and shows the current limit of each one;
- changes only the ones not already at 594 MHz;
- refuses to run if an alternative VBT is already loaded, because then the driver would expose that VBT instead of the factory one;
- also accepts an already-extracted file: `bash generate_vbt.sh vbt.bin` (no root needed).

`apply_vbt.sh` installs:
- `/lib/firmware/i915/vbt_hdmi594.bin`
- `/etc/dracut.conf.d/i915-vbt.conf` (includes the file in the initramfs)
- the kernel parameter `i915.vbt_firmware=i915/vbt_hdmi594.bin` (via grubby)

Revert: `sudo bash apply_vbt.sh --revert` and reboot.

## Verify
```
sudo grep port_clock /sys/kernel/debug/dri/0000:00:02.0/i915_display_info
```
At 4K60, the correct value is `port_clock=594000` (it was `297000` before the fix).

## Notes
- New kernels inherit the parameter (grubby `ALL`, and dracut includes the file).
- After a BIOS update (the factory VBT may change): `sudo bash apply_vbt.sh --revert`,
  reboot, then run `sudo bash generate_vbt.sh` and `sudo bash apply_vbt.sh` again.
- Emergency (no picture): in GRUB, press `e`, remove `i915.vbt_firmware=...`, `Ctrl+X`.
- The scripts use `grubby` and `dracut` (Fedora). On other distributions, copy `vbt_hdmi594.bin`
  to `/lib/firmware/i915/`, include it in the initramfs and add the kernel parameter with your own tools.
