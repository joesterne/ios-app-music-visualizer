# Forest Walk

Select **Forest Walk**, the sixteenth gallery option, in the native app or browser preview. A backpacked walker follows a woodland trail through layered evergreens, shafts of sunlight, ferns, and fireflies. Deer, foxes, rabbits, and birds appear beside the trail at varying intervals, with quiet stretches between encounters.

## Behavior

- The shared animation clock drives tree travel, walking, bird wings, rabbit hops, and encounter fades. Pause and Reduce Motion freeze the scene's motion; changing speed continues from the current clock position.
- Encounters use deterministic pseudorandom seeds per ten seconds of animation time. Species, side, start offset, depth, and duration vary. One encounter lasts five to seven seconds and fades in and out. The same animation time reproduces the same encounter, including after a pause; a new session repeats the sequence.
- Supported audio input adjusts foliage sway, sunlight, and firefly size/brightness. It does not control animal spawning. With motion paused, input can still update those reactive details. Ambient mode uses the existing generated signal.
- Palette changes affect firefly accents while preserving natural woodland colors. Glow controls light accents; Detail controls tree, fern, and firefly counts. Favorites and explicit Save preferences include Forest Walk.
- Fixed pools and a maximum of one animal prevent work from accumulating over long sessions. Trees render in depth order. No image download, timer, network request, or third-party asset is required.

## Code organization

The browser scene lives in `Web/forest-walk.js`, which the preview builder embeds before `Web/app.js`. `sceneRenderers` provides one dispatch table for dedicated scenes. The native implementation uses `ForestWalkRenderer.swift` and a separately testable `ForestWalkGeometry.swift`; `VisualRenderer` dispatches dedicated scenes before drawing signal-based visuals. Visualizer titles now use a readable switch instead of nested conditional expressions.

After editing web sources, run both `Scripts/build-preview.py` and `Scripts/build-duo-demo.py`. Run `Scripts/generate-project.py` after adding source files.

## Validation on October 6, 2026

- Portable suite: all sixteen gallery selections, 114 DOM interaction assertions, preference save/restore, scheduler/pause/Reduce Motion, audio/source controls, Duo embedding, DSP, and existing Yosemite/Fallout renderer regressions.
- Real Canvas forest tests: desktop, portrait, ultrawide and thumbnail output; all four animal species and both sides; quiet gaps; bounded fades; identical frozen frames; moving frames; audio changes with motion frozen; palette response; timestamps through 1,000,000 seconds.
- Swift tests: encounter diversity, quiet gaps, deterministic geometry and long-running timestamps; Forest Walk selection/favorite round-trip and existing settings/Tron regressions.
- Desktop and portrait browser renderer images inspected. The live browser preview was opened and Forest Walk selected through its gallery.
- Unsigned native Mac Debug build passed using local Xcode 27.0. This is compilation evidence, not native runtime or live audio validation.
- The local installation lacks the iOS 27.1 SDK required by this project's existing Duo layout. iOS compilation and device/runtime behavior remain unverified for this change. `Scripts/build-apple.sh` includes the new Swift encounter tests for a supported Xcode environment.
