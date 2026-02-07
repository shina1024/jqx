#!/usr/bin/env bash
set -euo pipefail
filter="$1"
if [ "${2-}" != "" ]; then
  moon run --target native cmd -- "$filter" "$2"
  exit 0
fi
json=""
if [ ! -t 0 ]; then
  json="$(cat)"
fi
moon run --target native cmd -- "$filter" "$json"
