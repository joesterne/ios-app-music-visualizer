# Architecture

## Independent playback and rendering

`StudioModel` selects one source at a time and serializes transitions. It stops the previous player/capture, clears measured frames, then starts the chosen input. Apple Music playback starts are serialized so a source change cannot leave an untracked player starting in the background. Rendering settings and imported files survive relaunch; capture and playback never start automatically at launch.

| Layer | Responsibility |
| --- | --- |
| `LocalAudioPlayer` | `AVAudioFile` decode → `AVAudioPlayerNode` → mixer tap → output; player generation token discards stale completion callbacks after seeks/stops |
| `MicrophoneCapture` | Permission → input-node tap → analyzer; no monitoring connection |
| `MacAudioCapture` | ScreenCaptureKit audio output → PCM buffer → analyzer; excludes this process, ignores screen output, stops on errors |
| `AudioAnalyzer` / `AGAnalyzer` | Audio thread input, thread-safe state, fixed-size FFT, waveform and level snapshots |
| `AppleMusicService` | Authorization, subscription check, paged library, debounced catalog search, MusicKit queue and transport |
| `VisualizerCanvas` | TimelineView and Canvas; eight procedural renderers; explicit reactive/ambient input selection |
| `StudioView` | Phone/tablet layout, desktop sidebar/inspector, source selection, player, immersive view |

## Signal processing

The portable C analyzer uses a 2,048-sample Hann window and radix-2 FFT with a 1,024-sample hop. It derives 64 logarithmic bands from 40 Hz to the lower of 16 kHz and 48% of the input sample rate. Spectral magnitudes use a -72 dB floor and attack/release smoothing. RMS and peak remain linear, with bass/mid/treble aggregates for future renderers. Waveform snapshots contain 256 samples.

The analyzer preallocates its working arrays. Its mutex protects audio writes, resets, and main-thread frame copies. A main-thread timer samples the analyzer at 30 Hz, independent of the visual renderer’s 30/60 fps preference. This is a practical prototype design, not a hard real-time guarantee; profile audio-thread contention on devices before production optimization. A lock-free single-producer mailbox can replace the mutex if measured contention warrants it.

Interleaved input is averaged over channels. The Swift planar path currently uses mono or the first stereo pair; multichannel spatial/downmix support is not included. Anti-phase stereo signals can cancel in the mono mix. Invalid sample values are sanitized and sample-rate changes reset history.

## Source boundaries

Ambient visuals use only a local animation clock; they do not use song position, inferred tempo, fabricated frequency data attributed to a track, or streaming metadata. MusicKit provides playback and music metadata, without piping protected audio into the analyzer. Spotify and other service modes are external launchers. No OAuth tokens, private keys, backend credentials, or downloaded stream caches are included.

Mac system audio is generic OS capture. It is separate from service launchers and never decrypts or bypasses protected content. Permission denial and capture errors are visible. A silent protected source remains silent rather than being replaced by fake measured audio.

## Build structure

Two native app targets share SwiftUI, AVFoundation, MusicKit, and the C analyzer. `#if os(macOS)` contains ScreenCaptureKit and desktop scenes/commands; iOS uses AVAudioSession. The minimum OS versions follow MusicKit’s macOS 14 player availability and the iOS 17 UI/audio APIs used here. Swift 5 language mode is selected for compatibility with Xcode 16 and newer SDKs.

The HTML preview is a separate Web Audio/Canvas implementation for convenient interaction with the design and local music. It does not establish that native Apple-framework code has compiled or run.
