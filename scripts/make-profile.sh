#!/usr/bin/env bash
# Turn a probe capture (RTX30-PROBE/RUNxx/{REPORT.TXT,PROM.BIN}) into RTX-UNLOCK/PROFILE.BIN
# using the upstream tools. The profile is specific to YOUR card; never reuse someone else's.
# usage: make-profile.sh <path/to/RUNxx> <usb-root>
set -euo pipefail
RUN=${1:?RUNxx dir}; USB=${2:?usb root}
WORK=${WORK:-$PWD/build-src}
TMP=$(mktemp -d)
python3 "$WORK/tools/probe-to-profile.py" --report "$RUN/REPORT.TXT" --prom "$RUN/PROM.BIN" --output "$TMP/board.json"
grep -q '"deviceId": "2488"' "$TMP/board.json" || { echo "Refusing: probe target is not 10de:2488" >&2; exit 3; }
python3 "$WORK/tools/runtime_profile.py" "$TMP/board.json" --output "$USB/RTX-UNLOCK/PROFILE.BIN"
echo "Wrote $USB/RTX-UNLOCK/PROFILE.BIN (board.json kept at $TMP/board.json for review)"
