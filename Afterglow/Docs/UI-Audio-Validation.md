# UI and audio verification — September 24, 2026

## Verified interactively

The native Mac app was built with local signing in `/tmp/afterglow-ui-audio` and launched. These results are separate from the unsigned Mac/iOS Simulator compilation checks.

- All eleven native and browser gallery options select correctly.
- Native: all five palettes, sensitivity/speed/glow/detail sliders, reset settings, 30/60 fps, favorites, pause, immersive entry/exit, and settings-sheet opening work. Reset restores defaults.
- Browser: visual sliders update their displayed values, palette selection changes rendering, settings close works, and microphone connection cancellation returns to Audio Idle.
- Native microphone: connected successfully, displayed a live waveform, and stopped on request. Capture was stopped after testing.
- Local files: a generated 20-second stereo WAV with 440/880 Hz tones imported and played in both the native app and browser preview. Waveforms showed the signal rather than ambient animation.
- Native playback: pause/resume, seek, volume, and previous/next controls worked with the single-track test collection. Visual selection survived app relaunch.
- Browser Spotify and Apple Music buttons opened the correct external service tabs. These are companion launchers, not PCM audio inputs.
- Native Apple Music setup button now displays its instructions inline; Dismiss message works. Unconfigured playback now produces an actionable alert instead of silently returning.

## Fixed during this pass

- Ignore late microphone permission success/failure after the user selects another source; stop any abandoned stream.
- Allow canceling an in-progress browser microphone connection and show distinct connecting, active, and idle states.
- Handle browser microphone-track termination and make reconnect available.
- Keep browser microphone analysis connected through a zero-gain output, without audible microphone monitoring.
- Clear browser audio measurements when paused, ended, disconnected, or switching sources; do not substitute ambient measurements for an idle live input.
- Guard asynchronous file/play actions against source changes; clear the previous file before replacement.
- Disable preview volume outside local-file mode.
- Make browser settings open/close consistent across viewport widths.
- Respect a change to the browser Reduce Motion preference by pausing motion.
- Serialize native capture stop/start against source changes, and guard track skipping during transitions.
- Clear the old native file and selected track after a failed replacement load.
- Improve native system-audio permission guidance and Apple Music setup/transport feedback.

## Automated checks

- `node Tests/test_preview.cjs`: dependency-free JavaScript tests run the actual preview script with simulated DOM/audio/permission objects. Covers eleven gallery options, five palettes, settings/immersive close, microphone cancellation, denial/retry/disconnect, stale asynchronous success/failure, zero-gain routing, local playback/pause/seek/restart/volume. This is a logic regression test, not evidence of browser microphone hardware access.
- `bash Scripts/test-tron.sh`: settings migration, Halo/Iron Man persistence, and existing Tron geometry regressions passed.
- `bash Scripts/build-apple.sh` with Xcode selected: audio DSP tests and both unsigned Mac and iOS Simulator builds passed.
- Locally signed Mac build and app launch passed.
- `git diff --check` passed.

## Still blocked or not verified

- Mac system capture was rejected by macOS recording privacy permissions. Actual system-audio samples remain unverified. Enable Afterglow in System Settings → Privacy & Security → Screen & System Audio Recording and relaunch before retesting.
- The in-app browser microphone request stayed pending. Cancellation worked, but actual browser microphone samples were not obtained. Native Mac microphone input did work.
- Native Apple Music is disabled in this build; authorization, library/catalog queries, playback, subscription eligibility, and account-specific controls require a configured and signed MusicKit build/account.
- No new physical iPhone/iPad runtime checks, hardware disconnect/reconnect tests, multi-track auto-advance checks, alternate codec checks, or sustained performance checks were completed in this pass.

The general device checklist remains the release gate. These results do not assert that every account-dependent or hardware-dependent control has been validated.

## Response toggle, gallery, and rendering follow-up

The September 24 follow-up added a saved React to audio setting to native and browser views, horizontal gallery controls, cached Halo depth order, cached browser frequency ranges, hidden-page work suppression, and reduced native analyzer-frame publication in independent mode. Existing audio playback/input connections continue when changing the visual response setting.

Browser interaction verified independent mode, persistence after reload, and the gallery scroll endpoint, with no reported console errors. The dependency-free regression tests additionally verified playback continuity, re-enabling analysis, hidden-page suppression, and scroll synchronization. Settings/geometry tests, DSP tests, and unsigned Mac/iOS Simulator builds passed after these changes.

The earlier native launch and audio results above precede this follow-up. Native runtime testing of the new toggle/gallery controls and sustained performance profiling remain outstanding.
