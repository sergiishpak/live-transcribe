# Live Transcribe for macOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local macOS app that turns live system audio into selectable English text with low display latency.

**Architecture:** A Swift Package provides a native SwiftUI executable and focused testable state types. A private Core Audio process tap feeds `AVAudioPCMBuffer` values to FluidAudio's 160 ms Parakeet EOU streaming actor, and an `NSTextView` bridge displays committed plus provisional text without disrupting selection.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Core Audio, AVFoundation, Core ML, FluidAudio.

**Spec:** `docs/superpowers/specs/2026-09-11-live-transcribe-design.md`

## Global Constraints

- Target macOS 14.2 or later on Apple Silicon.
- Use only native Apple frameworks plus FluidAudio; no driver, virtual audio device, cloud transcription, database, or settings window.
- Capture the system mix only; do not request microphone permission or retain audio after processing.
- Use FluidAudio Parakeet EOU at 160 ms chunks and keep the model loaded while the app runs.
- Use native selectable text with Command-A and Command-C, pause follow mode during selection or manual scrolling, and preserve in-memory text across Stop/Start.
- Persist only window frame and Always on Top preference.

---

## File structure

| Path | Responsibility |
| --- | --- |
| `Package.swift` | Declares the executable, tests, macOS platform, and FluidAudio dependency. |
| `Sources/LiveTranscribe/App.swift` | Launches the SwiftUI app and restores window preferences. |
| `Sources/LiveTranscribe/AppModel.swift` | Owns readiness, capture session, transcript, and user actions. |
| `Sources/LiveTranscribe/Transcript.swift` | Testable committed/provisional transcript and backlog state. |
| `Sources/LiveTranscribe/TranscriptTextView.swift` | AppKit text view bridge with follow-mode behavior. |
| `Sources/LiveTranscribe/SystemAudioCapture.swift` | Owns Core Audio tap, aggregate device, IOProc, and audio callback. |
| `Sources/LiveTranscribe/StreamingTranscriber.swift` | Loads and drives FluidAudio's streaming model. |
| `Sources/LiveTranscribe/MainView.swift` | The single-window controls and status UI. |
| `Resources/Info.plist` | Declares the system-audio capture purpose string only. |
| `scripts/build-app.sh` | Produces and ad-hoc-signs `dist/Live Transcribe.app` from the SwiftPM executable. |
| `Tests/LiveTranscribeTests/*.swift` | XCTest coverage for transcript and backlog rules. |

### Task 1: Bootstrap the runnable app and test target

**Files:**
- Create: `Package.swift`
- Create: `Sources/LiveTranscribe/App.swift`
- Create: `Resources/Info.plist`
- Create: `scripts/build-app.sh`
- Create: `Tests/LiveTranscribeTests/LiveTranscribeTests.swift`

**Interfaces:**
- Produces the `LiveTranscribe` executable and `LiveTranscribeTests` XCTest target.
- `@main struct LiveTranscribeApp: App` is the executable entry point.

- [ ] **Step 1: Write the failing package test**

```swift
import XCTest
@testable import LiveTranscribe

final class LiveTranscribeTests: XCTestCase {
    func testPackageExposesAppModule() {
        XCTAssertEqual(appDisplayName, "Live Transcribe")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails because the module does not exist**

Run: `swift test`

Expected: FAIL because `LiveTranscribe` cannot be imported.

- [ ] **Step 3: Add the smallest package, entry point, and local bundle builder**

```swift
// Sources/LiveTranscribe/App.swift
import SwiftUI

let appDisplayName = "Live Transcribe"

@main
struct LiveTranscribeApp: App {
    var body: some Scene { WindowGroup(appDisplayName) { Text("Preparing…") } }
}
```

```bash
#!/bin/zsh
set -euo pipefail
swift build -c release
app="dist/Live Transcribe.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/LiveTranscribe "$app/Contents/MacOS/LiveTranscribe"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --deep --sign - "$app"
```

`Info.plist` contains `NSAudioCaptureUsageDescription` with the value `Live Transcribe needs system audio to display a local transcript.` and does not contain `NSMicrophoneUsageDescription`.

- [ ] **Step 4: Run build and test gates**

Run: `swift test && swift build && scripts/build-app.sh && codesign --verify --deep --strict "dist/Live Transcribe.app"`

Expected: the test passes, the package builds, and `codesign` exits 0.

- [ ] **Step 5: Commit the bootstrap**

```bash
git add Package.swift Sources/LiveTranscribe/App.swift Resources/Info.plist scripts/build-app.sh Tests/LiveTranscribeTests/LiveTranscribeTests.swift
git commit -m "feat: bootstrap live transcription app"
```

### Task 2: Add the transcript state and copy-safe native text view

**Files:**
- Create: `Sources/LiveTranscribe/Transcript.swift`
- Create: `Sources/LiveTranscribe/TranscriptTextView.swift`
- Create: `Tests/LiveTranscribeTests/TranscriptTests.swift`
- Modify: `Sources/LiveTranscribe/App.swift`

**Interfaces:**
- Produces `Transcript` with `commit(_:)`, `showPartial(_:)`, `clear()`, `displayText`, and `isBehind`.
- Produces `TranscriptTextView(text:followLive:onFollowChanged:)` for `MainView` in Task 5.

- [ ] **Step 1: Write failing behavior tests**

```swift
func testCommitMakesEarlierWordsStable() {
    var transcript = Transcript()
    transcript.showPartial("hello wor")
    transcript.commit("hello world")
    transcript.showPartial(" how are")
    XCTAssertEqual(transcript.displayText, "hello world how are")
}

