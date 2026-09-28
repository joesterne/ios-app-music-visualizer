# Version 0.3 control audit

September 26, 2026. Browser DOM checks passed; native runtime checks remain pending on a Mac. A working handler does not establish provider authorization or OS audio routing.

| Controls | Behavior and fixes | Verification |
| --- | --- | --- |
| Visual cards, palettes, favorites | Select all 12 visuals and 5 palettes; quick/full controls stay synchronized | DOM assertions |
| Sensitivity, speed, glow, detail, volume, fps | Validated values; shared controls; 30/60 fps; continuous native speed clock | DOM and scheduler; native clock test included, not executed |
| Play/pause, seek, restart/import | Disable unavailable actions; serialize native transitions; prevent late browser file starts | DOM with media doubles; native source review |
| Native previous/next | Enabled only with a playable queue; busy operations cannot overlap | Source review; device check pending |
| Microphone and source choices | Stale permission requests cannot take over newer browser selections; stopped/denied input has visible state | DOM with permission doubles; native device check pending |
| Apple Music | Native Play opens sources when setup or queue is missing; session tokens reject stale account responses | Source review; configured account/device required |
| External services | Open provider; preview offers a fallback link if launch is blocked | DOM launch assertions; actual provider session not exercised |
| Settings, immersive, Escape | Open/close at 390, 890, 1150, and 1440 logical widths; synchronized pressed state | DOM state checks, not visual layout verification |
| Local Save/Restore/Reset/Forget | Explicit snapshot; restore on launch; reset keeps snapshot; forget preserves music | DOM round-trip, malformed/blocked storage; native regression included |
| JSON export/import (preview) | Versioned, size-limited and validated; older asynchronous reads cannot override newer preference actions | DOM export/import, invalid values and race tests |
| Duo poses, visual buttons, tour | Same iframe and audio state; poses cannot reset current/saved visual | Wrapper and scheduler tests |

## Reproduce

Run from the app root with Node 24 or later. Use `npm ci --ignore-scripts --no-audit --no-fund`, then `npm test` for the full portable suite. The lockfile pins the development-only jsdom and Canvas dependencies. The app itself has no third-party runtime dependencies. Individual checks:

```bash
python3 Scripts/build-preview.py
python3 Scripts/build-duo-demo.py
node Tests/test-controls.cjs
node Tests/test-preview.cjs
node Tests/test-duo-demo.cjs
node Tests/test-yosemite-rendering.cjs /tmp/afterglow-render-check
bash Scripts/test-dsp.sh
```

The control suite reports **95 assertions**, including absence of uncaught DOM handler errors. Raster rendering uses the actual Canvas renderer separately from the mocked DOM suite. On a Mac, run `bash Scripts/build-apple.sh`, then follow `Device-Checklist.md`. Native type checking, permissions, MusicKit playback, hardware input, accessibility, and layout inspection are still required.

Repository integration also checks Tron mode/color persistence while preserving the existing Halo and Iron Man renderers.
