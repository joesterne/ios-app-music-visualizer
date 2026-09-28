# Native validation checklist

Run after a successful Xcode build. These checks were **not** executed on an Apple device in the authoring environment.

## Build and launch

- Build `Afterglow-Mac` for My Mac on Apple silicon; check the executable architecture includes arm64.
- Build `Afterglow-iOS` for an iOS 17+ simulator and for a real iPhone/iPad with your team.
- Confirm app icons, dark appearance, portrait/landscape layouts, and resize behavior at 720, 1024, and 1400-point desktop widths.
- Check VoiceOver source selection, slider labels, play/pause, and immersive exit. Increase system text size and ensure key actions remain reachable.

## iPhone Duo

- Build with Xcode 27.1 or newer; use Device Hub to test every pose and Split View configuration listed in `iPhone-Duo.md`.
- Verify the arrangement keeps playback, palette, and motion controls out of active division/occlusion regions. Test the inner camera while active.
- Start local music, pause/resume motion, switch poses, and toggle focus mode. Confirm no audio-player reset or animation-clock restart from layout changes.
- Check VoiceOver and large Dynamic Type in both compact and regular size classes, including sheets and vertically placed system toolbars.

## Audio files

- Import mono WAV, stereo WAV, MP3, AAC, and ALAC. Try a protected/unsupported file and confirm a readable error.
- Import several files; test play, pause/resume, seek forward/back, previous/next, and automatic advance at end.
- Rapidly seek/skip while playing; stale player callbacks must not advance the queue unexpectedly.
- Relaunch and play a previously imported file. Remove an imported copy and confirm the original remains untouched.
- Delete the selected track, including the last track; the old file must not resume.
- Confirm waveform and spectrum become idle when stopped and react to different-frequency test signals.

## Live input

- Deny microphone permission, retry after enabling it in Settings, and verify no feedback monitoring.
- Disconnect/reconnect a USB/Bluetooth input or headphone output. Confirm pause/error behavior and recover by restarting the source.
- On iOS, test interruptions and switching apps. Capture must stop when inactive; playback resumes only when requested.
- On Mac, deny/allow screen/system-audio recording, then capture an unprotected sound in another app. Confirm this app’s output is excluded.
- Stop system capture, revoke permission, and test a system-triggered stream error. UI must stop presenting the input as active.
- A protected stream may produce silence. Do not claim the source is analyzed if no signal arrives.

## Apple Music

- Enable MusicKit App Services for both exact bundle identifiers; sign with an eligible team and set the build setting to YES.
- Check permission denial, authorization, a library with >100 songs, an empty library, search results, and no network.
- Try an account with and without catalog playback eligibility; errors should be actionable.
- Play from a search and from the library; check artwork, title/artist, queue advance, transport, and seek.
- Switch sources during playback; Apple Music must pause. Disconnect should clear the in-memory queue and visible account content.
- Visuals remain labeled ambient in the Apple Music mode.

## Visuals and power

- Open each of fourteen styles, all five palettes, min/max sensitivity, speed, glow, and detail.
- In Super Mario and Space Flight, verify animation, pause, Reduce Motion, audio response, favorites, and saved selection in classic, Duo, and immersive layouts. Toggle response during local playback and confirm playback continues.
- In Yosemite, verify sky masking against the cliff edges, landscape/portrait crops, animated clouds and mist, bird motion, light response to local audio, and asset loading on both targets. Check that the landscape stays still when pausing or enabling Reduce Motion.
- Check 30/60 fps, Reduced Motion, explicitly saved favorites persistence, immersive mode, Escape, and native macOS full-screen transitions.
- Profile a sustained session using Instruments for audio dropouts, Canvas time, thermal behavior, and main-thread hitches.
- Test import of a large file while the UI stays responsive; file copying runs off the main actor.
- After the performance refactor, compare constellation at maximum detail/glow; overlapping dots may blend slightly differently after batching.
- In Instruments, confirm live audio invalidates the visualizer rather than the full studio, and thumbnails stay idle when playback position changes.
- Pause motion and enable Reduce Motion with active input; amplitude must keep updating while time-driven motion freezes. Resume, switch styles, change palette, and enter/exit immersive mode.
- Background and foreground the app during playback; verify rendering/metadata polling suspends and recovers without a burst of catch-up frames.

## Release boundary

The project has no App Store listing, signing identity, provisioning profile, notarization, or TestFlight distribution. Before shipping, complete real-device validation, provider review as appropriate for the final product, and review the privacy manifest against any newly added APIs. Do not advertise the Spotify/other-service launchers as native integrations or audio synchronization.

## Version 0.3 controls and preferences

- Save a setup, change every preference, Restore, relaunch, Reset, and Forget. Reset must retain the saved setup; Forget must preserve imported music and unrelated defaults. Confirm unsaved changes do not replace the snapshot.
- Run `Scripts/build-apple.sh`, including its preference and animation-clock regression executable.
- Verify the source-sheet meter updates only for active input and errors remain visible while the sheet is open.
- Tap Apple Music Play before configuration/authorization/queue selection: the sources sheet should open. Test disabled skip states, a failed local decode, and recovery with another file.
- Rapidly change sources/playback while imports and permissions are pending. Switch apps during a microphone prompt; iOS must not start capture while inactive.
- Drag the speed slider during motion and while paused; resume without jumping. Repeat across Duo pose and immersive transitions.
- Test browser JSON import/export and local save in Safari and Chrome, including storage blocked, a moved file, and corrupt or oversized JSON. Verify settings open/close at narrow, intermediate, and desktop widths.
