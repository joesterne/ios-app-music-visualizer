# iOS App Music Visualizer

**Afterglow** — the iPhone, iPad, and native Mac music visualizer.

The original project from the September 21 **Build music visualizer app** conversation
has been restored under [`Afterglow/`](Afterglow/). The previously created repository
contained only this README and a `.gitignore`; the app archive was still attached to
that conversation.

- Open [`Afterglow/Afterglow.xcodeproj`](Afterglow/Afterglow.xcodeproj) in Xcode.
- Open [`Afterglow/Preview.html`](Afterglow/Preview.html) in a browser for the interactive preview.
- See [`Afterglow/README.md`](Afterglow/README.md) for music sources and platform setup.

Choose **Tron** in the visualizer gallery to access **Light cycles**, **Identity discs**,
and **Circuit expansion**, each in **Light blue**, **Orange**, or **Red**.

## Validation status

Local verification completed on September 22, 2026:

- **Audio-processing tests passed:** frequency/RMS, silence, stereo formats, reset,
  non-finite input, and concurrent snapshots.
- **Tron tests passed:** legacy-settings migration, all nine mode/color combinations,
  40,000 disc-boundary/continuity samples, 1,200 cycle trails, and bounded circuit
  growth through 1,000,000 simulated seconds.
- **Native Mac and iOS Simulator Debug builds succeeded** with Xcode 27 and signing disabled.

These results cover the local working tree, including the test-script fix. Simulator
execution and physical-device testing remain unverified; Xcode reported that the
simulator runtime service was unavailable. MusicKit authorization/playback,
microphone input, and Mac system-audio capture still need runtime verification.

See the [verification commands](Afterglow/README.md#verification-commands) to repeat
the checks and the [device checklist](Afterglow/Docs/Device-Checklist.md) for remaining
validation before distribution.
