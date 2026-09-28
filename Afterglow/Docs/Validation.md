# Validation record

## CI follow-up — September 27

Added pull-request checks for the full portable suite and unsigned native builds, using a locked npm development environment and Xcode 27.1 on GitHub’s hosted `xcode-27` image. Fixed an inherited native regression assertion that still expected eleven visuals after Yosemite expanded the gallery to twelve; the test now verifies the exact styles and Yosemite preference migration. Consult the PR check results for actual hosted execution status. This entry records configuration, not an assertion that native builds have passed.


## Current repository integration — September 26

Integrated the version 0.3 package into `main`, preserving Tron, Halo, and Iron Man. The gallery now contains twelve visuals. 95 DOM assertions pass, including Tron mode/color save and reload; scheduler, Duo wrapper, and C DSP checks pass. Swift parsing and Xcode source membership are checked separately. Native builds, native preference/Tron executables, and hardware tests were not run in this Linux workspace. Earlier native build results below apply only to their recorded revisions. PR #4 remains separate.


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

Initial validation: September 21, 2026. Performance refactor: September 25, 2026. Yosemite addition: September 26, 2026.

## Executed in the authoring workspace

- Portable C signal-processing tests passed: dominant-frequency detection and RMS at 8, 44.1, 48, and 96 kHz; bass/high-frequency tones; silence and signal decay; stereo planar/interleaved equivalence; reset behavior; NaN/Inf handling; concurrent snapshot/reset access.
- The same signal-processing tests passed under AddressSanitizer and UndefinedBehaviorSanitizer. Leak detection was unavailable under the host’s process tracing, so it is not claimed.
- All Swift source files were parsed with the tree-sitter Swift grammar without syntax error nodes. This is **syntax checking**, not Swift type checking.
- The browser preview’s embedded JavaScript passed `node --check`.
- Xcode project structure, source/resource membership, plist and scheme XML, and app-icon dimensions were checked using independent parsers and file inspection.

## Not executed

- `xcodebuild`, Swift type checking against Apple SDKs, simulator launch, device installation, native UI rendering, Instruments, and on-device audio routing. The workspace runs Linux and has no Xcode/Apple SDKs.
- MusicKit account authorization, catalog playback, device microphone permission, and ScreenCaptureKit capture. These require a configured Apple environment and account/device access.
- Visual browser QA: the cloud browser rejected local-file navigation under its security policy. No browser-rendered screenshot or layout verification is claimed. Later DOM-only control tests are described below. The later Yosemite Canvas-renderer check is described below.

The project includes `Scripts/build-apple.sh` and `Docs/Device-Checklist.md` so the remaining checks are concrete and reproducible on a Mac. The package should be treated as an implementation ready for an Apple build-and-test pass, not as a tested production release.

## September 25 performance regression pass

The refactor passed the C audio suite, ASan/UBSan (leak detection disabled), 960 before/after analyzer snapshot comparisons, Swift syntax parsing, preview JavaScript syntax and scheduler behavior tests, and project/configuration validation. The maximum analyzer difference was 1.78813934e-07. The measured analyzer CPU-time reduction was 25–29% across the tested input rates; `Performance.md` contains the workload and full numbers. Native build, device performance, and visual checks remain outstanding.

## September 26 Yosemite verification

- Added the ninth visualizer to native and preview galleries, with the preview opening to Yosemite.
- Parsed all 15 Swift source files without syntax errors. Both Xcode targets include 16 compiled source files (15 Swift + 1 C), including `YosemiteScene.swift`, and the asset catalog. Plist, scheme/workspace XML, and asset JSON validation passed.
- Preview JavaScript syntax and shared scheduler behavior tests passed, including 60 fps limiting, pause/idle, live input with frozen time, and background suspension.
- Executed the actual Yosemite Canvas renderer with Skia (`@napi-rs/canvas`). Inspected landscape and phone renders at two animation times. Checks passed for changing motion, stable paused frames, measured-level light response, background reuse, palette/resize cache invalidation, and the asset-loading fallback. This is renderer verification, not a browser session or native app screenshot.
- Verified the PNGs embedded in the standalone HTML match the native asset files byte for byte.
- Audio processing code was unchanged in this addition; the September 25 audio results above were not rerun. Native build/type checking, Apple-device operation, browser layout, and performance profiling remain outstanding.

## September 25–26 Duo update verification

- All 17 Swift sources passed syntax parsing, including the availability-guarded iOS 27.1 arrangement workspace and shared visual clock. This does not type-check the new APIs against an Apple SDK.
- Preview and demo scripts passed JavaScript syntax checks. Scheduler/pose tests preserve the same audio objects, source, paused state, and visual time across demo layout messages, and reject unrecognized poses or non-parent messages.
- The actual demo wrapper passed tour, pose, visual-selection, hidden-page, and narrow-container checks. Its embedded preview matches `Preview.html` exactly and its iframe loads only once throughout the tested transitions.
- The actual Canvas renderers produced the walkthrough visuals using measured RMS/spectrum/waveform data from the original 24-second score. Representative video frames were inspected. The MP4 was checked for H.264 video (1280 × 800, 24 fps), stereo AAC audio (48 kHz), 24-second duration, and successful decoding.
- Both targets include 18 compiled source files (17 Swift + 1 C), with the asset catalog and privacy manifest in their resource phases. Plist/XML/JSON and standalone embedded-asset validation passed.
- Native compilation, Swift type checking with iOS 27.1, actual simulator/hardware pose transitions, native frame rates, and browser DOM/layout verification were not available. Audio-processing code was unchanged, so its prior results were not rerun.

## September 26: version 0.3 controls and preferences

- **87 DOM interaction assertions passed** against the generated preview in jsdom. These execute real HTML elements and handlers, with controlled substitutes for media, permissions, images, drawing, and animation timing. They establish handler/state behavior, not real browser layout, device permissions, or provider playback.
- Scheduler tests passed, including 30/60 fps cadence, idle/hidden suspension, live amplitude with frozen motion, and pose continuity. Wrapper tests passed with no visual reset on pose change and one iframe initialization.
- The actual Yosemite Canvas renderer regression passed again: landscape/phone/thumbnail drawing, moving/frozen frames, level response, cache reuse/invalidation, and loading fallback. Portable C DSP tests passed again.
- All 19 Swift files, including the new native regression source, passed syntax parsing. Each native target includes 18 production Swift files and one C file. Project membership, plist/XML/JSON, HTML IDs, and JavaScript syntax checks passed.
- `Tests/test-native-preferences.swift` adds isolated defaults validation, corrupt-data recovery, scoped deletion, and continuous clock/pause checks to the Mac build script. These native checks were **not executed** here: Swift type checking, Xcode builds, native buttons, and Apple-device integration remain unverified.
- The existing 24-second video is retained from version 0.2; the interactive HTML demo includes version 0.3 changes.
