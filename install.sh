#!/usr/bin/env bash
# Installs a systemd service that disables the GPP0 ACPI wakeup source at boot,
# which stops the system waking up immediately after suspend on some boards
# (reported working on the Gigabyte B550 Aorus Pro v1.0 with firmware F16).
#
# Usage: sudo ./install.sh [--dry-run]
#   --dry-run   detect and print what would be done, change nothing (no root needed)

set -euo pipefail

SERVICE_NAME="wakeup-disable_GPP0.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
WAKEUP_FILE="${WAKEUP_FILE:-/proc/acpi/wakeup}"          # overridable for testing
BOARD_FILE="${BOARD_FILE:-/sys/class/dmi/id/board_name}"  # overridable for testing

DRY_RUN=0
case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

# --- need root unless dry-run ---
if [[ $DRY_RUN -eq 0 && $EUID -ne 0 ]]; then
    echo "Needs root, re-running with sudo..."
    exec sudo "$0" "$@"
fi

# --- detect this machine ---
board="unknown"
[[ -r $BOARD_FILE ]] && board="$(<"$BOARD_FILE")"
echo "Detected:"
echo "  Board : $board"
echo "  Kernel: $(uname -r)"

if [[ $board != *B550* ]]; then
    echo "Note: this fix was verified on a Gigabyte B550 Aorus Pro. Your board is '$board'; continuing anyway." >&2
fi

if [[ ! -r $WAKEUP_FILE ]]; then
    echo "Error: $WAKEUP_FILE not found. ACPI wakeup control is not available on this system." >&2
    exit 1
fi

line="$(grep -E '^GPP0[[:space:]]' "$WAKEUP_FILE" || true)"
if [[ -z $line ]]; then
    echo "Error: no GPP0 entry in $WAKEUP_FILE. Available wakeup sources:" >&2
    cat "$WAKEUP_FILE" >&2
    exit 1
fi
echo "  GPP0  : $line"

# --- the unit ---
# /proc/acpi/wakeup is a TOGGLE: writing a name flips its state. So only write
# when GPP0 is currently enabled, otherwise a reboot-time run would re-enable it.
read -r -d '' UNIT <<'EOF' || true
[Unit]
Description=Fix suspend by disabling the GPP0 ACPI wakeup source

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'grep -qE "^GPP0[[:space:]].*\*enabled" /proc/acpi/wakeup && echo GPP0 > /proc/acpi/wakeup || true'

[Install]
WantedBy=multi-user.target
EOF

if [[ $DRY_RUN -eq 1 ]]; then
    echo
    echo "Dry run: would write $SERVICE_PATH:"
    echo "-----"
    echo "$UNIT"
    echo "-----"
    echo "then run: systemctl daemon-reload && systemctl enable --now $SERVICE_NAME"
    exit 0
fi

# --- install ---
echo "$UNIT" > "$SERVICE_PATH"
echo "Wrote $SERVICE_PATH"
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

echo
echo "GPP0 is now: $(grep -E '^GPP0[[:space:]]' "$WAKEUP_FILE")"
echo "Try suspending now. If the system still wakes immediately, run ./uninstall.sh."
