# Third-party notice inventory

`ThirdPartyNotices.txt` preserves upstream license and notice texts. `provenance.json` records the source versions, archive hashes, and classifications used when preparing this distribution on 2026-10-26.

## Source evidence

- FluidAudio 0.15.7 is pinned in `Package.resolved` at `41540ea237350afe5117a082b5c28eda642d0612`.
- Its NemoTextProcessing binary points to the `text-processing-rs` v0.3.0 XCFramework. That upstream build enables `ffi,fst-engine`.
- The native production dependency graph was derived from that tag’s manifests, lockfile, build scripts, and macOS archive. Thirty native dependency versions and seven separately identified build/proc-macro tools are covered. Crate archive checksums were verified against the pinned lockfile.
- The archive identifies Rust 1.97.0 at `2d8144b7880597b6e6d3dfd63a9a9efae3f533d3`. Seven additional runtime crate versions were verified against its library lockfile. Rust, stdarch, compiler-builtins, and embedded libm notices are retained.
- The rustfst crate omits license files, so those texts were recovered from its exact recorded VCS revision. The compiler-builtins combined notice was verified against the exact vendored Rust source.
- The model card declares CC BY 4.0. The notices credit NVIDIA and FluidInference and link the source and license; model files are downloaded separately.

## Bounds

This is a conservative source/build/archive inventory, not an upstream SBOM or proof of exact final linker retention. Native archive presence does not establish that every component is retained in the final executable. Build-tool notices are included without claiming runtime use. Root development/WASM dependencies and unsupported WASI/UEFI edges are excluded.

Only FluidAudio’s ASR path is used. Its two `Bundle.module` calls are inside LuxTTS G2P initialization, so its TTS resource bundle is deliberately omitted. Recheck resource and data licensing if the app starts using those features.

When updating FluidAudio or its native artifact, refresh this inventory from the new pinned sources and actual artifact. Do not assume these license texts describe a newer version. `scripts/check-release.sh` verifies that the package carries the repository’s complete notice directory.
