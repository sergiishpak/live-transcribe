#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
version="$(python3 "$root/scripts/version.py")"
identity="${SIGNING_IDENTITY:--}"

if [[ "$(uname -m)" != arm64 ]]; then
    print -u2 "The initial release supports building on Apple Silicon Macs only."
    exit 1
fi

if [[ ! -f THIRD_PARTY_NOTICES.md || ! -d licenses ]]; then
    print -u2 "Third-party notices and license texts are required to package the app."
    exit 1
fi

swift build -c release --arch arm64 --force-resolved-versions
bin_dir="$(swift build -c release --arch arm64 --show-bin-path)"
app="dist/Live Transcribe.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Licenses"
cp "$bin_dir/LiveTranscribe" "$app/Contents/MacOS/LiveTranscribe"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/Licenses/"
ditto licenses "$app/Contents/Resources/Licenses/licenses"
# FluidAudio's resource bundle is TTS-only; the Unified ASR path does not access it.
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $version" "$app/Contents/Info.plist"
if [[ "$identity" == - ]]; then
    codesign --force --sign - "$app"
else
    codesign --force --options runtime --timestamp --sign "$identity" "$app"
fi
"$root/scripts/check-release.sh" --app-only
print "Built $app ($version, arm64)."
