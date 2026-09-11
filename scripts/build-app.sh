#!/bin/zsh
set -euo pipefail

swift build -c release
app="dist/Live Transcribe.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/LiveTranscribe "$app/Contents/MacOS/LiveTranscribe"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --deep --sign - "$app"
