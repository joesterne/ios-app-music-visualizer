import SwiftUI

// The large, immutable landscape lives outside TimelineView. Only the weather layer
// participates in frame updates; both layers use the same centered cover transform.
struct YosemiteBackdrop: View, Equatable {
    let palette: VisualPalette

    var body: some View {
        GeometryReader { proxy in
            let rect = YosemiteScene.cover(in: proxy.size)
            Image("YosemiteLandscape")
                .resizable()
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .overlay(palette.accent.opacity(palette == .monochrome ? 0.035 : 0.055))
                .overlay {
                    LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                           .init(color: .black.opacity(0.42), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

enum YosemiteScene {
    static let imageWidth = 1672.0
    static let imageHeight = 941.0
    private static let cloudImage = Image("YosemiteCloud")

    static func cover(in size: CGSize) -> CGRect {
        let scale = max(size.width / imageWidth, size.height / imageHeight)
        let width = imageWidth * scale, height = imageHeight * scale
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2,
                      width: width, height: height)
    }

    // A cached silhouette keeps the moving cloud layer behind the granite skyline.
    private static let sky: Path = {
        let points: [(Double, Double)] = [
            (0, 0), (1, 0), (1, 0.257), (0.971, 0.245), (0.922, 0.205),
            (0.910, 0.248), (0.896, 0.260), (0.870, 0.234), (0.854, 0.221),
            (0.837, 0.229), (0.823, 0.256), (0.811, 0.292), (0.798, 0.346),
            (0.770, 0.378), (0.751, 0.392), (0.720, 0.367), (0.707, 0.406),
            (0.683, 0.407), (0.675, 0.420), (0.647, 0.453), (0.638, 0.430),
            (0.620, 0.406), (0.605, 0.393), (0.588, 0.396), (0.578, 0.393),
            (0.566, 0.441), (0.552, 0.483), (0.526, 0.483), (0.495, 0.459),
            (0.470, 0.462), (0.449, 0.497), (0.420, 0.472), (0.385, 0.465),
            (0.365, 0.482), (0.353, 0.462), (0.337, 0.452), (0.328, 0.431),
            (0.316, 0.435), (0.287, 0.385), (0.283, 0.322), (0.280, 0.242),
            (0.250, 0.214), (0.225, 0.207), (0.208, 0.182), (0.186, 0.172),
            (0.166, 0.155), (0.145, 0.142), (0.130, 0.136), (0.095, 0.149),
            (0.090, 0.157), (0.060, 0.156), (0.020, 0.162), (0, 0.167)
        ]
        return Path { path in
            for (index, point) in points.enumerated() {
                let p = CGPoint(x: point.0 * imageWidth, y: point.1 * imageHeight)
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }()

    // Position, vertical offset, width, drift. All values are in image coordinates.
    private static let clouds: [(Double, Double, Double, Double)] = [
        (0.04, 0.015, 0.37, 0.0042), (0.50, 0.070, 0.30, 0.0031),
        (0.26, 0.220, 0.27, 0.0022), (0.81, -0.035, 0.43, 0.0050),
        (0.67, 0.270, 0.24, 0.0018), (-0.18, 0.130, 0.32, 0.0035)
    ]
    private static func wrap(_ value: Double, width: Double) -> Double {
        let span = 1 + 2 * width
        return (value + width).truncatingRemainder(dividingBy: span) - width
    }

    static func draw(context: GraphicsContext, size: CGSize, palette: VisualPalette,
                     frame: AudioFrame, time: Double, sensitivity: Double, glow: Double,
                     detail: Double) {
        let rect = cover(in: size), scale = rect.width / imageWidth
        var world = context
        world.translateBy(x: rect.minX, y: rect.minY)
        world.scaleBy(x: scale, y: scale)
        let sprite = world.resolve(cloudImage)
        let energy = min(1, max(0, Double(frame.rms) * sensitivity * 3))

        var atmosphere = world
        atmosphere.clip(to: sky)
        for index in 0..<min(clouds.count, 3 + Int(detail * 3)) {
            let cloud = clouds[index]
            let x = wrap(cloud.0 + time * cloud.3, width: cloud.2)
            let y = cloud.1 + sin(time * 0.024 + Double(index)) * 0.006
            let width = cloud.2 * imageWidth
            var layer = atmosphere
            layer.opacity = index == 2 || index == 4 ? 0.46 : 0.78
            layer.draw(sprite, in: CGRect(x: x * imageWidth, y: y * imageHeight,
                                          width: width, height: width / 3))
        }

        // A small flock glides over the distant valley, without particle emitters.
        var birds = Path()
        for index in 0..<(2 + Int(detail * 4)) {
            let i = Double(index)
            let x = (0.52 + time * 0.0018 + i * 0.016).truncatingRemainder(dividingBy: 1.20) - 0.10
            let y = 0.325 + sin(time * 0.046 + i * 0.65) * 0.028 + i * 0.006
            let p = CGPoint(x: x * imageWidth, y: y * imageHeight)
            let wing = 2.5 + sin(time * 1.7 + i) * 1.1
            birds.move(to: CGPoint(x: p.x - 4, y: p.y - wing))
            birds.addQuadCurve(to: p, control: CGPoint(x: p.x - 1.7, y: p.y - wing))
            birds.addQuadCurve(to: CGPoint(x: p.x + 4, y: p.y - wing),
                               control: CGPoint(x: p.x + 1.7, y: p.y - wing))
        }
        atmosphere.stroke(birds, with: .color(Color(hex: 0x28394B).opacity(0.58)),
                          style: StrokeStyle(lineWidth: 1.15, lineCap: .round))

        // Stretched translucent sprites form thin banks of mist in the valley.
        for index in 0..<(detail > 0.65 ? 3 : 2) {
            let i = Double(index)
            let x = 0.265 + sin(time * 0.032 + i * 1.7) * 0.042
            let y = 0.635 + i * 0.070 + sin(time * 0.024 + i) * 0.008
            var mist = world
            mist.opacity = (0.13 - i * 0.025) * (0.65 + glow * 0.35 + energy * 0.10)
            mist.draw(sprite, in: CGRect(x: x * imageWidth, y: y * imageHeight,
                                         width: imageWidth * 0.48, height: imageHeight * 0.08))
        }

        // Restrained sunlight responds to measured amplitude; scenery never pumps.
        let light = palette == .glacier ? Color(hex: 0xC7EAFF) : Color(hex: 0xFFE1AB)
        var sunlight = world
        sunlight.blendMode = .screen
        sunlight.fill(Path(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)),
                      with: .radialGradient(Gradient(colors: [light.opacity(glow * (0.035 + energy * 0.065)), .clear]),
                                            center: CGPoint(x: imageWidth * 0.22, y: imageHeight * 0.25),
                                            startRadius: 0, endRadius: imageWidth * 0.62))
    }
}
