# Minecraft

Select **Minecraft**, the seventeenth gallery option, in the native app or browser preview. A blocky miner walks across a scrolling block world of grass, dirt, and stone, stepping up and dropping down with the terrain. Trees, torches, and creepers pass by, and a cross-section of the ground shows coal, iron, gold, redstone, and diamond ores.

## Behavior

- The shared animation clock drives terrain scrolling (1.6 blocks per second), the miner's walk and pickaxe, drifting clouds, and a two-minute day/night cycle with a sun and moon. Pause and Reduce Motion freeze all of it; changing speed continues from the current clock position.
- The world is derived from seeded world-column indices, so the same animation time reproduces the same terrain, features, and ores. Surface height stays between one and six blocks, and neighboring columns differ by at most two so the miner can always walk on.
- Supported audio input drives the light sources: gold ores glow with mids, redstone with bass, and diamond with treble; torch halos, pickaxe swing strength, and experience-orb size follow the overall level. With motion paused, these still respond. Ambient mode uses the existing generated signal.
- Palette changes tint the experience orbs while the world keeps its block colors. Glow controls light accents; Detail controls block texture, star count, and orb count. Favorites and explicit Save preferences include Minecraft.
- Only on-screen columns are drawn each frame, with no stored particles, timers, images, network requests, or third-party assets.

## Code organization

The browser scene lives in `Web/minecraft.js`, which the preview builder embeds before `Web/app.js` and registers in `sceneRenderers`. The native implementation uses `MinecraftRenderer.swift` and a separately testable `MinecraftGeometry.swift` with the same seeds; `VisualRenderer` dispatches it before the signal-based visuals.

After editing web sources, run both `Scripts/build-preview.py` and `Scripts/build-duo-demo.py`. Run `Scripts/generate-project.py` after adding source files.

## Validation

- Portable suite (`npm test`): all seventeen gallery selections, DOM interactions, preference save/restore including Minecraft, and the existing renderer, Duo, and DSP regressions.
- Real Canvas tests (`Tests/test-minecraft-rendering.cjs`): terrain bounds and walkability, all five ores, recurring trees/torches/creepers, identical frozen frames, scrolling frames, band and level response with motion frozen, palette response, day brighter than night, desktop/phone/ultrawide/thumbnail output, and timestamps through 1,000,000 seconds.
- Swift tests (`Scripts/test-minecraft.sh`, run by `Scripts/build-apple.sh`): the same terrain, ore, and feature checks against `MinecraftGeometry`, plus selection/favorite round-trip in `test_tron.swift`.
- The native renderer was written without a local Swift toolchain; the CI Mac and iOS builds are its compilation check. Native runtime and live-audio behavior on devices are unverified.
