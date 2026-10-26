# Installation and troubleshooting

## Compatibility

The initial download is for **Apple Silicon (M-series) Macs** and recognizes **English** speech. Intel Macs and other languages are outside the initial release scope.

The Swift package declares macOS **14.2** as its minimum, matching the Core Audio process-tap API. This is not a claim that every intervening macOS release has been tested. The release-preparation build and controlled audio check were run on an M3 Pro with macOS **27.0.1**; the [earlier benchmark](benchmarks/2026-09-11-m3-pro.md) records a separate configuration and result.

First launch needs internet access, disk space for approximately 600 MB of model downloads plus compiled model caches, and time for model preparation. No API key or account is required. There is no established minimum RAM requirement beyond testing on an M3 Pro with 18 GB of memory.

## Install

1. Download `Live-Transcribe-<version>-arm64.dmg` from [GitHub Releases](https://github.com/sergiishpak/live-transcribe/releases/latest).
2. Open the disk image and drag **Live Transcribe** onto the **Applications** shortcut.
3. Eject the disk image and open **Live Transcribe** from Applications.

When updating, quit the previous app before replacing it. Transcripts are not saved, so copy anything you need before quitting.

## Opening the initial release

The initial release is **ad-hoc signed, without an Apple Developer ID, and not notarized**. macOS may say it cannot verify the developer or check the app for malicious software.

If you downloaded it from this project’s release page and choose to open it:

1. Try opening the app once, then dismiss the block message.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the security message about Live Transcribe and choose **Open Anyway**.
4. Confirm and authenticate if macOS asks, then open the app again.

These steps follow [Apple’s instructions for opening apps from an unidentified developer](https://support.apple.com/en-us/102445). On managed Macs, your administrator may disallow the override. If macOS reports actual malware or a damaged app, do not treat that as the same warning: verify the download or build from source. There is no need to disable Gatekeeper globally.

## First launch and audio permission

Wait for **Preparing model…** to become **Ready**. The model downloads automatically from Hugging Face. This can take several minutes on first launch; the app currently shows a preparation status rather than a percentage.

Click **Start**, then allow the system-audio recording permission requested by macOS. The relevant Privacy & Security section may be called **Screen & System Audio Recording** or **Screen Recording**, depending on your macOS version. The app uses an audio-only Core Audio tap; it does not capture the screen or microphone.

Play English speech through your Mac. The capture includes the system mix, so overlapping apps can interfere with recognition.

## Troubleshooting

| Symptom | What to try |
| --- | --- |
| **Preparing model…** takes a long time | Keep the app open and check your internet connection and free disk space. The first run downloads and prepares the model. |
| **Model preparation failed** | Check internet access to Hugging Face, then click **Retry**. Model loading may download missing files again. |
| **System audio capture failed** or no speech appears | Check the app’s audio-recording permission in Privacy & Security, quit and reopen it if permission changed, then play audible English speech and click **Start**. |
| Only the other person in a call appears | The app captures system playback, not your microphone. This is expected. |
| **Catching up** | Reduce competing workload. **Skip to Live** drops pending audio and inserts a visible skip marker. |
| Text does not scroll to the newest words | Click **Jump to Live**. Scrolling away or selecting text can pause following. |
| Recognition is wrong | Reduce overlapping speech or music. English speech is the supported input; results still need checking. |

If the cache appears corrupted after retrying, quit the app and locate `~/Library/Application Support/FluidAudio/Models/` in Finder using **Go → Go to Folder**. Move only the `parakeet-unified-en-0.6b` folder aside, then reopen the app to download it again. This cache may be shared with other FluidAudio apps; leave other models alone.

## Verify a download

Download the matching `.dmg.sha256` file into the same folder as the DMG, then run:

```sh
shasum -a 256 -c Live-Transcribe-0.1.1-arm64.dmg.sha256
```

An `OK` result checks that your DMG matches that checksum. A checksum from the same release is an integrity check, not Apple notarization or independent proof of the publisher’s identity.

## Uninstall

Quit the app and remove **Live Transcribe.app** from Applications. The downloaded model cache remains under the path above and may be shared with other apps. Transcripts are not saved by Live Transcribe.

## Reporting a problem

Open a [GitHub issue](https://github.com/sergiishpak/live-transcribe/issues) with your app version, macOS version, Mac chip, and the exact error or steps. Avoid attaching private recordings or transcripts. Reports and fixes are handled as time permits.
