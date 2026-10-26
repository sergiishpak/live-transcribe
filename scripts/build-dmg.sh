#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

"$root/scripts/build-app.sh"
version="$(python3 "$root/scripts/version.py")"
dmg="dist/Live-Transcribe-$version-arm64.dmg"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/live-transcribe-dmg.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
stage="$scratch/content"
mkdir "$stage"

ditto "dist/Live Transcribe.app" "$stage/Live Transcribe.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/Read Me First.txt" <<'EOF'
Live Transcribe — English captions for your Mac's system audio

INSTALL
Drag Live Transcribe onto Applications, eject this disk, and open the
installed app. Requires an Apple Silicon Mac. The declared minimum is
macOS 14.2; see the guide below for tested compatibility.

OPENING
An ad-hoc-signed build is not notarized. If macOS blocks an unidentified
developer, try opening once, then go to System Settings > Privacy &
Security > Open Anyway, if you choose to trust this project's download.
Managed Macs may disallow this. Do not disable Gatekeeper globally.

FIRST RUN
Allow internet access for the speech model (about 600 MB in a previous
check). Wait for Ready, click Start, and allow macOS system-audio capture.
Play English speech on your Mac. Your microphone is not captured.
Once cached, the model can transcribe locally without internet access.

COPY BEFORE QUITTING
The app does not save transcripts or audio recordings. Copy any text you
want to keep before quitting. Stop keeps the text in the current window.

HELP AND SOURCE
https://github.com/sergiishpak/live-transcribe
https://github.com/sergiishpak/live-transcribe/blob/main/docs/INSTALL.md

LICENSES
In Finder, choose Show Package Contents on the app, then open
Contents/Resources/Licenses for the MIT license and third-party notices.
EOF

# Leave any previous DMG intact if creation fails partway through.
hdiutil create -quiet -volname "Live Transcribe $version" -fs HFS+ \
    -srcfolder "$stage" -format UDZO "$scratch/release.dmg"
mv -f "$scratch/release.dmg" "$dmg"
(
    cd dist
    shasum -a 256 "${dmg:t}" > "${dmg:t}.sha256"
)
"$root/scripts/check-release.sh"
print "Ready: $dmg and $dmg.sha256"
