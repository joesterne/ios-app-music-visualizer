# Architecture

## Independent playback and rendering

`StudioModel` selects one source at a time and serializes transitions. It stops the previous player/capture, clears measured frames, then starts the chosen input. Apple Music playback starts are serialized so a source change cannot leave an untracked player starting in the background. Explicitly saved rendering preferences and imported files survive relaunch; capture and playback never start automatically at launch.

| Layer | Responsibility |
| --- | --- |
| `LocalAudioPlayer` | `AVAudioFile` decode → `AVAudioPlayerNode` → mixer tap → output; player generation token discards stale completion callbacks after seeks/stops |
| `MicrophoneCapture` | Permission → input-node tap → analyzer; no monitoring connection |
| `MacAudioCapture` | ScreenCaptureKit audio output → PCM buffer → analyzer; excludes this process, ignores screen output, stops on errors |
| `AudioAnalyzer` / `AGAnalyzer` | Audio thread input, thread-safe state, fixed-size FFT, waveform and level snapshots |
| `AppleMusicService` | Authorization, subscription check, paged library, debounced catalog search, MusicKit queue and transport |
| `VisualizerCanvas` | TimelineView and Canvas; eight procedural renderers plus a layered Yosemite scene; explicit reactive/ambient input selection |
| `StudioView` | Phone/tablet layout, desktop sidebar/inspector, source selection, player, immersive view |

## Signal processing

The portable C analyzer uses a 2,048-sample Hann window and radix-2 FFT with a 1,024-sample hop. It derives 64 logarithmic bands from 40 Hz to the lower of 16 kHz and 48% of the input sample rate. Spectral magnitudes use a -72 dB floor and attack/release smoothing. RMS and peak remain linear, with bass/mid/treble aggregates for future renderers. Waveform snapshots contain 256 samples.

The analyzer preallocates its working arrays and FFT tables, and caches frequency-bin ranges per sample rate. Input/reset serialization is separate from the short snapshot-copy lock; steady-state publication skips a contended copy instead of blocking the producer. A display can receive the previous complete frame until a subsequent hop. The visualizer reads snapshots inside its own 30/60 fps timeline; paused motion retains live amplitude updates, while inactive scenes stop rendering. Audio frames do not publish through the shared studio model. A separate 5 Hz timer polls changed playback metadata only for local and Apple Music sources while active. Input/reset mutexes remain, so this is not a hard real-time or lock-free implementation. See `Performance.md` for measured CPU changes and remaining device profiling.

Interleaved input is averaged over channels. The Swift planar path currently uses mono or the first stereo pair; multichannel spatial/downmix support is not included. Anti-phase stereo signals can cancel in the mono mix. Invalid sample values are sanitized and sample-rate changes reset history.

## Source boundaries

Ambient visuals use only a local animation clock; they do not use song position, inferred tempo, fabricated frequency data attributed to a track, or streaming metadata. MusicKit provides playback and music metadata, without piping protected audio into the analyzer. Spotify and other service modes are external launchers. No OAuth tokens, private keys, backend credentials, or downloaded stream caches are included.

Mac system audio is generic OS capture. It is separate from service launchers and never decrypts or bypasses protected content. Permission denial and capture errors are visible. A silent protected source remains silent rather than being replaced by fake measured audio.

## Build structure

Two native app targets share SwiftUI, AVFoundation, MusicKit, and the C analyzer. `#if os(macOS)` contains ScreenCaptureKit and desktop scenes/commands; iOS uses AVAudioSession. The minimum OS versions follow MusicKit’s macOS 14 player availability and the iOS 17 UI/audio APIs used here. Swift 5 language mode is selected; the Duo source requires the Xcode 27.1 SDK.

The HTML preview is a separate Web Audio/Canvas implementation for convenient interaction with the design and local music. It does not establish that native Apple-framework code has compiled or run.

## Yosemite scenery

`YosemiteBackdrop` keeps the immutable image outside the animation timeline. `YosemiteScene` renders a transparent Canvas above it using an identical aspect-fill transform. A cached skyline path clips clouds and birds behind the mountains. Cloud textures are bundled in the asset catalog; there are no image requests at runtime. At maximum detail, the dynamic layer draws six clouds, six birds, three mist banks, and one sunlight gradient. Frame-rate, pause, Reduce Motion, source mode, and scene activity use the shared visualizer scheduler.

The preview embeds the same artwork. Each display canvas caches its resized, palette-tinted backdrop in a WeakMap; the cache invalidates only for size or palette changes. Image decoding happens once, and its completion requests a frame even when motion is paused. Preview cards remain still.

## Duo arrangements and continuous visual time

On iOS 27.1, `DuoWorkspaceView` uses size classes for compact/expanded composition and the system split `ArrangementView` for division-region-aware placement. It does not use device-model strings, `UIScreen.main`, interface-orientation guesses, or hinge angles to infer layout. Standard navigation/toolbars respect safe areas. iOS 17–27.0 and macOS use the classic workspace.

`StudioView` owns `VisualizerClock` independently of its current layout. Main canvases and the classic immersive view read this clock; preview cards retain their fixed time. Moving the renderer across view branches therefore keeps motion time, while source/playback state stays in `StudioModel`. Pause and scene inactivity update the clock without publishing per-frame changes through the shared model.

## Preference and browser state boundaries

`PreferenceStore` saves one versioned, validated UserDefaults snapshot on explicit Save. Slider edits do not encode or write preferences on each change. Restore/reset/forget have separate scopes. Legacy visual preferences are read only for migration. `StudioModel` holds its busy flag across awaited source and playback operations; an import revision prevents a late file import from replacing a newer source choice. MusicKit session generations discard stale account results.

`Web/index.html`, `studio.css`, and `app.js` are the editable browser sources. `build-preview.py` embeds them and both Yosemite assets into the offline HTML. `build-duo-demo.py` then embeds that exact preview in one persistent iframe. Pose messages carry layout only; visual selections synchronize separately so pose changes cannot overwrite the current or restored visual.

Browser source and preference-import operations use generation tokens. Late permission results release their streams without taking over the selected source. localStorage failures are caught; validated JSON export/import provides a portable backup. The scheduler coalesces thumbnail work, caps main-canvas resolution and 30/60 fps cadence, skips unused waveform generation, and sleeps when both motion and measured input are idle.
