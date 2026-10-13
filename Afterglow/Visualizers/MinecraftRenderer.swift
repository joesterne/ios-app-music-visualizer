import SwiftUI

/// A scrolling block world kept separate from the signal renderers.
/// All motion comes from VisualizerClock; audio drives ore glow, torches, the pickaxe and orbs.
enum MinecraftRenderer {
    private static let oreColors: [UInt32] = [0x1E1E1E, 0xD8AF93, 0xF7D33C, 0xE0261F, 0x4EE6E0]

    static func draw(context: GraphicsContext, size: CGSize, palette: VisualPalette,
                     frame: AudioFrame, time: Double, sensitivity: Double, glow: Double, detail: Double) {
        let w = Double(size.width), h = Double(size.height), u = min(w, h)
        guard w > 1, h > 1 else { return }
        let t = time.isFinite ? max(0, time) : 0
        let quality = min(1, max(0, detail))
        let random = MinecraftGeometry.random
        let audio = frame.response(sensitivity)
        let energy = audio.energy
        func band(_ from: Int, _ to: Int) -> Double {
            var sum = 0.0
            for i in from..<max(from, min(to, frame.bands.count)) { sum += Double(frame.bands[i]) }
            return AudioResponse.band(sum / Double(to - from), gain: sensitivity)
        }
        let levels = [0, band(8, 24) * 0.6, band(8, 24), band(0, 8), band(36, 64)]
        let b = max(4, (u / 20).rounded()), p = b / 16
        var c = context
        c.blendMode = .normal

        // A two-minute day: sun and moon trade places on opposite sides of one arc.
        let angle = t / 120 * .pi * 2, daylight = 0.5 + 0.5 * cos(angle)
        c.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(stops: [
            .init(color: mix(0x0B1030, 0x6F9CFF, daylight), location: 0),
            .init(color: mix(0x1B2350, 0xB7D0FF, daylight), location: 0.6)
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        for i in 0..<Int(20 + quality * 40) {
            let n = Double(i), star = max(1, b * 0.09)
            box(&c, random(n + 600) * w, random(n + 700) * h * 0.55, star, star, 0xFFFFFF,
                (1 - daylight) * (0.4 + 0.6 * random(n + 800)))
        }
        celestial(&c, w * 0.5 + w * 0.4 * sin(angle), h * 0.5 - h * 0.4 * cos(angle), b, day: true)
        celestial(&c, w * 0.5 - w * 0.4 * sin(angle), h * 0.5 + h * 0.4 * cos(angle), b, day: false)
        for i in 0..<4 {
            let n = Double(i), cloud = b * (4 + random(n + 40) * 5), span = w + cloud * 2
            let raw = (random(n + 50) * span - t * b * 0.35).truncatingRemainder(dividingBy: span)
            let x = (raw < 0 ? raw + span : raw) - cloud, y = h * (0.07 + random(n + 60) * 0.12)
            box(&c, x, y, cloud, b * 0.7, 0xFFFFFF, 0.35 + daylight * 0.5)
            box(&c, x + cloud * 0.2, y - b * 0.35, cloud * 0.45, b * 0.4, 0xFFFFFF, 0.35 + daylight * 0.5)
        }

        // The world scrolls left; columns are addressed by world index.
        let scroll = MinecraftGeometry.scroll(at: t), first = Int(floor(scroll))
        let offset = (scroll - floor(scroll)) * b, base = Int(floor(h * 0.8 / b))
        let columns = Int(ceil(w / b)) + 2
        let speckles = quality > 0.15 ? Int(1 + quality * 3) : 0
        func texture(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ seed: Double, _ hex: UInt32) {
            for k in 0..<speckles {
                let kx = floor(random(seed + Double(k) * 3.1) * 4), ky = floor(random(seed + Double(k) * 5.7) * 4)
                box(&c, x + kx * b / 4, y + ky * b / 4, b / 4, b / 4, hex, 0.35)
            }
        }
        var glows: [(Double, Double, Int)] = [], torches: [(Double, Double, Double)] = []
        for i in -1..<columns {
            let index = first + i, info = MinecraftGeometry.column(index)
            let x = Double(i) * b - offset, top = Double(base - info.height) * b
            var row = 0
            while top + Double(row) * b < h {
                let y = top + Double(row) * b, seed = Double(index * 97 + row * 13)
                if row == 0 {
                    box(&c, x, y, b, b, 0x8A5A35); texture(&c, x, y, seed, 0x6B4426)
                    box(&c, x, y, b, b * 0.28, 0x5FA83A); box(&c, x + b * 0.25, y + b * 0.28, b / 4, b / 8, 0x5FA83A)
                } else if row < 4 {
                    box(&c, x, y, b, b, 0x7B5233); texture(&c, x, y, seed, 0x5F3E25)
                } else {
                    box(&c, x, y, b, b, row > 11 ? 0x55565C : 0x7F7F7F)
                    texture(&c, x, y, seed, row > 11 ? 0x3F4045 : 0x6A6A6A)
                    if let ore = MinecraftGeometry.ore(column: index, depth: row) {
                        for (ox, oy) in [(0.15, 0.2), (0.55, 0.15), (0.3, 0.55), (0.65, 0.6)] {
                            box(&c, x + b * ox, y + b * oy, b * 0.22, b * 0.22, oreColors[ore])
                        }
                        if ore > 1 { glows.append((x, y, ore)) }
                    }
                }
                if row < 3 { box(&c, x, y, b, b * 0.06, 0x000000, 0.08) }
                row += 1
            }
            switch info.feature {
            case .tree:
                for k in 1...4 {
                    box(&c, x + b * 0.1, top - Double(k) * b, b * 0.8, b, 0x6B4F2A)
                    box(&c, x + b * 0.3, top - Double(k) * b, b * 0.12, b, 0x4F3A1F)
                }
                for (lx, ly) in [(-1.0, -5.0), (0, -5), (1, -5), (-1, -4), (1, -4), (0, -6)] {
                    box(&c, x + lx * b, top + ly * b, b, b, 0x3F8A2B)
                    texture(&c, x + lx * b, top + ly * b, Double(index * 41) + lx * 7 + ly, 0x2D6A1F)
                }
            case .torch:
                box(&c, x + b * 0.44, top - b * 0.6, b * 0.13, b * 0.6, 0x8A6A3A)
                torches.append((x + b * 0.5, top - b * 0.65, Double(index)))
            case .creeper:
                creeper(&c, x + b * 0.2, top, b)
            case .plain:
                break
            }
        }

        // The miner steps up and drops down with the blocks under their feet.
        let minerX = (w * 0.36).rounded(), world = scroll + minerX / b
        let column = Int(floor(world)), frac = world - floor(world)
        let h0 = Double(MinecraftGeometry.column(column).height), h1 = Double(MinecraftGeometry.column(column + 1).height)
        let step = min(1, max(0, (frac - 0.6) / 0.3)), ease = step * step * (3 - 2 * step)
        var lift = 0.0
        if h1 > h0 { lift = (h1 - h0) * ease + sin(ease * .pi) * 0.35 }
        else if h1 < h0 && frac > 0.85 { lift = (h1 - h0) * min(1, (frac - 0.85) / 0.15) }
        let feet = (Double(base) - h0 - lift) * b, swing = sin(t * 7)
        limb(&c, minerX, feet - 12 * p, 4 * p, 12 * p, -swing * 0.55, 0x2C307E)
        limb(&c, minerX, feet - 24 * p, 4 * p, 12 * p, swing * 0.5, 0x26878B)
        box(&c, minerX - 2 * p, feet - 24 * p, 4 * p, 12 * p, 0x2FA3A8)
        limb(&c, minerX, feet - 12 * p, 4 * p, 12 * p, swing * 0.55, 0x3B3F9E)
        box(&c, minerX - 4 * p, feet - 32 * p, 8 * p, 8 * p, 0xC69C7B)
        box(&c, minerX - 4 * p, feet - 32 * p, 8 * p, 2.5 * p, 0x4A3222)
        box(&c, minerX - 4 * p, feet - 32 * p, 2 * p, 5 * p, 0x4A3222)
        box(&c, minerX + 2 * p, feet - 28.5 * p, 1.5 * p, 1.5 * p, 0x3A3AA0)
        // The pickaxe swings harder with louder input.
        let chop = -0.9 - swing * 0.5 - (energy * 0.35 + audio.hit * 0.55) * abs(sin(t * 9))
        var arm = c
        arm.translateBy(x: minerX, y: (feet - 23 * p).rounded())
        arm.rotate(by: .radians(chop))
        arm.fill(Path(CGRect(x: -2 * p, y: 0, width: 4 * p, height: 12 * p)), with: .color(Color(hex: 0xC69C7B)))
        arm.fill(Path(CGRect(x: -0.75 * p, y: 9 * p, width: 1.5 * p, height: 11 * p)), with: .color(Color(hex: 0x7A5A30)))
        for k in -4...4 {
            let kx = Double(k) * 1.4 * p - 0.75 * p, ky = 18 * p + Double(abs(k)) * 0.5 * p
            arm.fill(Path(CGRect(x: kx, y: ky, width: 1.5 * p, height: 1.5 * p)), with: .color(Color(hex: 0x4EE6E0)))
        }

        // Night falls over the whole world; light sources are drawn above it.
        box(&c, 0, 0, w, h, 0x060A20, (1 - daylight) * 0.5)
        var light = c
        light.blendMode = .plusLighter
        for (x, y, ore) in glows where levels[ore] > 0.02 {
            box(&light, x - b * 0.2, y - b * 0.2, b * 1.4, b * 1.4, oreColors[ore], levels[ore] * (0.15 + glow * 0.35))
        }
        for (x, y, seed) in torches {
            let flicker = 0.8 + 0.2 * sin(t * 13 + seed * 2.3), r = b * (1 + energy * 1.2 + audio.hit * 0.5) * flicker * 1.6
            var halo = c
            halo.opacity = (0.06 + 0.5 * (1 - daylight)) * (0.4 + glow * 0.6)
            halo.fill(Path(CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFCF5A), Color(hex: 0xFFCF5A).opacity(0)]),
                center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
            box(&c, x - b * 0.1, y - b * 0.12, b * 0.2, b * 0.2, 0xFFE27A)
            box(&c, x - b * 0.05, y - b * 0.06, b * 0.1, b * 0.1, 0xFFF7D0)
        }
        // Experience orbs drift up from the miner in the palette accent.
        var orbs = c
        orbs.addFilter(.shadow(color: palette.accent.opacity(glow), radius: glow * b * 0.6))
        for i in 0..<Int(3 + quality * 6) {
            let n = Double(i), rise = (t * 0.35 + random(n + 900)).truncatingRemainder(dividingBy: 1)
            let orb = p * (2.5 + energy * 2.5 + audio.hit * 1.5)
            let x = minerX + sin(t * 1.3 + n * 2.1) * b * 1.4 - orb / 2, y = feet - b * 2.4 - rise * b * 3
            orbs.fill(Path(CGRect(x: x, y: y, width: orb, height: orb)),
                      with: .color(palette.accent.opacity((1 - rise) * (0.5 + glow * 0.5))))
        }
    }

    private static func celestial(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ b: Double, day: Bool) {
        let s = b * 1.6
        if day {
            box(&c, x - s / 2, y - s / 2, s, s, 0xFFF6B0)
            box(&c, x - s * 0.3, y - s * 0.3, s * 0.6, s * 0.6, 0xFFD84A)
        } else {
            box(&c, x - s / 2, y - s / 2, s, s, 0xE6EBF5)
            box(&c, x - s * 0.2, y - s * 0.25, s * 0.25, s * 0.25, 0xB9C0D0)
            box(&c, x + s * 0.12, y + s * 0.08, s * 0.18, s * 0.18, 0xB9C0D0)
        }
    }

    private static func creeper(_ c: inout GraphicsContext, _ x: Double, _ top: Double, _ b: Double) {
        box(&c, x, top - b * 0.35, b * 0.25, b * 0.35, 0x3F8F32)
        box(&c, x + b * 0.35, top - b * 0.35, b * 0.25, b * 0.35, 0x3F8F32)
        box(&c, x + b * 0.05, top - b * 1.3, b * 0.5, b, 0x5BB54A)
        box(&c, x + b * 0.15, top - b * 1.1, b * 0.12, b * 0.12, 0x7FD06A)
        box(&c, x + b * 0.33, top - b * 0.75, b * 0.12, b * 0.12, 0x3F8F32)
        box(&c, x - b * 0.1, top - b * 2.1, b * 0.8, b * 0.8, 0x5BB54A)
        box(&c, x + b * 0.02, top - b * 1.9, b * 0.18, b * 0.18, 0x101410)
        box(&c, x + b * 0.42, top - b * 1.9, b * 0.18, b * 0.18, 0x101410)
        box(&c, x + b * 0.22, top - b * 1.72, b * 0.2, b * 0.32, 0x101410)
    }

    private static func limb(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ width: Double,
                             _ height: Double, _ angle: Double, _ hex: UInt32) {
        var g = c
        g.translateBy(x: x.rounded(), y: y.rounded())
        g.rotate(by: .radians(angle))
        g.fill(Path(CGRect(x: -width / 2, y: 0, width: width, height: height)), with: .color(Color(hex: hex)))
    }

    /// Pixel-snapped rectangles keep block edges crisp at every scale.
    private static func box(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ width: Double, _ height: Double,
                            _ hex: UInt32, _ alpha: Double = 1) {
        let rect = CGRect(x: x.rounded(), y: y.rounded(), width: ceil(width), height: ceil(height))
        c.fill(Path(rect), with: .color(Color(hex: hex).opacity(alpha)))
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ k: Double) -> Color {
        func channel(_ shift: UInt32) -> Double {
            let from = Double((a >> shift) & 255), to = Double((b >> shift) & 255)
            return (from * (1 - k) + to * k) / 255
        }
        return Color(.sRGB, red: channel(16), green: channel(8), blue: channel(0), opacity: 1)
    }
}
