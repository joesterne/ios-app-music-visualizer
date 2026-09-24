# Afterglow — Music Visualizer

A native music visualizer for **iPhone, iPad, and Mac**, with an interactive browser preview. Choose from eleven visualizers, including Tron, Halo, and Iron Man.

## Run locally

### Browser preview

From the repository root, run:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory Afterglow
```

Open **http://127.0.0.1:8765/Preview.html** in Safari or Chrome. Keep the terminal open; press **Ctrl+C** to stop the server. If port 8765 is already in use, try 8766 and use that port in the URL.

Start with **Ambient studio**, or click **Import audio / +** and select an unprotected audio file. Turn **React to audio** on for measured input or off for independent animation while playback continues. Use the horizontal control below the gallery to browse all eleven visualizers. Microphone input requires browser permission; localhost provides the appropriate secure context, but browser support still varies.

The preview runs locally without an account, backend, or API key. Audio is not uploaded. It does not provide native MusicKit playback or Mac system-audio capture.

### Native Mac app

Requires a Mac with **Xcode 16 or newer** and **macOS 14 or newer**.

```bash
open Afterglow/Afterglow.xcodeproj
```

In Xcode, select **Afterglow-Mac → My Mac**, then press **⌘R**. The Mac target uses local signing; choose **Sign to Run Locally** if Xcode asks. Ambient visuals and local audio files work without MusicKit setup. For live input, choose **Microphone / input** or **Mac system audio** and grant the relevant macOS permission.

### iPhone / iPad

Open the same project, choose **Afterglow-iOS**, select an **iOS 17-or-newer simulator** or a connected device, and press **⌘R**. A physical device requires your development team and a unique `BUNDLE_ID_PREFIX` in `Afterglow/Config/App.xcconfig`.

See the [full setup guide](Afterglow/README.md) for signing, music-source capabilities, and optional Apple Music configuration.

## Visuals and controls

- **Tron:** Light cycles, Identity discs, and Circuit expansion; each in light blue, orange, or red.
- **Halo:** a glowing ringworld, stars, orbiting energy, and audio-responsive spires.
- **Iron Man:** a white-blue arc reactor, rotating red/gold rings, and reactive HUD accents.
- **React to audio:** saved preference for measured audio response or independent animation. Streaming companions use independent animation because they do not supply audio samples.
- **Gallery scrolling:** visible horizontal control for all eleven styles, plus palette, sensitivity, speed, glow, detail, favorites, and immersive controls.

The renderers reuse Halo depth orders and browser frequency ranges, skip hidden browser rendering/analysis, and reduce native frame publication during independent animation. No device-specific speedup has been benchmarked.

## Validation

On September 24, 2026, DSP tests, settings/geometry tests, browser logic regression tests, and unsigned macOS/iOS Simulator builds passed. Browser interaction checks verified response-toggle persistence and gallery scrolling. Earlier in the same session, the locally signed Mac app launched and microphone/local-file playback were exercised.

The newest native toggle/scroll changes are build-verified; native runtime verification of those changes is still pending. Browser microphone capture, Mac system-audio permission, configured MusicKit playback, physical-device behavior, and sustained performance remain open checks. Compilation does not establish runtime behavior.

See the [UI/audio validation report](Afterglow/Docs/UI-Audio-Validation.md), [verification commands](Afterglow/README.md#verification-commands), and [device checklist](Afterglow/Docs/Device-Checklist.md).
