# Validation record

Date: September 21, 2026.

## Executed in the authoring workspace

- Portable C signal-processing tests passed: dominant-frequency detection and RMS at 8, 44.1, 48, and 96 kHz; bass/high-frequency tones; silence and signal decay; stereo planar/interleaved equivalence; reset behavior; NaN/Inf handling; concurrent snapshot/reset access.
- The same signal-processing tests passed under AddressSanitizer and UndefinedBehaviorSanitizer. Leak detection was unavailable under the host’s process tracing, so it is not claimed.
- All Swift source files were parsed with the tree-sitter Swift grammar without syntax error nodes. This is **syntax checking**, not Swift type checking.
- The browser preview’s embedded JavaScript passed `node --check`.
- Xcode project structure, source/resource membership, plist and scheme XML, and app-icon dimensions were checked using independent parsers and file inspection.

## Not executed

- `xcodebuild`, Swift type checking against Apple SDKs, simulator launch, device installation, native UI rendering, Instruments, and on-device audio routing. The workspace runs Linux and has no Xcode/Apple SDKs.
- MusicKit account authorization, catalog playback, device microphone permission, and ScreenCaptureKit capture. These require a configured Apple environment and account/device access.
- Visual browser QA: the cloud browser rejected local-file navigation under its security policy. The HTML preview is included, but no browser-rendered screenshot or visual-verification claim is made.

The project includes `Scripts/build-apple.sh` and `Docs/Device-Checklist.md` so the remaining checks are concrete and reproducible on a Mac. The package should be treated as an implementation ready for an Apple build-and-test pass, not as a tested production release.
