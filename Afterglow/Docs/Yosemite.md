# Yosemite visualizer

Added September 26, 2026. Select **Yosemite**, the first visualizer card, in the native iPhone/iPad/Mac studio. The standalone preview starts in Yosemite mode.

The scene looks into a Yosemite-inspired valley from a fixed camera: sunlit granite cliffs, a distant dome, pine forest, and a waterfall in the background artwork. Moving clouds pass behind the cliff silhouette, a small flock glides over the valley, and thin mist banks drift through the trees. This is generated scenic artwork, not a live camera, an exact survey, or a photograph of current conditions. The waterfall belongs to the still background; it is not separately animated.

| Control | Yosemite behavior |
| --- | --- |
| Motion speed | Cloud drift, mist drift, bird flight and wing motion |
| Detail | Number of cloud layers, birds, and mist banks |
| Glow | Strength of sunlight and mist |
| Sensitivity | Light response to measured audio amplitude |
| Palette | A restrained color wash; Glacier also cools the sunlight |
| Pause / Reduce Motion | Freezes the motion clock; live audio can still change light |
| 30 / 60 fps | Native rendering preference; browser preview caps at 60 fps |

Local files, microphone, and permitted Mac system audio drive the light with measured RMS. Ambient and streaming companion modes use independent local animation, just like the other visualizers. Yosemite adds no service access or music permissions.

## Artwork and rendering

- `Assets.xcassets/YosemiteLandscape.imageset/YosemiteLandscape.png`: generated 1672 × 941 opaque landscape.
- `Assets.xcassets/YosemiteCloud.imageset/YosemiteCloud.png`: generated 2172 × 724 cloud sprite with transparent background.
- Native: `Visualizers/YosemiteScene.swift`, with its static backdrop outside `TimelineView`.
- Preview: the `YOSEMITE RENDERER` block in `Preview.html`; the matching PNGs are embedded so the file works offline.

Both renderers center-crop the same landscape to fill the view and align animation in the artwork's coordinates. Portrait focuses on the central valley and distant dome. Landscape and immersive views reveal the full overlook. The cached skyline mask is specific to this artwork: update it in both renderers if replacing the landscape.

After replacing an asset, run `python3 Scripts/embed-preview-assets.py` to refresh the standalone preview. Adding Swift source files requires `python3 Scripts/generate-project.py`; opening the included project does not.

## Verification

The actual JavaScript Canvas renderer was rendered in Skia with `@napi-rs/canvas` at desktop, wide, phone, and thumbnail sizes. Two different animation times were visually inspected. Automated checks cover changing motion, identical paused frames, light response, static-background reuse, palette/resize invalidation, and the loading fallback. The shared preview scheduler tests also pass.

For the optional development-only render check, install `@napi-rs/canvas` in your development environment, then run `node Tests/test-yosemite-rendering.cjs [output-directory]`. This dependency is not needed by either app or the HTML preview.

Swift syntax and project resources were checked in Linux. Native compilation, Swift type checking, Apple-device rendering, browser DOM/layout QA, and device performance still need the Xcode/device checks in `Device-Checklist.md`. No native frame-rate or power measurements are claimed.

## Asset generation record

Both assets were generated using the built-in image-generation tool. The landscape used an opaque background; the cloud used transparent-background generation. No external photographs were downloaded. The generated files are included above without post-generation raster edits.

Final landscape prompt:

> Use case: photorealistic-natural. Asset type: background plate for an animated scenic music visualizer, NOT a UI mockup. Primary request: a serene cinematic view overlooking Yosemite Valley from Tunnel View, with immense recognizable El Capitan granite cliff on the left, forested Cathedral Rocks on the right, distant Half Dome slightly right of center and a deep evergreen valley between them. Very wide 16:9 landscape composition, ideally 2048x1152. Upper approximately 38 percent is clear blue-lavender sky with absolutely no clouds, no birds, no sun disk; these will be animated by code later. Granite catches quiet warm late-afternoon light, realistic rock striations and pine tree detail, cool atmospheric depth in the far valley, naturally darker foreground pines at the bottom corners. Small Bridalveil waterfall on right cliff may be subtle. Beautiful sophisticated real landscape photography, natural texture, crisp foreground, soft distant haze, restrained colors, peaceful expansive sense of scale. No illustration or cartoon, no text, no labels, no border, no people, no buildings, no road, no watermark. Static camera background with a large open central sky and valley for a gentle drifting-cloud overlay. Return the finished landscape artwork.

Cloud generation brief: an isolated, elongated, softly billowing white cloud with warm cream highlights, pale lavender shadows, organic edges, and transparent padding in a wide 3:1 composition, suitable for layered drifting sprites over the Yosemite landscape.
