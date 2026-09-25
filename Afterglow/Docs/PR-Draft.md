# PR draft

**Title:** Add independent visual motion, gallery scrolling, and reliable audio controls

**Publication:** Submit as a draft from `codex/audio-response-controls` into `codex/halo-iron-man`, which is the open Halo/Iron Man PR #2 branch. Retarget to `main` after that prerequisite merges.

## Description

Users can now switch between measured audio response and independent animation without stopping their track or disconnecting an input. A saved **React to audio** toggle controls both the studio and immersive renderers. Visible horizontal gallery controls make all eleven visualizers accessible.

The preview now handles canceled and late microphone permission results, disconnected input tracks, and source changes during asynchronous file/play operations. Native playback clears failed file replacements, serializes capture transitions, and provides actionable MusicKit/setup and system-capture errors.

Halo depth ordering and browser frequency-bin ranges are reused instead of rebuilt each frame. Hidden browser pages skip analysis/rendering, and native independent mode avoids publishing analyzer frames unless source meters are visible. No measured frame-rate improvement is claimed.

The README now includes localhost preview commands, Xcode Mac/iOS run instructions, audio-source requirements, and validation boundaries.

## Validation

- Passed browser logic regressions: gallery/palette/settings controls, microphone lifecycle and source races, local transport, visual response switching without pausing playback, gallery synchronization, hidden-page analysis suppression.
- Passed native settings migration/round-trip and Tron geometry tests.
- Passed DSP tests and unsigned macOS/iOS Simulator Debug builds.
- Browser UI verified toggle persistence and gallery endpoint scrolling with no reported console errors.
- Earlier native runtime checks verified local signing/launch, microphone input, local WAV playback, and existing controls; see `Docs/UI-Audio-Validation.md`.

## Remaining runtime checks

- New native toggle/gallery controls have compilation coverage but await runtime verification.
- Actual browser microphone capture, permission-enabled Mac system capture, configured MusicKit playback, physical iOS devices, and sustained performance remain unverified.

Keep this PR in draft until the required runtime checks are complete. Exclude the unrelated `project_repo/` directory from publication.
