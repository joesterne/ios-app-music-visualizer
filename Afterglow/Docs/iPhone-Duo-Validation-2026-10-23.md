# iPhone Duo validation — October 23, 2026

Result: native build, installation, launch, and basic fold-layout smoke tests passed on the iPhone Duo simulator running iOS 27.1. This is simulator evidence, not physical-device certification.

Tested source: repository revision `3e60608`, with no tracked implementation changes. Xcode 27.1 at `/Applications/Xcode-27.1.app` built the `Afterglow-iOS` Debug scheme with signing disabled for simulator `60FCBDC7-205E-4758-9742-F1F74C91D5CC`.

## Native simulator checks

| Check | Result |
| --- | --- |
| Compile, install, and launch | Passed; native Aurora scene rendered |
| Closed portrait | Scene and scrolling deck rendered, with bottom playback controls |
| Open | Scene and control deck arranged side by side |
| Partially open | Scene and deck remained visible on opposite sides of the fold |
| Rotated partially open / tabletop | Scene moved above the fold, controls below |
| Closed landscape | Compact scene and bottom playback controls rendered |
| State continuity | Aurora selection and paused motion survived open, partial, rotated, and closed transitions |
| Focus mode | Entered while closed; unfolding retained the reduced control deck |
| Source sheet | Opened and dismissed in tabletop pose |
| Settings sheet | Opened and dismissed while open; motion resumed successfully |

The simulator was left running with focus mode off and animation resumed. No live audio track was played during these native checks.

## Automated checks

- Full `npm test` portable suite passed: 158 DOM interaction assertions; all 17 visualizers and five palettes; customization rendering; preview scheduling and Duo pose continuity; demo iframe lifetime; Yosemite, Fallout, Forest Walk, and Minecraft renderer checks; DSP checks.
- Native DSP and Tron/settings/geometry tests passed.
- Native Forest Walk and Minecraft geometry tests passed.
- Native preference and animation-clock tests passed, including customization isolation/round-trip, continuous speed, and pause/resume.

## Environment workaround

Initial native test runs reported source files modified during compilation. A direct workspace build then waited in macOS file coordination while opening the project. A temporary copy under `/tmp/afterglow-duo-validation-20261023` avoided that wait. Its native sources, configuration, assets, and project files were byte-compared with the workspace. The successful build used `/tmp/afterglow-duo-derived` for derived data. No implementation workaround was needed.

Build log: `/tmp/afterglow-duo-ios-local.log`. Portable test log: `/tmp/afterglow-duo-portable.log`. These temporary logs may be removed by the operating system.

## Remaining coverage

Physical hardware, live audio/playback-position continuity across folds, MusicKit and microphone permissions, large Dynamic Type, native Reduce Motion, camera-occlusion variations, Split View/narrow-window combinations, and sustained performance/power were not tested. The Mac target and older-iOS fallback were not rebuilt in this pass. The native UI exercise used Aurora; automated renderer coverage does not establish every visualizer's native layout in every pose.
