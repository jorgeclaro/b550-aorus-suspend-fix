#!/usr/bin/env bash
# Removes the GPP0 wakeup-disable service and puts GPP0 back to enabled.
#
# Usage: sudo ./uninstall.sh

set -euo pipefail

SERVICE_NAME="wakeup-disable_GPP0.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
WAKEUP_FILE="${WAKEUP_FILE:-/proc/acpi/wakeup}"

if [[ $EUID -ne 0 ]]; then
    echo "Needs root, re-running with sudo..."
    exec sudo "$0" "$@"
fi

if [[ -e $SERVICE_PATH ]]; then
    systemctl disable --now "$SERVICE_NAME" || true
    rm -f "$SERVICE_PATH"
    systemctl daemon-reload
    echo "Removed $SERVICE_NAME"
else
    echo "$SERVICE_NAME is not installed."
fi

# The file is a toggle: flip GPP0 back only if it is currently disabled.
if [[ -r $WAKEUP_FILE ]] && grep -qE '^GPP0[[:space:]].*\*disabled' "$WAKEUP_FILE"; then
    echo GPP0 > "$WAKEUP_FILE"
    echo "GPP0 wakeup re-enabled."
fi
