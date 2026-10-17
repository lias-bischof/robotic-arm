#!/bin/sh
set -eu
cd "$(dirname "$0")"
export PATH="/opt/homebrew/sbin:/opt/homebrew/bin:/usr/local/sbin:$PATH"
make
if ! command -v mosquitto >/dev/null; then
    echo 'Mosquitto fehlt: brew install mosquitto cjson' >&2
    exit 1
fi
cleanup() {
    if [ -n "${bridge_pid:-}" ]; then
        kill "$bridge_pid" 2>/dev/null || true
        wait "$bridge_pid" 2>/dev/null || true
    fi
    kill "$broker_pid" 2>/dev/null || true
    wait "$broker_pid" 2>/dev/null || true
}
mosquitto -c mosquitto.conf &
broker_pid=$!
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
sleep 1
kill -0 "$broker_pid" # Fail if another broker already owns the port.
./robot_bridge "$@" &
bridge_pid=$!
wait "$bridge_pid"