func testClearRemovesCommittedAndPartialText() {
    var transcript = Transcript(committed: "keep", partial: " this")
    transcript.clear()
    XCTAssertEqual(transcript.displayText, "")
}
```

- [ ] **Step 2: Run the tests to verify they fail because `Transcript` is unavailable**

Run: `swift test --filter TranscriptTests`

Expected: FAIL with `cannot find 'Transcript' in scope`.

- [ ] **Step 3: Implement the transcript as one value type and wrap `NSTextView` directly**

```swift
struct Transcript: Equatable {
    private(set) var committed = ""
    private(set) var partial = ""
    var displayText: String { committed + partial }
    mutating func showPartial(_ text: String) { partial = text.isEmpty ? "" : " " + text }
    mutating func commit(_ text: String) { committed = text; partial = "" }
    mutating func clear() { committed = ""; partial = "" }
}
```

The text view must be editable only for selection, use `isSelectable = true`, keep standard text commands enabled, and scroll to the end only when `followLive` is true and there is no active selection.

- [ ] **Step 4: Run focused and full tests**

Run: `swift test --filter TranscriptTests && swift test`

Expected: all tests pass.

- [ ] **Step 5: Commit transcript behavior**

```bash
git add Sources/LiveTranscribe/Transcript.swift Sources/LiveTranscribe/TranscriptTextView.swift Sources/LiveTranscribe/App.swift Tests/LiveTranscribeTests/TranscriptTests.swift
git commit -m "feat: add copy-safe live transcript"
```

### Task 3: Add one local streaming-transcription service

**Files:**
- Create: `Sources/LiveTranscribe/StreamingTranscriber.swift`
- Create: `Tests/LiveTranscribeTests/BacklogTests.swift`
- Modify: `Package.swift`

**Interfaces:**
- Consumes `AVAudioPCMBuffer` and callbacks `@MainActor (String, Bool) -> Void`.
- Produces `final class StreamingTranscriber` with `prepare(onUpdate:)`, `append(_:)`, `finish()`, and `skipToLive()`.

- [ ] **Step 1: Write failing backlog tests**

```swift
func testBacklogBecomesBehindAfterTwoSecondsOfAudio() {
    var backlog = AudioBacklog()
    backlog.enqueue(seconds: 2.1)
    XCTAssertTrue(backlog.isBehind)
}

