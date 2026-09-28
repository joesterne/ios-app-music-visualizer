# Performance refactor — September 25, 2026

## Measured audio-analysis cost

Same host and compiler for both versions: Linux x86_64, GCC 13.3.0, `-O2`, no fast-math. Each trial processes 6,000 stereo blocks of 1,024 frames and copies a full display snapshot after each block. Inputs and setup are outside the timed section; each trial warms up with 64 blocks. Results below are the median of seven trials. These are analyzer CPU timings, not end-to-end playback latency or iPhone/Mac frame-rate measurements.

| Input rate | Original, µs/block | Refactored, µs/block | Less CPU time |
| --- | ---: | ---: | ---: |
| 44.1 kHz | 49.860 | 37.252 | 25.3% |
| 48 kHz | 49.129 | 35.121 | 28.5% |
| 96 kHz | 47.339 | 34.819 | 26.4% |

Observed trial ranges: original 49.451–50.042 / 48.702–49.660 / 46.739–47.830 µs; refactored 35.639–40.700 / 35.024–36.060 / 34.085–35.031 µs, in table order. Host scheduling and device/compiler differences affect results.

Reproduce the current workload:

```bash
bash Scripts/benchmark-dsp.sh
```

To compare an earlier revision using the identical harness, supply that revision's `Core/AGAnalyzer.c`:

```bash
bash Scripts/benchmark-dsp.sh /path/to/previous/AGAnalyzer.c
python3 Tests/compare_dsp.py /path/to/previous/AGAnalyzer.c
```

## Changes

- FFT twiddles, bit-reversal indices, and the Hann window are initialized once. Logarithmic band boundaries and zone membership are recomputed only on sample-rate changes.
- Each band finds maximum squared magnitude before taking one square root. The FFT size, hop size, frequency range, attack/release response, RMS, and waveform resolution are unchanged.
- Display snapshots have a separate short lock. A renderer no longer waits behind an entire input buffer's FFT work. Steady-state audio publication uses `trylock`; if a display copy is in progress, it keeps the previous complete frame and publishes on a later hop. Input/reset still use a mutex, so this is not a lock-free or hard real-time implementation. Precomputed tables trade some additional per-analyzer memory for lower steady-state CPU use.
- The visualizer reads measured audio inside its own timeline. There is no 30 Hz `@Published` audio frame on the shared studio model. Playback metadata polls at 5 Hz only for local/Apple Music sources while active; unchanged values do not publish. Other sources and inactive scenes have no metadata timer.
- Equatable visualizer inputs keep playback-position and favorite changes from redrawing unchanged thumbnails. Live amplitude still updates when motion is paused or Reduce Motion is enabled; only motion time freezes. Inactive scenes stop the rendering timeline.
- Ambient modes skip 512 waveform sine evaluations per frame unless the waveform style needs them.
- Constellation rejects distant pairs using squared distance and combines dot paths by color. At maximum detail, 83 per-dot halo operations become three; glow near zero skips halo operations. Geometry and colors are retained, but merging overlapping dots can slightly change additive brightness. Native GPU timing and visual comparison remain unverified.
- The browser preview caches frequency ranges, caps drawing/analysis near 60 fps on faster displays, stops work while hidden, and sleeps during paused ambient mode until an input or resize requests a frame.

## Regression results and remaining checks

- Existing C audio tests and AddressSanitizer/UndefinedBehaviorSanitizer passed. LeakSanitizer was disabled because the host does not support it under process tracing.
- 960 snapshots compared against the original analyzer across mono/stereo, irregular buffer lengths, reset, rate changes from 8–384 kHz, noise, tones, silence, clipping, and nonfinite samples. Maximum absolute difference across bands, waveform, and levels: **1.78813934e-07**, below the 1e-4 tolerance.
- Node VM behavior tests passed for scheduling on 60/120/144 Hz displays, paused ambient sleep, redraw after settings changes, live audio while motion is frozen, cached bin ranges, and background suspension/resume. These use mocked audio and drawing, so they do not establish browser visual/audio quality.
- All 14 Swift files passed syntax parsing. Xcode project membership and configuration files were checked. No Apple SDK type checking, Xcode build, Instruments profile, or physical-device verification was possible on this Linux host.

Run `Scripts/build-apple.sh` on an Apple silicon Mac, then follow `Docs/Device-Checklist.md`. Use an optimized Release build and Instruments Time Profiler, SwiftUI, and Core Animation tools to measure actual frame pacing, audio callback contention, power, and the constellation appearance. Do not infer a device FPS improvement from the portable analyzer benchmark.

Implementation references: Apple's [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview), [equatable()](https://developer.apple.com/documentation/swiftui/view/equatable()), and [GraphicsContext filtering](https://developer.apple.com/documentation/swiftui/graphicscontext/addfilter(_:options:)).

## September 26: version 0.3 control-path refactor

- Thumbnail buffers are reused. Relevant changes queue one redraw; unrelated speed/detail/frame-rate changes avoid thumbnail work. In the actual control-handler regression, 50 consecutive speed events produced **0 thumbnail draws**, while 50 gain events produced **one pass over 9 cards**. This counts work; it is not a frame-rate or wall-time benchmark.
- Browser audio analysis runs only for active input. Waveform samples are synthesized only for the waveform visual. The renderer caps its surface at 3 million pixels and honors both 30 and 60 fps, including during settings changes.
- Native preferences encode/write on explicit Save rather than every slider change. Live input metering has a separate 15 fps timeline. Native visual speed changes integrate elapsed time without jumping.
- The C suite, 87 DOM interaction assertions, scheduler tests, Duo wrapper tests, and actual Yosemite Canvas renderer regression passed. No additional native FPS, power, or CPU percentage improvement is claimed; Apple-device profiling remains required.
