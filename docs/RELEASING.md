# Deliberate releases

Build and test locally, then publish deliberately. Pushing a tag does not publish binaries. GitHub Actions validates changes but does not upload releases or use signing credentials.

DMGs and checksums belong in **GitHub Releases**, not Git history. The downloaded model stays outside both the DMG and the repository. The initial release target is `sergiishpak/live-transcribe`.

## Prepare a release

1. Add notes under `CHANGELOG.md` → `Unreleased`, then use the version command below. Review the new version and dated changelog section.
2. Check dependency/model attribution and bundled license texts whenever dependencies change.
3. Run:

   ```sh
   swift test --force-resolved-versions
   ./scripts/build-and-install.sh
   ./scripts/build-dmg.sh
   ```

4. Test the installed copy with controlled English system audio. Confirm model readiness, permission handling, live text, Stop/Start, Clear, sentence copy, scrolling/Jump to Live, and Always on Top. Test backlog skipping when reproducing a backlog is practical.
5. Open the DMG in Finder and inspect its app, Applications shortcut, and readme. `build-dmg.sh` also runs `check-release.sh`, which mounts the image read-only and verifies its contents, signature, arm64 architecture, version, licenses, and SHA-256 checksum.
6. For the first public release, validate on another Mac or with a fresh macOS user/model cache when available. Cached local checks do not verify first-download UX or all Gatekeeper/permission prompts.
7. Record what was actually tested in `docs/releases/<version>.md`. The current notes are drafted in [releases/0.1.1.md](releases/0.1.1.md).

Build outputs:

```text
dist/Live Transcribe.app
dist/Live-Transcribe-<version>-arm64.dmg
dist/Live-Transcribe-<version>-arm64.dmg.sha256
```

## Semantic versioning

`VERSION` is the single source of truth. Stable releases use [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`, with no leading zeroes. This project currently accepts stable release numbers only, without prerelease or build-metadata suffixes.

- **patch**: compatible fixes and release/packaging maintenance, for example `0.1.0 → 0.1.1`.
- **minor**: compatible new functionality; resets the patch component, for example `0.1.1 → 0.2.0`.
- **major**: incompatible changes to documented workflows or supported integrations; resets minor and patch, for example `0.2.0 → 1.0.0`.

Version `0.x` denotes initial development and does not promise a stable compatibility contract. The user-facing contract is the behavior and compatibility described in the README and installation guide.

```sh
./scripts/version.py                   # show and validate the current version
./scripts/version.py patch --dry-run   # preview without changing files
./scripts/version.py patch             # or minor / major
```

Bumping moves the Unreleased notes into a dated changelog section and updates `VERSION`. It requires release notes, preserves earlier entries, and never commits, tags, builds, or publishes automatically. Python 3 is required for the version command and build scripts.

The build inserts that version into both macOS app version fields. The DMG filename, mounted volume name, and checksum filename use the same validated value. The source Info.plist deliberately contains no duplicated release version. Rebuild after bumping; older DMGs remain separate files in `dist/`.

## Signing status

The default build uses **ad-hoc signing**. This detects changes to the signed bundle but does not establish an Apple-verified publisher identity. It is **not notarized**. Describe that explicitly in the release notes and link the [opening instructions](INSTALL.md#opening-the-initial-release).

No valid Developer ID Application identity was available during initial release preparation. Do not label the download “Apple verified” or notarized.

### If Developer ID signing becomes available

The app builder accepts an explicit identity:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/build-dmg.sh
```

This enables hardened runtime and a signing timestamp for the app. A successful signing command alone does **not** notarize it. The Developer ID/notarization path is documented for future use and has not been exercised for the initial build.

With a separately configured `notarytool` keychain profile, notarize and staple the **app before building the final DMG**, then submit/staple the final DMG if distributing it with a notarization ticket. The current DMG script rebuilds the app, so a notarized release needs an intentional packaging update to preserve the stapled app. Recalculate checksums after any stapling. Keep credentials in Keychain or GitHub secrets, never in this repository.

Use Apple’s [notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [requirements](https://developer.apple.com/documentation/security/resolving-common-notarization-issues) when adding that workflow. Validate with `stapler validate` and `spctl --assess`; `codesign --verify` alone is not a Gatekeeper acceptance check.

## Publish after review

Commit the reviewed source, notices, scripts, icon, documentation, `VERSION`, and `Package.resolved`. Add the maintainer’s demo video link to the README when available. Preserve the existing commits; exclude generated output, signing material, local agent sessions, and personal data. Push the repository and wait for GitHub Actions to pass.

For the initial import, publish the reviewed branch as `main` so the documentation links resolve. Keep its existing commit ancestry; an empty GitHub repository does not require a fresh local history. Check `git status --short` before tagging to ensure that the tested source is committed.

Once the tested artifact matches the reviewed commit, create its version tag and a draft release:

```sh
version="$(./scripts/version.py)"
git tag -a "v$version" -m "Live Transcribe $version"
git push origin "v$version"
gh release create "v$version" \
  "dist/Live-Transcribe-$version-arm64.dmg" \
  "dist/Live-Transcribe-$version-arm64.dmg.sha256" \
  --repo sergiishpak/live-transcribe \
  --verify-tag --draft --title "Live Transcribe $version" \
  --notes-file "docs/releases/$version.md"
```

Review the draft and both attached assets before publishing it in GitHub. Open the public download link and verify the downloaded checksum.