func testSkipToLiveClearsPendingAudioAndMarksTheGap() {
    var backlog = AudioBacklog()
    backlog.enqueue(seconds: 3)
    XCTAssertEqual(backlog.skipToLiveMarker, "[Skipped 3.0s to return to live]")
    XCTAssertFalse(backlog.isBehind)
}
```

- [ ] **Step 2: Run the test to verify it fails because `AudioBacklog` is unavailable**

Run: `swift test --filter BacklogTests`

Expected: FAIL with `cannot find 'AudioBacklog' in scope`.

- [ ] **Step 3: Implement the fixed 160 ms Parakeet EOU integration**

```swift
let manager = StreamingEouAsrManager(chunkSize: .ms160)
try await manager.loadModels()
await manager.setPartialCallback { partial in
    Task { @MainActor in onUpdate(partial, false) }
}
await manager.setEouCallback { final in
    Task { @MainActor in onUpdate(final, true) }
}
```

Queue received `AVAudioPCMBuffer` values in arrival order. On each append, call `appendAudio(_:)` and `processBufferedAudio()` in the actor. `AudioBacklog` measures queued audio duration; it reports behind above 2 seconds and is only cleared through the explicit skip action. `finish()` flushes the active stream and retains loaded models for the next Start.

- [ ] **Step 4: Run package tests and build**

Run: `swift test && swift build`

Expected: all tests pass and the executable compiles with FluidAudio linked.

- [ ] **Step 5: Commit streaming transcription**

```bash
git add Package.swift Sources/LiveTranscribe/StreamingTranscriber.swift Tests/LiveTranscribeTests/BacklogTests.swift
git commit -m "feat: add local streaming transcription"
```

### Task 4: Capture the system mix without user-managed devices

**Files:**
- Create: `Sources/LiveTranscribe/SystemAudioCapture.swift`
- Create: `Tests/LiveTranscribeTests/CaptureStateTests.swift`

**Interfaces:**
- Produces `final class SystemAudioCapture` with `start(_ onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws` and `stop()`.
- `AppModel` in Task 5 owns one capture object and passes its buffers to `StreamingTranscriber.append(_:)`.

- [ ] **Step 1: Write failing lifecycle tests for the pure ownership state**

```swift
func testStartThenStopReturnsToIdle() {
    var state = CaptureState()
    state.start(tapID: 41, aggregateID: 42)
    state.stop()
    XCTAssertEqual(state, .idle)
}
```

- [ ] **Step 2: Run the test to verify it fails because `CaptureState` is unavailable**

Run: `swift test --filter CaptureStateTests`

Expected: FAIL with `cannot find 'CaptureState' in scope`.

- [ ] **Step 3: Implement the private Core Audio tap lifecycle**

```swift
let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
description.isPrivate = true
var tapID = AudioObjectID(kAudioObjectUnknown)
try check(AudioHardwareCreateProcessTap(description, &tapID))
```

Create one private aggregate device containing the tap UID, attach an `AudioDeviceCreateIOProcIDWithBlock` callback, copy callback samples before returning, and dispatch a correctly formatted `AVAudioPCMBuffer` to `onBuffer`. In `stop()` always stop and destroy the IOProc before destroying the aggregate device and tap; each already-destroyed object is ignored. The component must not change the default output device or mute it.

- [ ] **Step 4: Run test and build gates**

Run: `swift test && swift build`

Expected: all tests pass and Core Audio symbols resolve.

- [ ] **Step 5: Commit capture support**

```bash
git add Sources/LiveTranscribe/SystemAudioCapture.swift Tests/LiveTranscribeTests/CaptureStateTests.swift
git commit -m "feat: capture system audio with a private tap"
```

### Task 5: Wire the one-window app and verify the real workflow

**Files:**
- Create: `Sources/LiveTranscribe/AppModel.swift`
- Create: `Sources/LiveTranscribe/MainView.swift`
- Modify: `Sources/LiveTranscribe/App.swift`
- Modify: `scripts/build-app.sh`

**Interfaces:**
- Consumes `SystemAudioCapture.start(_:)`, `SystemAudioCapture.stop()`, `StreamingTranscriber`, `Transcript`, and `TranscriptTextView`.
- Produces the complete user workflow through `@MainActor final class AppModel: ObservableObject`.

- [ ] **Step 1: Write a failing action test**

```swift
@MainActor
func testClearRemovesTextWithoutChangingReadyState() {
    let model = AppModel.forTesting(transcript: Transcript(committed: "hello"))
    model.clear()
    XCTAssertEqual(model.transcript.displayText, "")
    XCTAssertEqual(model.status, .ready)
}
```

- [ ] **Step 2: Run the test to verify it fails because `AppModel` is unavailable**

Run: `swift test --filter AppModelTests`

Expected: FAIL with `cannot find 'AppModel' in scope`.

- [ ] **Step 3: Implement only the specified controls and persistence**

```swift
Button(model.isRecording ? "Stop" : "Start") { model.toggleCapture() }
Button("Clear") { model.clear() }
Toggle("Always on Top", isOn: $model.alwaysOnTop)
if !model.followLive { Button("Jump to Live") { model.followLive = true } }
```

Prepare the model at launch. Disable Start until preparation ends. Show an error and Retry if preparation or capture fails. Persist `alwaysOnTop` and the window frame in `UserDefaults`; use `NSWindow.level = .floating` while the toggle is on. Stop preserves the transcript, Clear removes it, and the app does not write audio or transcript files.

- [ ] **Step 4: Run automated verification and build the app bundle**

Run: `swift test && swift build && scripts/build-app.sh && codesign --verify --deep --strict "dist/Live Transcribe.app"`

Expected: all unit tests pass, the package builds, and the signed app validates.

- [ ] **Step 5: Run the manual smoke test**

1. Launch `dist/Live Transcribe.app`.
2. Let the model finish preparing, start a short English video, and press Start.
3. Grant only the system-audio prompt, confirm no microphone prompt appears, and verify the output audio remains audible.
4. Confirm text appears, select a passage, copy it with Command-C, scroll away, and use Jump to Live.
5. Press Stop, then Start, confirm text appends, press Clear, then quit and reopen to confirm window preference persistence.
6. Record observed time from first spoken word to first visible text and the longest sustained delay in `docs/benchmarks/2026-09-11-m3-pro.md`.

- [ ] **Step 6: Commit the integrated app**

```bash
git add Sources/LiveTranscribe/AppModel.swift Sources/LiveTranscribe/MainView.swift Sources/LiveTranscribe/App.swift scripts/build-app.sh Tests/LiveTranscribeTests
git commit -m "feat: add live transcription window"
```

## Self-review

- Spec coverage: Tasks 1–5 cover the app bundle, permission declaration, local model, system capture, transcript behavior, interruption recovery, window preferences, backlog visibility, and manual latency measurement.
- Placeholder scan: no deferred implementation markers or vague test steps are present.
- Type consistency: Task 2 creates `Transcript`; Task 3 creates `StreamingTranscriber`; Task 4 creates `SystemAudioCapture`; Task 5 consumes those exact names.
