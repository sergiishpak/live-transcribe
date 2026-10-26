# Contributing

Live Transcribe is a personal utility shared under the MIT license. Focused bug fixes, clearer documentation, and reproducible bug reports are welcome. Maintenance is best effort; there is no promised response time or release schedule.

For a bug, include your app and macOS versions, Mac chip, reproduction steps, and the error message. Use controlled sample audio where possible and leave private recordings, transcripts, and credentials out of reports.

For a larger feature, start a GitHub issue to discuss the scope. The current focus is English system-audio transcription on Apple Silicon, with a small native interface.

Before submitting a pull request:

1. Read the [developer guide](docs/DEVELOPMENT.md).
2. Keep changes focused and run `swift test`.
3. If changing the app, run `./scripts/build-and-install.sh` and check the installed copy. This replaces the copy in `/Applications`, so save any transcript first.
4. If changing packaging or versioning, run `python3 -m unittest discover -s scripts/tests`, `./scripts/build-dmg.sh`, and `./scripts/check-release.sh`.
5. Describe what changed, why, and what you actually verified.

Do not commit `dist/`, `.build/`, local agent sessions, signing credentials, model weights, or personal transcripts. Contributions to the project’s own code are provided under its [MIT license](LICENSE); keep third-party notices intact.
