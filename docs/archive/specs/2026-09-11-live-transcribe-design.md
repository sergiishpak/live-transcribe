# Live Transcribe for macOS — Design

> Historical design, retained for context. It describes an earlier model and intended behavior. Use the [current developer guide](../../DEVELOPMENT.md) for the implemented architecture.

## Goal

Build a personal macOS utility that displays local, English-only transcription of live system audio quickly enough to copy passages into an agent chat while a call or video is playing.

## Scope

The first release is a single native macOS app. It captures the system mix only; it does not capture the microphone, record audio, save transcripts, create virtual audio devices, or require the user to select a source application.

The app asks macOS for its system-audio capture permission when the user starts capture. Internally it may create and remove the private Core Audio objects required by Apple's process-tap API; this is invisible to the user and requires no manual audio routing or driver installation.

## User experience

On launch, the app downloads and prepares its on-device speech model if it is not already cached. The main window shows a clear readiness state: Preparing, Ready, Recording, or an actionable error.

The window is small and resizable. It contains Start/Stop, Clear, an Always on Top toggle, a selectable transcript, and a Jump to Live control when the reader is away from the bottom. Window size, position, and the Always on Top preference persist across launches.

Start begins system-audio capture when the model is ready. Stop ends capture and preserves the in-memory transcript. A later Start appends to it. Clear empties the transcript. No transcript or audio is retained after the app quits.

The transcript uses native selectable text, so Command-A and Command-C work normally. It follows live output while the reader remains at the bottom. Scrolling away or selecting text pauses automatic scrolling without pausing capture; Jump to Live resumes it. Only the newest phrase may be revised by recognition; committed text never changes.

If work cannot keep up, the app reports that it is behind. It preserves short backlogs. When necessary, the user can choose Skip to Live; the transcript visibly marks the skipped interval. The app never silently drops audio.

## Architecture

The application is SwiftUI for window state and a wrapped `NSTextView` for native selection and scroll control. A small app coordinator owns the model lifecycle and connects capture, conversion, transcription, and the transcript store.

`SystemAudioCapture` creates a private Core Audio process tap and aggregate device, receives mixed system-audio buffers, and releases both reliably when stopped. `AudioResampler` converts incoming audio to the 16 kHz mono Float32 samples required by the model. `StreamingTranscriber` owns the selected FluidAudio model, produces committed and provisional text, and exposes backlog state. `TranscriptStore` applies those updates without invalidating the user's current selection or scroll position.

The first implementation uses FluidAudio's cache-aware Parakeet EOU streaming model with 160 ms chunks because immediate readable text is the primary requirement. It remains fully local after the initial model download. Parakeet TDT v2 is a quality reference, not the default live engine, because FluidAudio documents v2 as batch transcription. A benchmark harness records time to first visible text, ongoing display delay, and the observed transcript on representative English call and video clips; it is used to validate the model choice on this M3 Pro Mac.

## Data flow

```text
System audio
  -> private Core Audio process tap
  -> 16 kHz mono Float32 resampler
  -> 160 ms streaming transcription chunks
  -> committed text + revisable trailing text
  -> native selectable transcript view
```

## Errors and recovery

If permission is denied, the app names the macOS Privacy & Security location to enable system-audio capture and leaves Start available after the user changes it. A model download failure exposes retry and does not start capture. Capture, conversion, or inference failures stop the active session, preserve text already produced, destroy tap resources, and show a retryable error.

## Acceptance criteria

- The project builds as a signed local macOS app targeting macOS 14.2 or later on Apple Silicon.
- Its first run requires only the normal system-audio permission, not a microphone permission, virtual device, or driver.
- It captures audible system audio from a call or video, not the local microphone.
- It shows local English transcription in a selectable, copyable, resizable window and preserves user selection while new text arrives.
- It can stop, resume, clear, pause follow mode, return to live, and retain window preferences as specified above.
- The model is prepared before Start and remains loaded while the app runs.
- On the M3 Pro test machine, the benchmark reports time to first visible text and sustained display delay; the target is roughly one second or less during continuous speech. A result above the target is a measured limitation, not hidden by the UI.

## Constraints

- macOS 14.2 or later; this machine runs macOS 26.6.2 on Apple M3 Pro.
- Swift 6 and native Apple frameworks; FluidAudio supplies the on-device ASR model.
- English only. No accounts, cloud transcription, recording, history, diarization, translation, summaries, or settings window.
