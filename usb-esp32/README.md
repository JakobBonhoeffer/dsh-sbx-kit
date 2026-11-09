# usb-esp32 (optional mixin, untested)

> **Status: untested.** This mixin was written from the kit specification. It has
> not been applied to a sandbox with a board attached, and it is not verified
> that `sbx` forwards USB devices on every host OS. Treat it as a starting point.

A capability-only mixin that asks the host to pass common ESP32 USB-serial
bridges through to the sandbox and adds the `agent` user to the `dialout` group.
Every device entry is `optional: true`, so entries without a matching device are
skipped.

| Chip | VID:PID |
|---|---|
| Silicon Labs CP210x | `10c4:ea60` |
| WCH CH340 | `1a86:7523` |
| WCH CH9102 | `1a86:55d4` |
| FTDI FT232 | `0403:6001` |
| Espressif native USB (JTAG/CDC) | `303a:1001` |
| Espressif ROM download mode | `303a:0002` |

## Try it

1. Back up the state inside the sandbox first. Adding a kit **recreates the
   container**, so anything outside the mounted folders can be lost:
   ```bash
   cp -a ~/.dsh /path/to/a/mounted/folder/dsh-backup
   ```
2. Plug in the board and close programs that hold its COM port. Check the
   VID:PID on the host (PowerShell):
   ```powershell
   Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VID_(10C4|1A86|0403|303A)' } | Select FriendlyName, InstanceId
   ```
3. Add the mixin to an existing sandbox (host):
   ```powershell
   sbx kit add <name> .\usb-esp32
   sbx run --name <name>
   ```
4. Check inside the sandbox: `lsusb`, `ls -l /dev/ttyUSB* /dev/ttyACM*`, `id`,
   `esptool chip-id`. Use only `chip-id` for a first test, not `write-flash`.

If the device is missing in `lsusb`, the optional entry was skipped. A possible
fallback (also untested) is to run `esp_rfc2217_server` on the host and use
`esptool --port rfc2217://...` in the sandbox. That needs a network rule that
allows the sandbox to reach the host port.
