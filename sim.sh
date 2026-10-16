#!/usr/bin/env zsh
set -euo pipefail

DEVICE="${1:-venu3}"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
KEY_FILE="${CIQ_KEY_PATH:-$HOME/.garmin/developer_key.der}"

if [[ ! -f "$SDK_CFG" ]]; then
  echo "Error: Garmin Connect IQ SDK config not found at: $SDK_CFG" >&2
  exit 1
fi

SDK_BIN="$(cat "$SDK_CFG")/bin"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "Error: Developer key not found at: $KEY_FILE" >&2
  exit 1
fi

# Start Connect IQ Simulator if not already running
if ! pgrep -qf "ConnectIQ.app"; then
  "$SDK_BIN/connectiq" &
  sleep 3
fi

mkdir -p "$ROOT_DIR/bin"
PRG_FILE="$ROOT_DIR/bin/MinimalCharge-${DEVICE}.prg"

echo "Building Minimal Charge for device: $DEVICE ..."
"$SDK_BIN/monkeyc" \
  -d "$DEVICE" \
  -f "$ROOT_DIR/monkey.jungle" \
  -o "$PRG_FILE" \
  -y "$KEY_FILE" \
  -l 3

echo "Launching $DEVICE in Connect IQ Simulator ..."
"$SDK_BIN/monkeydo" "$PRG_FILE" "$DEVICE"
