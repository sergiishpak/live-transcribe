# Third-party notices

The [MIT license](LICENSE) covers Live Transcribe’s own code. It does not replace the licenses of the components below.

| Component | Version / source | License |
| --- | --- | --- |
| FluidAudio | 0.15.7, revision [`41540ea`](https://github.com/FluidInference/FluidAudio/tree/41540ea237350afe5117a082b5c28eda642d0612) | Apache 2.0 |
| fastcluster and VBx components | Notices supplied by the pinned FluidAudio checkout | BSD-style and Apache 2.0 |
| NemoTextProcessing / text-processing-rs | [`v0.3.0`](https://github.com/FluidInference/text-processing-rs/tree/v0.3.0), prebuilt native library linked by FluidAudio | Apache 2.0, with native dependency and Rust runtime notices |
| Parakeet Unified EN 0.6B CoreML | [FluidInference model repository](https://huggingface.co/FluidInference/parakeet-unified-en-0.6b-coreml), downloaded separately | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

The speech model is based on NVIDIA’s Parakeet model, with CoreML conversion and Swift integration by the FluidInference team. Live Transcribe downloads the upstream model without modifying its weights. The model is not bundled in the app or DMG. Its own terms and attribution apply separately from this app’s code license.

## License texts and provenance

- [Complete third-party license texts and notices](licenses/ThirdPartyNotices.txt), including the pinned upstream notices and native Rust dependencies.
- [Source/version/checksum inventory](licenses/provenance.json), distinguishing native runtime components from upstream build tools.
- [Inventory scope and maintenance notes](licenses/README.md).

The complete notices are also shipped inside the app at `Contents/Resources/Licenses/`. In Finder, choose **Show Package Contents** on Live Transcribe.app to read them.

FluidAudio’s unused LuxTTS resource bundle and speech-model weights are excluded from this app package. The notice inventory conservatively covers native dependency artifacts and does not claim that every listed component survives linker dead stripping or executes during transcription. Upstream build-tool notices are identified separately.
