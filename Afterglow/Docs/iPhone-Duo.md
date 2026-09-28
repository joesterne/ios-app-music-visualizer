# iPhone Duo update

Version 0.2 adds an iOS 27.1 workspace, a responsive browser preview, and an interactive Duo walkthrough. It retains the existing native macOS target and the iOS 17+ fallback interface.

## Native behavior

| Available space | App behavior |
| --- | --- |
| Compact outer display or narrow Split View | A vertically scrolling scene and control deck, with playback controls pinned inside the bottom safe area |
| Regular inner display | A system `ArrangementView` places the visualizer and control deck in separate regions |
| Partially folded inner display | The split arrangement uses the system's division regions to reposition content around the fold; the app does not infer a pose from arbitrary hinge-angle thresholds |
| Focus mode | The scene stays visible while the deck reduces to playback and motion controls |
| Native Mac | The existing desktop studio, with the shared animation-clock improvement |

The expanded control deck includes visualizer selection, palette buttons, motion and glow sliders, source selection, playback, and motion pause. Full settings remain available from the standard toolbar. Toolbar buttons and foreground content respect system safe areas. Only scenic backgrounds extend across their drawing surface.

The visualizer clock is owned by `StudioView`, above the changing layouts. Recreating a canvas after a size-class or arrangement change keeps elapsed motion time. Audio playback, selected source, imported queue, and visual preferences remain in the existing `StudioModel`; layout code never replaces the player or resets that model. The existing foreground-only audio policy still applies when iOS makes the app inactive. Continuous playback through OS suspension is not promised.

## Build and test on Apple hardware

1. Use **Xcode 27.1 or newer**, with the iOS 27.1 SDK. At the time of this update, Apple lists Xcode 27.1 beta for Duo development.
2. Open `Afterglow.xcodeproj`, choose `Afterglow-iOS`, then select the iPhone Duo simulator in Device Hub.
3. Build and test closed, open, rotated, partially folded, book, and tabletop poses. Test both sides of Split View and very narrow window widths.
4. Check active camera occlusion and asymmetric safe areas. Important controls must stay visible and reachable, including at large Dynamic Type sizes.
5. Start a local track, change poses repeatedly, and check source selection, playback position, paused state, and motion phase. Repeat with Reduce Motion enabled.
6. Test focus mode and all source/settings sheets in each pose. Then build and run the Mac scheme on Apple silicon and the iOS fallback on an older supported OS.

`bash Scripts/build-apple.sh` builds both targets and rejects an older simulator SDK with a clear message. The minimum deployment versions remain iOS 17 and macOS 14. The new iOS APIs are protected by runtime availability checks and excluded from the Mac target by platform compilation conditions.

## Demo deliverables

- `Duo-Demo.html`: a self-contained, interactive presentation around the actual `Preview.html` app. It keeps one iframe alive while changing viewport size and simulated pose. You can change visuals, use the controls, or import music inside the frame. Its guided tour is 20 seconds and starts only when requested.
- `Demo/Afterglow-Duo-Demo.mp4`: a 24-second, 1280 × 800, 24 fps rendered walkthrough with an original ambient score. The scenery and abstract visuals execute the real preview renderers; the device frame and control UI in the video are illustrative compositions, not screenshots from a compiled iOS app.
- `Demo/Open-Sky.wav`: the original synthesized score. Import this file into Afterglow to try a known local audio source. It is not a commercial track or a streaming-service recording.

The demo's closed/open aspect ratios use Apple's published display pixel ratios. Its logical viewports, device frame, tabletop positioning, and transitions are illustrative; they are not measured UIKit point sizes or a hardware/hinge simulator. Actual device positioning is delegated to Apple's arrangement system in the native app. The browser does not receive native hinge events.

Rebuild the interactive wrapper with `python3 Scripts/build-duo-demo.py` after editing `Preview.html`. The optional score and video scripts require NumPy, `@napi-rs/canvas`, and ffmpeg in a development environment; these are not app runtime dependencies.

## Validation status

Executed in Linux: Swift syntax parsing, JavaScript syntax checks, shared preview scheduler tests, pose/message continuity tests, demo tour and iframe-lifetime tests, actual Canvas-renderer frame checks, project/resource and asset integrity checks, and MP4 stream/duration validation. Representative closed, open, tabletop, and alternate-visual video frames were inspected.

Not executed: Apple-SDK Swift type checking, Xcode compilation, simulator pose testing, native UI rendering, physical Duo testing, browser DOM/layout QA, or device performance profiling. The source is prepared for an Apple build-and-test pass; support has not been certified on hardware. No additional simultaneous-display or independent multiwindow playback feature is claimed.

## Apple references checked September 25, 2026

- https://developer.apple.com/iphone-duo/
- https://developer.apple.com/videos/play/tech-talks/111461/
- https://developer.apple.com/videos/play/tech-talks/111463/
- https://developer.apple.com/videos/play/tech-talks/111464/
- https://www.apple.com/iphone-duo/specs/
