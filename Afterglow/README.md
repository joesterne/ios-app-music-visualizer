# Afterglow

A native music-visualizer studio for **iPhone, iPad, and Mac**, with eleven visualizers, five original palettes, three Tron colors, and clear source-mode labels.

This package contains a complete editable Xcode project and an interactive browser preview. **It is source code, not a signed `.ipa` or `.app`.** The native app must be built in Xcode on a Mac. Local unsigned Mac and iOS Simulator Debug builds succeeded with Xcode 27 on September 24, 2026. The latest native response-toggle and gallery changes still need runtime verification; see the [current validation status](#validation-status) below.


## Tron theme

Select **Tron** in the visualizer gallery, then choose an animation and color in
its controls below the stage (also available in native visual settings and the
immersive visualizer menu):

- **Light cycles:** neon riders follow right-angle routes and leave luminous trails.
- **Identity discs:** spinning illuminated discs rebound off the boundaries, with short afterimages.
- **Circuit expansion:** branching motherboard-style traces grow indefinitely as the view pulls back, with illuminated junctions and moving signal pulses.

Every mode supports **Light blue**, **Orange**, and **Red**. The Tron color is
independent of the original five palettes, so switching back restores your previous
palette. Native settings preserve all existing preferences when upgrading; Tron
mode/color choices also persist in the browser preview where local storage is available.

The existing sensitivity, motion-speed, glow, detail, favorites, pause, and Reduce
Motion behavior apply. Measured input changes the glow/line weight and disc size;
ambient and streaming-companion modes remain independent animations. Circuit
geometry retains at most eight rings to keep work and memory bounded.

Run `bash Scripts/test-tron.sh` on a Mac with Swift tools to validate settings
migration, all nine mode/color combinations, disc rebounds, cycle trails, and
long-running circuit geometry. `AFTERGLOW_TEST_SDK` optionally selects a macOS SDK.


## Try the visuals immediately

From this `Afterglow` directory, start a localhost server:

```bash
python3 -m http.server 8765 --bind 127.0.0.1
```

Open **http://127.0.0.1:8765/Preview.html** in Safari or Chrome. Keep the terminal open; press **Ctrl+C** to stop it. If the port is occupied, use `8766` in both the command and URL. From the repository root, append `--directory Afterglow` to the command.

Choose a visualizer or click **Import audio / +** to play an unprotected local audio file. Use **React to audio** beneath the stage to choose measured response or independent animation; playback continues when changing this setting. The choice persists after reload. The horizontal control below the gallery browses all eleven styles. Escape leaves immersive mode.

No music account, backend, API key, or package installation is required. Python is only used to serve the preview; opening `Preview.html` directly also supports ambient visuals, but localhost is recommended for browser audio permissions. Audio files and microphone samples are processed locally.

The preview is a browser implementation, not the compiled native app. It does not run MusicKit or ScreenCaptureKit. Microphone input requires a supported browser and permission; actual microphone capture was not verified in the Codex in-app browser. Use the native Mac app for the microphone path tested in the validation report.

## Run the native app on your M-series Mac

1. Install/open **Xcode 16 or newer** on macOS 14 or newer, then open this checkout.
2. Open **Afterglow.xcodeproj**. No project generator, package manager, backend, or API secret is required.
3. Select the **Afterglow-Mac** scheme and **My Mac** as the run destination.
4. Press **⌘R**. The default Mac configuration uses local signing. If Xcode asks, choose **Sign to Run Locally** in the Mac target’s Signing & Capabilities settings.
5. Start with **Ambient studio** or **Your audio files**. For input-driven visuals, choose **Microphone / input** or **Mac system audio** and grant the requested OS permission.

The Mac target is a native macOS app, using standard architectures, including **arm64 for Apple silicon**. It is intended for macOS 14 or later and does not rely on Rosetta or an iPhone compatibility window. The same project also permits the iOS app to be made available on Apple silicon, but the native Mac target provides system-audio capture and desktop controls.

## Run on iPhone or iPad

1. Choose the **Afterglow-iOS** scheme and an iOS 17-or-newer simulator or connected device.
2. For a physical device, select your development team in **Signing & Capabilities**. Change `BUNDLE_ID_PREFIX` in `Config/App.xcconfig` to a unique identifier you control.
3. Press **⌘R**. If requested by the device, enable Developer Mode and trust your development profile through the normal iOS settings flow.
4. Import music from Files, select a visualizer, and use the expand button for immersive viewing.

Use real devices for microphone routing and Apple Music playback validation. A simulator cannot establish full device playback behavior.

## Source capabilities

| Source | Playback | Visual response | Setup |
| --- | --- | --- | --- |
| Local WAV, MP3, AAC, AIFF, ALAC | In Afterglow; queue, play/pause, skip, seek, volume | Actual decoded audio: spectrum, waveform, RMS, band energy | Import unprotected files |
| Apple Music | In Afterglow through MusicKit; library, catalog search, queue, transport | Independent ambient animation; no PCM tap into the protected stream | Apple Developer configuration below; catalog playback requires a subscription |
| Spotify companion | In Spotify; launcher only | Independent ambient animation | Open Spotify and return; no Spotify SDK/login/token |
| Microphone / external input | Listens to the device’s current audio input; no monitoring | Actual input audio | Microphone permission |
| Mac system audio | Another app continues playing | Audio macOS permits ScreenCaptureKit to provide | macOS screen/system-audio permission; protected content may be silent |
| YouTube Music, TIDAL, SoundCloud, Amazon Music, Bandcamp | External service launchers | Ambient, or separately selected live input | Provider app/site |
| Ambient studio | No audio playback | Locally generated motion | None |

On iOS, this app **does not capture another app’s digital audio**. Microphone mode hears sound in the room; it cannot hear a track playing only through headphones. On Mac, generic system capture depends on the OS and content provider; it is not a promise of access to protected streams.

Spotify is deliberately a companion launcher. Spotify’s current developer policy restricts synchronizing recordings with visual media, combining its content with other services, and analyzing Spotify content. No Spotify API client, audio-analysis endpoint, metadata-driven beat simulation, or credentials are embedded here. The Spotify mode makes no claim of beat synchronization. If direct Spotify integration is essential to a later release, obtain approval for the specific product before adding it.

## Enable Apple Music

MusicKit uses Apple’s automatic developer-token generation. **There is no private signing key or service secret to paste into this app.** MusicKit is off by default so the project’s local and ambient functionality can be used without configuring a developer account.

1. Join/use an Apple Developer Program team with access to App IDs and MusicKit App Services.
2. In `Config/App.xcconfig`, change `BUNDLE_ID_PREFIX` from `com.example.afterglow` to your own prefix. The targets append `.ios` and `.mac`.
3. In the Apple Developer portal’s **Certificates, Identifiers & Profiles → Identifiers**, create or edit an **explicit App ID** matching each target’s bundle identifier.
4. In each App ID’s **App Services** tab, enable **MusicKit** and save. The bundle identifiers must exactly match Xcode. See Apple’s linked automatic-token documentation below.
5. In both targets, select that development team and refresh signing as Xcode requires. For the Mac target, change **Build Settings → Code Signing Identity** from local/ad-hoc signing (`-`) to **Apple Development** for the build you run with MusicKit.
6. Set `AFTERGLOW_MUSICKIT_ENABLED = YES` in `Config/App.xcconfig` and rebuild.
7. In Afterglow, choose **Apple Music → Connect Apple Music** and grant access. Use a device or Mac signed into your Music account. An active Apple Music subscription is needed for catalog playback.

The project includes `NSAppleMusicUsageDescription`. Enabling the runtime setting alone does not grant authorization or provision the service. MusicKit configuration is performed in Apple’s portal; do not invent an entitlement or embed private keys to work around authorization failures.

**Disconnect** stops the app’s Apple Music player and clears its in-memory music lists and queue. To revoke the OS-level authorization, use the system privacy settings for Media & Apple Music. Local imports and preferences are independent of that permission.

## Visual response and gallery browsing

Use **React to audio** beneath the stage to switch between measured audio response and independent animation without stopping playback or disconnecting an input. The preference is saved. Audio response requires a supported input (imported audio, microphone, or native Mac system capture); streaming companions continue to use ambient motion. The horizontal control below the gallery lets you browse all eleven visualizers.

Rendering reuses cached Halo depth orders and browser frequency-bin ranges. The browser skips visual analysis and rendering while hidden or uses ambient animation when independent; native independent mode avoids publishing analyzer frames unless the source meters are visible. These are reductions in repeated work; no device-specific frame-rate improvement has been measured.

Validated September 24: browser regression tests (including playback continuity, response switching, gallery synchronization, and hidden-page analysis), settings migration/round-trip and geometry tests, DSP tests, and unsigned macOS/iOS Simulator builds passed.

## Visuals and controls

- **Aurora:** layered flowing light ribbons.
- **Spectrum:** 64 logarithmic frequency bars with reflections.
- **Orbit:** concentric rings and radial frequency spokes.
- **Waveform:** layered views of the measured or ambient waveform.
- **Tunnel:** moving hexagonal depth rings.
- **Constellation:** drifting particles, connections, and audio-responsive size.
- **Terrain:** a perspective frequency landscape.
- **Bloom:** radial petal curves that expand with frequency energy.
- **Iron Man:** a white-blue triangular arc reactor, counter-rotating red/gold armor rings, and audio-reactive HUD ticks. The selected palette colors the HUD accents; sensitivity, motion speed, glow, detail, and pause controls apply.
- **Halo:** a tilted ringworld in a starfield, with illuminated surface panels, orbiting energy pulses, and spectrum-driven spires. Uses the selected palette and existing motion, sensitivity, glow, and detail controls.
- **Tron:** light cycles, bouncing identity discs, and expanding circuits; each has light blue, orange, and red options.

Choose **Ultraviolet, Glacier, Ember, Candy, or Monochrome**. Sensitivity, motion speed, glow, detail, frame-rate preference, and favorites persist between app launches. 30 fps reduces rendering work. System Reduce Motion pauses continuous time-based motion; measured amplitude may still change the image.

The badge distinguishes **LIVE AUDIO**, **AUDIO IDLE**, and **AMBIENT MOTION**. Ambient animation is not presented as audio analysis. Visual motion can be paused independently of playback.

Mac shortcuts: **⌘O** imports audio, **⇧⌘S** opens sources, **⌘I** toggles immersive mode, **⇧⌘P** pauses visual motion, and **⌘,** opens settings. The standard macOS green window control provides OS-level full screen; immersive mode hides the studio interface.

## Privacy and lifecycle

No analytics, ads, account server, or audio uploads. Imported files are copied into the app sandbox so they survive relaunch. Removing an imported copy never deletes the original file. Preferences are stored in app-owned UserDefaults. The privacy manifest declares that use.

Microphone and system audio are analyzed in memory; no capture is saved. ScreenCaptureKit screen buffers are discarded. Apple Music requests and artwork loads communicate directly with Apple, and external source launchers open the selected service.

This version is a **foreground visualizer**. On iOS it pauses its own playback and stops microphone capture when inactive; it does not claim background audio, lock-screen transport, or background microphone support. Returning to the app requires resuming playback/input. Audio interruptions and disconnected output routes pause the local player. On Mac, live system input may continue while another application is focused; rendering pauses when the scene is inactive.

## Project map

| Folder | Purpose |
| --- | --- |
| App | Entry point, source/state model, persisted visual settings |
| Audio | Local player, microphone input, ScreenCaptureKit, analyzer bridge |
| Core | Portable C FFT and signal processing |
| Services | MusicKit and sandboxed local collection |
| Views | Responsive SwiftUI studio, sources, player, settings |
| Visualizers | Eleven visualizers, including three Tron modes, with Canvas renderers and animation scheduling |
| Config | Info plists, entitlements, build settings, privacy manifest |
| Tests | Deterministic audio-processing, settings-migration, and Tron geometry tests |
| Scripts | Project regeneration and build checks |
| Docs | Architecture, validation status, device checklist |

There are no third-party app runtime dependencies. `Scripts/generate-project.py` uses standard Python and recreates the checked-in project after adding source files. It also recreates the generated Info plists and entitlements; retain manual edits before regenerating. Python is not needed to open or build the included project.

## UI and audio checks

See the [September 24 UI/audio validation report](Docs/UI-Audio-Validation.md) for verified native microphone and local-file playback, control checks, fixes, and remaining permission/account requirements.

## Validation status

Latest checks completed on September 24, 2026:

| Check | Result |
| --- | --- |
| Audio DSP | Passed: frequency/RMS at four rates, silence, stereo formats, reset, non-finite input, concurrent snapshots |
| Settings and geometry | Passed: legacy migration, response preference round-trip, Halo/Iron Man persistence, all nine Tron selections, geometry and long-running bounds |
| Browser logic regressions | Passed: input lifecycle, source-change races, playback controls, response switching without pausing playback, gallery synchronization, hidden-page analysis suppression |
| Browser interaction | Response toggle, preference persistence after reload, gallery endpoint scrolling; no reported JavaScript errors |
| Native Mac Debug build | Passed with Xcode selected, signing disabled |
| iOS Simulator Debug build | Passed with Xcode selected, signing disabled |
| Native runtime | Earlier locally signed Mac build launched; microphone and local WAV playback were exercised. Latest toggle/scroll changes have not been retested in the native app. |

Compilation and simulated browser regression tests do not establish device or account behavior. Browser microphone capture, Mac system-audio capture, configured MusicKit playback, physical-device checks, and sustained performance remain open. See the [UI/audio report](Docs/UI-Audio-Validation.md) and [device checklist](Docs/Device-Checklist.md).

## Verification commands

Run these commands from the `Afterglow` directory.

Browser control/audio logic tests, with Node.js installed (no npm packages required):

```bash
node Tests/test_preview.cjs
```

Portable signal-processing tests, on macOS or Linux with a C compiler:

```bash
bash Scripts/test-dsp.sh
```

Settings migration and Tron geometry tests, on a Mac with Swift tools:

```bash
bash Scripts/test-tron.sh
```

Native compilation on a Mac with Xcode selected as the developer directory:

```bash
bash Scripts/build-apple.sh
```

If the active developer directory points to Command Line Tools, select Xcode for
this command (adjust the path if Xcode is installed elsewhere):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Scripts/build-apple.sh
```

The build script compiles both the native Mac app and the iOS simulator app without signing. It does not validate account access or install a signed app. Follow `Docs/Device-Checklist.md` before treating the app as production-ready or submitting it to TestFlight/App Store.

## Primary references

- [Apple MusicKit](https://developer.apple.com/documentation/musickit)
- [Apple automatic developer-token setup](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api)
- [ApplicationMusicPlayer](https://developer.apple.com/documentation/musickit/applicationmusicplayer)
- [ScreenCaptureKit audio capture sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [Spotify developer policy](https://developer.spotify.com/policy)

Provider behavior and requirements were checked against the linked documentation on September 21, 2026. Recheck provider requirements before distribution.
