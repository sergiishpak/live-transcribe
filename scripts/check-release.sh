#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
version="$(python3 "$root/scripts/version.py")"
app="dist/Live Transcribe.app"
app_only=false
if [[ $# == 1 && "$1" == --app-only ]]; then
    app_only=true
elif [[ $# != 0 ]]; then
    print -u2 "Usage: $0 [--app-only]"
    exit 1
fi

check_app() {
    local bundle="$1"
    local plist="$bundle/Contents/Info.plist"
    plutil -lint "$plist"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" == "$version" ]]
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")" == "$version" ]]
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")" == 14.2 ]]
    [[ "$(lipo -archs "$bundle/Contents/MacOS/LiveTranscribe")" == arm64 ]]
    [[ -s "$bundle/Contents/Resources/AppIcon.icns" ]]
    cmp LICENSE "$bundle/Contents/Resources/Licenses/LICENSE"
    cmp THIRD_PARTY_NOTICES.md "$bundle/Contents/Resources/Licenses/THIRD_PARTY_NOTICES.md"
    diff -qr licenses "$bundle/Contents/Resources/Licenses/licenses"
    codesign --verify --deep --strict "$bundle"
}

check_app "$app"
if $app_only; then
    print "App package checks passed."
    exit 0
fi

dmg="dist/Live-Transcribe-$version-arm64.dmg"
(
    cd dist
    shasum -a 256 -c "${dmg:t}.sha256"
)
hdiutil verify -quiet "$dmg"
mount_dir="$(mktemp -d "${TMPDIR:-/tmp}/live-transcribe-check.XXXXXX")"
attached=false
cleanup() {
    if $attached; then
        hdiutil detach -quiet "$mount_dir" || true
    fi
    rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount_dir" "$dmg"
attached=true
[[ -L "$mount_dir/Applications" && "$(readlink "$mount_dir/Applications")" == /Applications ]]
[[ -s "$mount_dir/Read Me First.txt" ]]
check_app "$mount_dir/Live Transcribe.app"
print "DMG checks passed (signature, architecture, version, notices, checksum, and mounted contents)."
