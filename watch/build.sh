#!/usr/bin/env sh
set -eu

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
KEY_PATH=${CONNECTIQ_DEVELOPER_KEY:-}
MONKEYC=${MONKEYC:-monkeyc}

if [ -z "$KEY_PATH" ] || [ ! -f "$KEY_PATH" ]; then
    echo "Set CONNECTIQ_DEVELOPER_KEY to an existing Garmin developer key." >&2
    exit 2
fi

mkdir -p "$PROJECT_DIR/build"
exec "$MONKEYC" \
    -f "$PROJECT_DIR/monkey.jungle" \
    -d fr245m \
    -o "$PROJECT_DIR/build/PulseLink.prg" \
    -y "$KEY_PATH" \
    -r \
    -w \
    "$@"
