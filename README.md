# b550-aorus-suspend-fix

Fixes "wakes up immediately after suspend" on Linux for the **Gigabyte B550 Aorus Pro v1.0** by disabling the
`GPP0` ACPI wakeup source at every boot.

## The problem

On this board, Linux suspends and then wakes straight back up. `GPP0` is the PCIe bridge to the NVMe
drive in the M.2 slot, and it is allowed to wake the system from sleep. Turning that wake source off fixes it.

The fix comes from a community note, and I tested it on this board myself (see [Status](#status)).

## The manual fix

```bash
# 1. turn the wake source off once, then try to suspend
echo GPP0 | sudo tee /proc/acpi/wakeup

# 2. if suspend now works, make it survive reboots (this repo automates it)
```

Note: `/proc/acpi/wakeup` is a **toggle**. Writing `GPP0` flips it between `*enabled` and `*disabled`, so running
the command twice turns it back on. Check the state with `cat /proc/acpi/wakeup`.

## Install

```bash
git clone <this repo> && cd b550-aorus-suspend-fix
./install.sh --dry-run    # see what it detects and would do, changes nothing
sudo ./install.sh         # install
```

`install.sh` (asks for sudo itself):

- reads the board name from `/sys/class/dmi/id/board_name` and warns if it isn't a B550 (it continues anyway);
- stops with a clear message if `/proc/acpi/wakeup` or the `GPP0` entry doesn't exist, and lists the sources it did find;
- writes `/etc/systemd/system/wakeup-disable_GPP0.service`, then runs `systemctl daemon-reload` and
  `systemctl enable --now`.

Then try suspending.

### What the service does

```ini
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'grep -qE "^GPP0[[:space:]].*\*enabled" /proc/acpi/wakeup && echo GPP0 > /proc/acpi/wakeup || true'
```

It writes `GPP0` only when GPP0 is currently `*enabled`. Because the file is a toggle, the plain
`echo GPP0 >> /proc/acpi/wakeup` from the original note would turn the wake source back **on** if it were already
off.

## Check that it worked

```bash
cat /proc/acpi/wakeup                      # GPP0 should show *disabled
systemctl status wakeup-disable_GPP0.service
```

## Uninstall

```bash
sudo ./uninstall.sh
```

Removes the service and turns GPP0 wakeup back on if it is currently disabled.

## Status

- I tested this on Linux: disabling `GPP0` (with the service from the original community note) fixed the
  immediate wake-up on my Gigabyte B550 Aorus Pro v1.0 with firmware F16. It may behave differently on other
  firmware versions.
- `install.sh` and `uninstall.sh` came afterwards. They are checked for syntax and run in `--dry-run` against
  sample `/proc/acpi/wakeup` files; the only differences in the service are the "only if still enabled" check and
  `Type=oneshot`. They have not yet been run end to end on the real machine.
- Other boards may also have a `GPP0` entry but a different cause for the problem. If suspend still fails, run
  `./uninstall.sh`.

## License

MIT
