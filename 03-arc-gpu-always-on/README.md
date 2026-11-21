# Fan spinning up for no reason: dedicated Arc A350M GPU always on

## Symptom
The fan spun up easily and was constantly noisy, even with light tasks (e.g. LibreOffice Writer).
It also happened on Windows 11. Cleaning the dust and replacing the thermal paste changed nothing.

## Cause
The laptop has two GPUs:
- **Iris Xe** (integrated, `0000:00:02.0`): drives the screen, GNOME and the monitors.
- **Arc A350M** (dedicated, `0000:04:00.0`, ID `8086:5694`): should only power on when a program asks for it.

The Arc's automatic suspend was disabled:

```
/sys/bus/pci/devices/0000:04:00.0/power/control                = on   ← never suspends
/sys/bus/pci/devices/0000:04:00.0/power/runtime_status         = active
/sys/bus/pci/devices/0000:04:00.0/power/runtime_suspended_time = 0
```

The card stayed on all the time, unused, producing heat in the same cooling system as the CPU.
Any extra load was enough to make the fan spin up.

## Fix
Enable the Arc's automatic suspend (runtime PM): `power/control = auto`.
It then enters **D3cold** (electrically powered off) when idle and wakes up on its own when
a program needs it (e.g. games, `DRI_PRIME=1`).

To persist across reboots, a udev rule (`99-intel-arc-runtime-pm.rules`) applies this every time
the card appears or the driver binds to it.

```bash
sudo bash apply_gpu_pm.sh           # apply (takes effect immediately and on future boots)
sudo bash apply_gpu_pm.sh --revert  # undo
```

Temporary test, without installing anything (back to normal after a reboot):

```bash
echo auto | sudo tee /sys/bus/pci/devices/0000:04:00.0/power/control
```

## Result

| Sensor | Before (idle) | After (idle) | After (Impress + Firefox playing Full HD video + IntelliJ + terminal) |
|---|---|---|---|
| Board (acpitz) | 62 °C | 51 °C | 50 °C |
| CPU (TCPU) | 56 °C | 50 °C | 49 °C |

The fan is noticeably quieter.

## Verify
```bash
D=/sys/bus/pci/devices/0000:04:00.0
cat $D/power/control $D/power/runtime_status $D/power_state
# expected: auto / suspended / D3cold
```

## Notes
- The Arc may wake up for a few seconds when a program enumerates the GPUs on startup (Firefox, IntelliJ…)
  and goes back to sleep on its own. That's normal.
- The same applies to all GNOME power modes (Power Saver / Balanced / Performance):
  no `tuned` profile touches the Arc's `power/control`.
- **Steam:** the package's launcher (`steam.desktop`) has `PrefersNonDefaultGPU=true`, so GNOME starts
  all of Steam on the Arc (`DRI_PRIME=pci-0000_04_00_0`). The Steam window uses the dedicated GPU, which
  stays on **while Steam is open**, even with no game running and minimized to the tray. Games use the
  Arc without any configuration. After quitting Steam (Steam menu → Exit), the Arc returns to D3cold within seconds.
  Alternative (not adopted here): copy the launcher to `~/.local/share/applications/` with
  `PrefersNonDefaultGPU=false` (Steam on the Iris Xe) and use `DRI_PRIME=1 %command%` in the launch
  options of each game that should run on the Arc.
- The fan sensor (`acpi_fan`) returns a read error on Linux; the evaluation was done by temperature and by ear.
- Ruled out: ACPI interrupt storm (common on Galaxy Books). Here the SCI rate was ~4/s, which is normal.
- Extra tweak if you want even less noise: the Samsung `quiet` profile (`/sys/firmware/acpi/platform_profile`),
  the same as "Silent mode" in Samsung Settings on Windows. On Fedora it is selected by GNOME's
  "Power Saver" mode (via `tuned-ppd`): no turbo, ~1.4 GHz max, ~49 °C.
