#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/Live Transcribe.app"
destination="/Applications/Live Transcribe.app"

"$root/scripts/build-app.sh"

if pgrep -x LiveTranscribe >/dev/null; then
    osascript -e 'tell application id "com.sergiishpak.live-transcribe" to quit' 2>/dev/null || true
    for _ in {1..50}; do
        pgrep -x LiveTranscribe >/dev/null || break
        sleep 0.1
    done
fi

if pgrep -x LiveTranscribe >/dev/null; then
    print -u2 "Quit Live Transcribe, then run this script again."
    exit 1
fi

rm -rf "$destination"
ditto "$app" "$destination"
open "$destination"
