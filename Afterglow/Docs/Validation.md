# Validation record

## September 22, 2026 — restored project and Tron theme

The original 50-file Afterglow archive was recovered from the September 21
**Build music visualizer app** conversation and restored to this repository.

Executed on an Apple silicon Mac:

- Existing C audio-processing tests pass (`bash Scripts/test-dsp.sh`).
- New native Tron tests pass (`bash Scripts/test-tron.sh` with `AFTERGLOW_TEST_SDK` set to the installed macOS 26.5 SDK): legacy settings migration, all nine mode/color round-trips, 40,000 disc-boundary/continuity samples across five aspect ratios, 1,200 cycle trails across corners and route seams, and bounded circuit geometry through 1,000,000 simulated seconds.
- The complete native Mac Swift source passes `swiftc -typecheck -swift-version 5`, targeting arm64/macOS 14 with the installed macOS 26.5 SDK and the existing C bridging header. This also exposed two pre-existing catch-block assignments in `StudioModel`; both now correctly assign `self.error`.
- The regenerated Xcode project passes `plutil -lint` and includes the new renderer, geometry, settings, and control files in both app targets.
- The browser preview was served on localhost and visually inspected in Chrome: all three Tron modes, all nine mode/color selections, saved selections after reload, and the 390 × 844 phone layout. No browser error logs were reported during those checks.

Still outstanding:

- Xcode build/link, simulator run, device installation, native UI rendering, and Instruments. Xcode 27 is installed but its license has not yet been accepted; `xcodebuild` exits with that requirement. The installed command-line SDK supported the narrower Swift type check above.
- MusicKit authorization/playback, microphone input, system-audio capture, and physical-device audio routing have not been re-tested. This update preserves those source paths.

The earlier authoring record follows for provenance; its environment limitations
describe September 21, not the checks completed on September 22.

---

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
