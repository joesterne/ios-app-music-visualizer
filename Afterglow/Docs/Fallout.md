# Fallout visualizer

Select **Fallout** in the gallery. This is the fifteenth scene, available in the native app and offline browser preview.

Two toothed vault doors, numbered 101 and 76, roll back and forth on a hazard-striped rail. Rotation follows horizontal travel. Two Pip-Boy-style wrist computers sit in front, with olive housings, adjustment dials, speakers, amber/green indicators, and phosphor-green CRT glass. The screens type and scroll a looping fictional terminal listing, with scanlines, a moving refresh band, a cursor, and audio traces.

## Controls

- **Speed** changes the shared animation clock: doors, typing, cursor, refresh sweep, and dust.
- **Pause / Reduce Motion** freeze time-driven movement. With live audio enabled, signal traces, screen luminance, and indicators still respond.
- **React to audio** uses the existing source behavior; independent mode uses ambient signal data without interrupting playback.
- **Sensitivity** scales audio response, **Glow** changes the phosphor halo, and **Detail** changes the bounded dust count.
- **Favorites** and explicit **Save / Restore** retain the Fallout selection. Existing saved configurations remain readable.
- The scene intentionally keeps olive metal, amber markings, and green phosphor instead of recoloring the CRT with the global palette.

The imagery is drawn with Canvas primitives and text; no remote assets, services, fonts, or game files are required. Code is decorative and never executed. Fixed object counts and time-derived motion keep work bounded and frozen frames reproducible.

## Validation

Real Canvas tests cover landscape, portrait and thumbnail output; frozen-frame equality; animation changes; audio response with motion frozen; door travel/rotation; and timestamps through 1,000,000 seconds. The full portable suite passes, including 111 DOM interaction checks and all fifteen gallery choices. Native settings migration, selection/favorite round-trip and Tron geometry tests pass. The unsigned Mac target builds with Xcode 27.0.

Hosted Xcode 27.1 checks cover the iOS build. Native runtime, physical-device audio, interactive Duo poses, and sustained performance still need the device checklist. Canvas images are browser-renderer evidence, not screenshots of a running native app.
