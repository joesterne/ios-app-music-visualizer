import SwiftUI

struct VisualizerCanvas: View {
    var style: VisualizerStyle
    var palette: VisualPalette
    var frame: AudioFrame
    var reactive: Bool
    var settings: VisualSettings
    var paused = false
    var preview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var origin = Date()
    @State private var frozen: Double?
    private var stopped: Bool { paused || reduceMotion || preview || scenePhase != .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / (reduceMotion ? 15 : settings.fps), paused: stopped)) { timeline in
            let elapsed = preview ? 7.0 : (frozen ?? timeline.date.timeIntervalSince(origin))
            let time = elapsed * settings.speed
            let input = reactive && !preview ? frame : AudioFrame.ambient(at: time)
            Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                VisualRenderer.draw(context: context, size: size, style: style,
                                    palette: palette, frame: input, time: time,
                                    sensitivity: settings.sensitivity, glow: settings.glow,
                                    detail: preview ? 0.3 : settings.detail,
                                    tronMode: settings.tronMode, tronPalette: settings.tronPalette)
            }
        }
        .onAppear { if stopped { frozen = 0 } }
        .onChange(of: stopped) { _, value in
            if value { frozen = Date().timeIntervalSince(origin) }
            else if let frozen { origin = Date().addingTimeInterval(-frozen); self.frozen = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style == .tron ? "Tron, \(settings.tronMode.title), \(settings.tronPalette.title)" : style.title) visualizer, \(reactive ? "audio reactive" : "ambient animation")")
    }
}

enum VisualRenderer {
    // Bounded, immutable depth orders shared by every Halo frame and thumbnail.
    private static let haloOrders: [[Int]] = (48...96).map { count in
        (0..<count).sorted {
            sin(Double($0) / Double(count) * .pi * 2) < sin(Double($1) / Double(count) * .pi * 2)
        }
    }

    static func draw(context: GraphicsContext, size: CGSize, style: VisualizerStyle,
                     palette: VisualPalette, frame: AudioFrame, time: Double,
                     sensitivity: Double, glow: Double, detail: Double,
                     tronMode: TronMode = .lightCycles, tronPalette: TronPalette = .lightBlue) {
        let width = size.width, height = size.height
        guard width > 1, height > 1 else { return }
        if style == .tron {
            TronRenderer.draw(context: context, size: size, mode: tronMode, palette: tronPalette,
                              frame: frame, time: time, sensitivity: sensitivity, glow: glow, detail: detail)
            return
        }
        var context = context
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(StudioTheme.background))
        let center = CGPoint(x: width * 0.5, y: height * 0.5)
        let colors = palette.colors
        let energy = min(1, Double(frame.rms) * sensitivity * 3)
        context.fill(Path(rect), with: .radialGradient(
            Gradient(colors: [colors[0].opacity(0.095 + energy * 0.10), .clear]),
            center: center, startRadius: 0, endRadius: max(width, height) * 0.6))
        context.blendMode = .plusLighter
        switch style {
        case .aurora: aurora(&context, size, frame, time, colors, sensitivity, glow, detail)
        case .spectrum: spectrum(&context, size, frame, time, colors, sensitivity, glow)
        case .orbit: orbit(&context, size, frame, time, colors, sensitivity, glow, detail)
        case .waveform: waveform(&context, size, frame, time, colors, sensitivity, glow)
        case .tunnel: tunnel(&context, size, frame, time, colors, sensitivity, glow)
        case .constellation: constellation(&context, size, frame, time, colors, sensitivity, glow, detail)
        case .terrain: terrain(&context, size, frame, time, colors, sensitivity, glow, detail)
        case .bloom: bloom(&context, size, frame, time, colors, sensitivity, glow, detail)
        case .halo: halo(&context, size, frame, time, colors, sensitivity, glow, detail)
        case .ironMan: ironMan(&context, size, frame, time, colors, sensitivity, glow, detail)
        case .superMario: mario(&context, size, frame, time, colors, sensitivity, glow)
        case .spaceFlight: spaceFlight(&context, size, frame, time, colors, sensitivity, glow, detail)
        case .tron: break // Drawn above with its own color selection.
        }
    }

    // Fixed object pools and a time-based camera keep flight smooth and bounded.
    private static func spaceFlight(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                                    _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double, _ detail: Double) {
        c.blendMode = .normal
        let w = s.width, h = s.height, unit = min(w, h)
        let energy = min(1, max(0, Double(f.rms) * gain * 3))
        let bank = sin(t * 0.52) * 0.11, rise = cos(t * 0.37) * 0.055
        let cx = w * (0.5 + bank), cy = h * (0.45 + rise)
        func point(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
            CGPoint(x: cx + unit * (x * cos(bank) - y * sin(bank)) / z,
                    y: cy + unit * (x * sin(bank) + y * cos(bank)) / z)
        }
        func line(_ points: [CGPoint], _ color: Color, _ width: Double) {
            var p = Path(); p.addLines(points); c.stroke(p, with: .color(color), lineWidth: width)
        }
        let bounds = CGRect(origin: .zero, size: s)
        c.fill(Path(bounds), with: .color(Color(red: 0.015, green: 0.025, blue: 0.065)))
        c.fill(Path(bounds), with: .radialGradient(Gradient(colors: [colors[1].opacity(0.20 + energy * 0.12), .clear]), center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: max(w, h) * 0.7))
        for i in 0..<Int(90 + detail * 150) {
            let seed = Double(i), angle = seed * 2.399963
            let radius = 0.16 + abs(sin(seed * 43.7)) * 1.5
            let z = 0.16 + (1 - (seed * 0.618 + t * 0.28).truncatingRemainder(dividingBy: 1)) * 3
            let x = cos(angle) * radius, y = sin(angle) * radius
            line([point(x, y, z), point(x, y, z + 0.05 + energy * 0.10)], .white.opacity(0.28 + 0.6 / (z + 1)), 0.5 + 1 / (z + 1))
        }
        // Draw far objects first. Lateral separation increases as objects approach: an automatic dodge.
        let objects = (0..<9).map { i in
            let phase = (Double(i) / 9 - t * 0.045).truncatingRemainder(dividingBy: 1)
            return (i, 0.22 + (phase < 0 ? phase + 1 : phase) * 3.8)
        }
            .sorted { $0.1 > $1.1 }
        for (i, z) in objects {
            let side = i % 2 == 0 ? -1.0 : 1.0
            let x = side * (0.42 + Double(i % 3) * 0.12 + 0.16 / z)
            let y = sin(Double(i) * 2.7) * 0.38
            let p = point(x, y, z), r = unit * (i % 3 == 0 ? 0.22 : 0.07) / z
            guard p.x + r * 2 > 0, p.x - r * 2 < w, p.y + r * 2 > 0, p.y - r * 2 < h else { continue }
            if i % 3 == 0 {
                let rect = CGRect(x: p.x-r, y: p.y-r, width: r*2, height: r*2)
                c.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [colors[i % 3], Color(red: 0.025, green: 0.035, blue: 0.10)]), center: CGPoint(x: p.x-r*0.4, y: p.y-r*0.45), startRadius: 0, endRadius: r*1.7))
                c.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(colors[0].opacity(0.3 + glow*0.35)), lineWidth: 1.5)
                var ring = Path(); ring.addEllipse(in: CGRect(x: p.x-r*1.6, y: p.y-r*0.3, width: r*3.2, height: r*0.6))
                c.stroke(ring, with: .color(colors[2].opacity(0.6)), lineWidth: max(1, r*0.045))
            } else {
                var ship = Path(); ship.addLines([CGPoint(x:p.x,y:p.y-r),CGPoint(x:p.x+r*1.7,y:p.y+r*0.6),CGPoint(x:p.x+r*0.3,y:p.y+r*0.3),CGPoint(x:p.x,y:p.y+r),CGPoint(x:p.x-r*0.3,y:p.y+r*0.3),CGPoint(x:p.x-r*1.7,y:p.y+r*0.6)]); ship.closeSubpath()
                c.fill(ship, with: .color(Color(red: 0.15, green: 0.22, blue: 0.35)))
                c.stroke(ship, with: .color(colors[0]), lineWidth: max(1,r*0.045))
                line([CGPoint(x:p.x-r*0.35,y:p.y+r*0.4),CGPoint(x:p.x-r*0.35,y:p.y+r*(1.2+energy))], colors[2], max(2,r*0.13))
                line([CGPoint(x:p.x+r*0.35,y:p.y+r*0.4),CGPoint(x:p.x+r*0.35,y:p.y+r*(1.2+energy))], colors[2], max(2,r*0.13))
            }
        }
        // Cockpit stays fixed while the starfield banks, preserving the first-person viewpoint.
        for side in [-1.0, 1.0] {
            let edge = side < 0 ? 0.0 : w
            line([CGPoint(x:edge,y:h*0.72),CGPoint(x:w*0.5+side*w*0.27,y:h*0.89),CGPoint(x:w*0.5+side*w*0.16,y:h)], colors[0].opacity(0.6), 2)
        }
        let aim = CGPoint(x:w*0.5,y:h*0.45)
        line([CGPoint(x:aim.x-13,y:aim.y),CGPoint(x:aim.x-5,y:aim.y)], colors[0].opacity(0.55), 1)
        line([CGPoint(x:aim.x+5,y:aim.y),CGPoint(x:aim.x+13,y:aim.y)], colors[0].opacity(0.55), 1)
    }

    private static let marioSprite = ["....RRRRR...", "...RRRRRRRR.", "...BBBSSKS..", "..BSBSSSKSS.", "..BSBBSSSKSS", "...BSSSSKKK.", "....SSSSSS..", "...RRBRR....", "..RRRBRBRR..", ".RRRRBBBBRR.", ".SSRBYYBRSS.", ".SSSBBBBSSS.", "...BBBBBB...", "..BBB..BBB..", ".KKK....KKK.", "KKKK....KKKK"].map { Array($0) }

    // A fixed-size looping course. Camera and jump share world coordinates so Mario clears each pipe.
    private static func mario(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                              _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double) {
        c.blendMode = .normal
        let scale = s.height / 240, width = s.width / scale
        let travel = (max(0, t) * 38).truncatingRemainder(dividingBy: 640)
        let heroX = width * 0.28, camera = travel - heroX
        let energy = min(1, max(0, Double(f.rms) * gain * 3))
        func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) {
            c.fill(Path(CGRect(x: x * scale, y: y * scale, width: w * scale, height: h * scale)), with: .color(color))
        }
        let sky = Color(red: 0.10, green: 0.22, blue: 0.43)
        let grass = Color(red: 0.32, green: 0.77, blue: 0.28)
        let soil = Color(red: 0.56, green: 0.28, blue: 0.13)
        let gold = Color(red: 1, green: 0.77, blue: 0.18)
        box(0, 0, width, 240, sky)
        for i in -1...Int(width / 100 + 2) {
            let x = Double(i) * 100 - (travel * 0.2).truncatingRemainder(dividingBy: 100)
            box(x, 56, 34, 9, .white.opacity(0.7)); box(x + 8, 49, 18, 8, .white.opacity(0.7))
            for j in 0..<5 { box(x + Double(j) * 10, 174 - Double(min(j, 4-j)) * 11, 10, 28 + Double(min(j, 4-j)) * 11, grass.opacity(0.4)) }
        }
        box(0, 190, width, 50, soil); box(0, 188, width, 5, grass)
        for i in -1...Int(width / 16 + 2) {
            let x = Double(i) * 16 - travel.truncatingRemainder(dividingBy: 16)
            box(x, 198, 14, 2, .black.opacity(0.2)); box(x, 218, 14, 2, .black.opacity(0.2)); box(x, 200, 2, 16, .black.opacity(0.2))
        }
        let first = Int(floor(camera / 640)) - 1
        let last = Int(ceil((camera + width) / 640)) + 1
        for lap in first...last {
            let offset = Double(lap) * 640 - camera
            for position in [160.0, 400.0] {
                let x = offset + position
                box(x, 119, 18, 18, gold); box(x + 2, 121, 14, 2, .white.opacity(0.5))
                box(x + 7, 123, 6, 3, soil); box(x + 10, 126, 3, 3, soil); box(x + 7, 129, 3, 2, soil); box(x + 7, 133, 3, 2, soil)
            }
            for position in [280.0, 500.0] {
                let x = offset + position
                box(x - 12, 158, 24, 30, grass); box(x - 16, 150, 32, 10, grass)
                box(x - 8, 161, 4, 27, .white.opacity(0.25)); box(x + 8, 161, 4, 27, .black.opacity(0.25))
            }
            for j in 0..<8 {
                let x = offset + 115 + Double(j) * 48
                let pulse = band(f, j * 8, gain)
                box(x - 2, 92 - pulse * 9, 6, 10, gold)
                box(x - 4, 90 - pulse * 9, 10, 14, gold.opacity(glow * (0.12 + energy * 0.3)))
            }
            box(offset + 610, 76, 3, 112, .white)
            box(offset + 589, 80, 21, 14, colors[0]); box(offset + 606, 71, 10, 6, gold)
        }
        var jump = 0.0
        for obstacle in [280.0, 500.0] {
            let distance = abs(travel - obstacle)
            if distance < 64 { jump = max(jump, 86 * (1 - pow(distance / 64, 2))) }
        }
        let step = Int(t * 10) % 2 == 0 ? -1.0 : 1.0
        let bottom = 188 - jump
        for (row, pixels) in marioSprite.enumerated() {
            for (column, pixel) in pixels.enumerated() {
                let color: Color
                switch pixel {
                case "R": color = .red
                case "B": color = Color(red: 0.12, green: 0.27, blue: 0.85)
                case "S": color = Color(red: 1, green: 0.73, blue: 0.46)
                case "K": color = Color(red: 0.22, green: 0.12, blue: 0.08)
                case "Y": color = gold
                default: continue
                }
                let stride = row > 12 && jump == 0 ? step * (column < 6 ? -1 : 1) : 0
                box(heroX + Double(column - 6) * 2 + stride, bottom - 32 + Double(row) * 2, 2, 2, color)
            }
        }
    }

    // A projected ringworld: bounded geometry, with spectrum-driven energy spires.
    private static func halo(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                             _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double, _ detail: Double) {
        let unit = min(s.width, s.height)
        let radius = unit * 0.39
        let tilt = -0.34 + sin(t * 0.07) * 0.08
        let flatten = 0.48 + sin(t * 0.09) * 0.08
        func point(_ a: Double, _ r: Double, _ lift: Double = 0) -> CGPoint {
            let x = cos(a) * r, y = sin(a) * r * flatten - lift
            return CGPoint(x: s.width * 0.5 + x * cos(tilt) - y * sin(tilt),
                           y: s.height * 0.47 + x * sin(tilt) + y * cos(tilt))
        }
        let starCount = Int(30 + detail * 65)
        for i in 0..<starCount {
            let seed = Double(i)
            let x = (sin(seed * 127.1) * 43758.5453).truncatingRemainder(dividingBy: 1)
            let y = (sin(seed * 311.7) * 96321.9123).truncatingRemainder(dividingBy: 1)
            let r = (i % 7 == 0 ? 1.3 : 0.65) * max(0.65, unit / 350)
            let star = CGRect(x: abs(x) * s.width, y: abs(y) * s.height, width: r * 2, height: r * 2)
            c.fill(Path(ellipseIn: star), with: .color(colors[2].opacity(0.18 + 0.3 * (0.5 + 0.5 * sin(t * 0.4 + seed)))))
        }
        let segments = min(96, max(48, Int(48 + detail * 48)))
        // Back-to-front ordering gives the ring a solid inner surface.
        let order = haloOrders[segments - 48]
        for i in order {
            let a = Double(i) / Double(segments) * .pi * 2
            let b = Double(i + 1) / Double(segments) * .pi * 2
            let signal = band(f, i * 64 / segments, gain)
            let inner = radius * 0.82
            var panel = Path()
            panel.move(to: point(a, inner)); panel.addLine(to: point(a, radius))
            panel.addLine(to: point(b, radius)); panel.addLine(to: point(b, inner)); panel.closeSubpath()
            c.fill(panel, with: .color(colors[i % 5 == 0 ? 1 : 0].opacity(0.10 + signal * 0.18)))
            var seam = Path(); seam.move(to: point(a, inner)); seam.addLine(to: point(a, radius))
            c.stroke(seam, with: .color(colors[1].opacity(0.35)), lineWidth: 0.7)
            if i % 3 == 0 {
                var spire = Path(); spire.move(to: point(a, radius * 0.91))
                spire.addLine(to: point(a, radius * 0.91, unit * (0.025 + signal * 0.13)))
                trace(&c, spire, color: colors[2], width: 1.2, glow: glow, opacity: 0.4 + signal * 0.5)
            }
        }
        for factor in [0.82, 0.86, 1.0] {
            var rim = Path()
            for i in 0...128 {
                let p = point(Double(i) / 128 * .pi * 2, radius * factor)
                if i == 0 { rim.move(to: p) } else { rim.addLine(to: p) }
            }
            trace(&c, rim, color: colors[factor == 0.86 ? 1 : 0], width: factor == 0.86 ? 0.8 : 2, glow: glow)
        }
        for pulse in 0..<3 {
            var arc = Path()
            for i in 0...18 {
                let a = t * 0.22 + Double(pulse) * .pi * 2 / 3 + Double(i) * 0.018
                let p = point(a, radius * 0.96)
                if i == 0 { arc.move(to: p) } else { arc.addLine(to: p) }
            }
            trace(&c, arc, color: colors[2], width: 2.5, glow: glow, opacity: 0.9)
        }
    }

    private static func ironMan(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                                _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double, _ detail: Double) {
        let unit = min(s.width, s.height)
        let center = CGPoint(x: s.width * 0.5, y: s.height * 0.46)
        let red = Color(hex: 0xFF493B), gold = Color(hex: 0xFFD080)
        let cyan = Color(hex: 0x75E8FF)
        let energy = min(1, max(0, Double(f.rms) * gain * 3))
        let radius = unit * 0.29
        func point(_ a: Double, _ r: Double) -> CGPoint {
            CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        }
        func arc(_ r: Double, _ start: Double, _ length: Double) -> Path {
            var p = Path()
            for i in 0...24 {
                let q = point(start + length * Double(i) / 24, r)
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            return p
        }
        let aura = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        c.fill(aura, with: .radialGradient(Gradient(colors: [cyan.opacity(0.12 + energy * 0.16), .clear]),
                                         center: center, startRadius: 0, endRadius: radius))
        // Segmented red/gold armor rotates around the stationary reactor core.
        for ring in 0..<3 {
            let r = radius * (0.78 + Double(ring) * 0.19)
            for segment in 0..<6 {
                let a = Double(segment) * .pi / 3 + t * (ring % 2 == 0 ? 0.10 : -0.14)
                let color = ring == 1 ? red : gold
                trace(&c, arc(r, a, .pi / 3 * 0.76), color: color,
                      width: ring == 1 ? 4 : 1.4, glow: glow * 0.7, opacity: 0.6)
            }
        }
        let ticks = Int(36 + detail * 36)
        for i in 0..<ticks {
            let a = Double(i) / Double(ticks) * .pi * 2 - .pi / 2
            let signal = band(f, i * 64 / ticks, gain)
            let r = radius * 1.23
            var p = Path(); p.move(to: point(a, r))
            p.addLine(to: point(a, r + unit * (0.008 + signal * 0.045)))
            c.stroke(p, with: .color((i % 6 == 0 ? gold : colors[0]).opacity(0.35 + signal * 0.6)), lineWidth: i % 6 == 0 ? 2 : 1)
        }
        for vane in 0..<12 {
            let a = Double(vane) * .pi / 6
            var p = Path(); p.move(to: point(a, radius * 0.45))
            p.addLine(to: point(a + 0.12, radius * 0.66))
            trace(&c, p, color: cyan, width: 3, glow: glow, opacity: 0.45 + band(f, vane * 5, gain) * 0.5)
        }
        trace(&c, arc(radius * 0.70, 0, .pi * 2), color: cyan, width: 2, glow: glow)
        // The triangular white-blue heart gives the reactor a distinct silhouette.
        var core = Path()
        for i in 0..<3 {
            let p = point(-.pi / 2 + Double(i) * .pi * 2 / 3, radius * (0.40 + energy * 0.035))
            if i == 0 { core.move(to: p) } else { core.addLine(to: p) }
        }
        core.closeSubpath()
        c.fill(core, with: .color(cyan.opacity(0.16 + energy * 0.30)))
        trace(&c, core, color: .white, width: 2.5, glow: glow, opacity: 0.95)
        // Corner brackets frame the HUD without relying on tiny decorative text.
        for sx in [-1.0, 1.0] {
            for sy in [-1.0, 1.0] {
                let x = center.x + sx * unit * 0.43, y = center.y + sy * unit * 0.35
                var p = Path(); p.move(to: CGPoint(x: x - sx * unit * 0.065, y: y))
                p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y - sy * unit * 0.05))
                trace(&c, p, color: red, width: 1.4, glow: glow * 0.5, opacity: 0.65)
            }
        }
    }

    private static func trace(_ context: inout GraphicsContext, _ path: Path, color: Color,
                              width: Double = 1.8, glow: Double, opacity: Double = 1) {
        if glow > 0.04 {
            var haze = context
            haze.addFilter(.blur(radius: 3 + glow * 7))
            haze.stroke(path, with: .color(color.opacity(opacity * glow * 0.65)),
                        style: StrokeStyle(lineWidth: width * 3, lineCap: .round, lineJoin: .round))
        }
        context.stroke(path, with: .color(color.opacity(opacity)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    private static func band(_ frame: AudioFrame, _ index: Int, _ gain: Double) -> Double {
        min(1, max(0, Double(frame.bands[abs(index) % frame.bands.count]) * gain))
    }
    private static func aurora(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                               _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double, _ detail: Double) {
        let layers = Int(5 + detail * 8)
        let steps = Int(100 + detail * 100)
        for line in 0..<layers {
            let l = Double(line)
            var p = Path()
            for i in 0...steps {
                let x = Double(i) / Double(steps)
                let envelope = pow(sin(x * .pi), 0.9)
                let signal = band(f, Int(x * 63), gain)
                let wave = sin(x * 8 + t * 0.65 + l * 0.19) * 0.16
                    + sin(x * 15 - t * 0.34 + l * 0.11) * 0.08
                let y = s.height * (0.5 + envelope * wave * (0.65 + signal) + (l - Double(layers) / 2) * 0.009)
                let point = CGPoint(x: x * s.width, y: y)
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            trace(&c, p, color: colors[line % 3], width: 1.25, glow: glow,
                  opacity: 0.28 + 0.5 * Double(line + 1) / Double(layers))
        }
    }
    private static func spectrum(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                                 _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double) {
        let usable = s.width * 0.84, gap = usable / 64
        let base = s.height * 0.72
        for i in 0..<64 {
            let level = band(f, i, gain)
            let h = max(2, level * s.height * 0.51)
            let x = s.width * 0.08 + Double(i) * gap
            let rect = CGRect(x: x, y: base - h, width: max(1, gap * 0.58), height: h)
            let path = Path(roundedRect: rect, cornerRadius: min(3, gap * 0.24))
            let color = colors[i < 22 ? 0 : i < 44 ? 1 : 2]
            c.fill(path, with: .linearGradient(Gradient(colors: [color, color.opacity(0.25)]),
                                               startPoint: CGPoint(x: x, y: base - h), endPoint: CGPoint(x: x, y: base)))
            c.fill(Path(roundedRect: CGRect(x: x, y: base + 8, width: max(1, gap * 0.58), height: h * 0.18), cornerRadius: 2),
                   with: .linearGradient(Gradient(colors: [color.opacity(0.16), .clear]),
                                         startPoint: CGPoint(x: x, y: base), endPoint: CGPoint(x: x, y: base + h * 0.2)))
        }
    }
    private static func orbit(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                              _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double, _ detail: Double) {
        let radius = min(s.width, s.height) * 0.24
        let center = CGPoint(x: s.width / 2, y: s.height / 2)
        let count = Int(90 + detail * 90)
        for ring in 0..<3 {
            var p = Path()
            for i in 0...count {
                let theta = Double(i) / Double(count) * .pi * 2
                let signal = band(f, Int(Double(i % count) / Double(count) * 63), gain)
                let r = radius * (1 + Double(ring) * 0.22 + signal * 0.26)
                let angle = theta + t * (ring % 2 == 0 ? 0.08 : -0.06)
                let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            trace(&c, p, color: colors[ring], glow: glow, opacity: 0.8 - Double(ring) * 0.15)
        }
        for i in 0..<64 {
            let theta = Double(i) / 64 * .pi * 2 + t * 0.08
            let signal = band(f, i, gain)
            let r = radius * 0.82
            let p1 = CGPoint(x: center.x + cos(theta) * r, y: center.y + sin(theta) * r)
            let p2 = CGPoint(x: center.x + cos(theta) * (r - signal * radius * 0.35),
                             y: center.y + sin(theta) * (r - signal * radius * 0.35))
            var p = Path(); p.move(to: p1); p.addLine(to: p2)
            c.stroke(p, with: .color(colors[0].opacity(0.5)), lineWidth: 2)
        }
    }
    private static func waveform(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                                 _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double) {
        for layer in 0..<3 {
            var p = Path()
            for i in f.waveform.indices {
                let x = Double(i) / Double(f.waveform.count - 1)
                let amplitude = Double(f.waveform[i]) * gain * s.height * (0.28 - Double(layer) * 0.05)
                let point = CGPoint(x: s.width * (0.05 + x * 0.9), y: s.height / 2 + amplitude + Double(layer - 1) * 9)
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            trace(&c, p, color: colors[layer], width: layer == 0 ? 2.2 : 1.2, glow: glow,
                  opacity: layer == 0 ? 0.9 : 0.3)
        }
    }
    private static func tunnel(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                               _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double) {
        let center = CGPoint(x: s.width / 2, y: s.height / 2)
        for layer in 0..<18 {
            let progress = (Double(layer) / 18 + t * 0.055).truncatingRemainder(dividingBy: 1)
            let radius = pow(progress, 2) * max(s.width, s.height) * 0.75
            let rotation = t * 0.07 + (1 - progress) * 1.3
            let scale = 1 + band(f, layer * 3, gain) * 0.1
            var p = Path()
            for side in 0..<7 {
                let angle = Double(side % 6) / 6 * .pi * 2 + rotation
                let point = CGPoint(x: center.x + cos(angle) * radius * scale,
                                    y: center.y + sin(angle) * radius * scale)
                if side == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            trace(&c, p, color: colors[layer % 3], width: 0.8 + progress,
                  glow: glow * 0.7, opacity: sin(progress * .pi) * 0.7)
        }
    }
    private static func constellation(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                                      _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double, _ detail: Double) {
        let count = Int(28 + detail * 55)
        var points: [CGPoint] = []
        for i in 0..<count {
            let seed = Double(i)
            let x = 0.5 + sin(seed * 127.1 + t * 0.025) * 0.43
            let y = 0.5 + cos(seed * 311.7 + t * 0.033) * 0.4
            points.append(CGPoint(x: x * s.width, y: y * s.height))
        }
        let threshold = min(s.width, s.height) * 0.22
        for i in 0..<count {
            for j in (i + 1)..<count {
                let d = hypot(points[i].x - points[j].x, points[i].y - points[j].y)
                if d < threshold {
                    var p = Path(); p.move(to: points[i]); p.addLine(to: points[j])
                    c.stroke(p, with: .color(colors[i % 3].opacity((1 - d / threshold) * 0.24)), lineWidth: 0.7)
                }
            }
            let r = 1 + band(f, i, gain) * 3.6
            let dot = Path(ellipseIn: CGRect(x: points[i].x - r, y: points[i].y - r, width: r * 2, height: r * 2))
            var halo = c; halo.addFilter(.blur(radius: 5 * glow))
            halo.fill(dot, with: .color(colors[i % 3].opacity(0.8)))
            c.fill(dot, with: .color(colors[i % 3]))
        }
    }
    private static func terrain(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                                _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double, _ detail: Double) {
        let rows = Int(12 + detail * 15)
        for row in 0..<rows {
            let z = Double(row) / Double(rows)
            let scale = 0.15 + z * 0.85
            var p = Path()
            for i in 0..<64 {
                let x = Double(i) / 63
                let ridge = band(f, i, gain) * (0.6 + 0.4 * sin(x * 12 + z * 7 + t * 0.3))
                let point = CGPoint(x: s.width * (0.5 + (x - 0.5) * scale * 1.7),
                                    y: s.height * (0.38 + z * 0.56 - ridge * scale * 0.25))
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            trace(&c, p, color: colors[row % 3], width: 0.7 + z, glow: glow * 0.6, opacity: 0.12 + z * 0.58)
        }
    }
    private static func bloom(_ c: inout GraphicsContext, _ s: CGSize, _ f: AudioFrame,
                              _ t: Double, _ colors: [Color], _ gain: Double, _ glow: Double, _ detail: Double) {
        let center = CGPoint(x: s.width / 2, y: s.height / 2)
        let radius = min(s.width, s.height) * 0.28
        for layer in 0..<Int(5 + detail * 7) {
            let l = Double(layer)
            var p = Path()
            for i in 0...240 {
                let theta = Double(i) / 240 * .pi * 2
                let signal = band(f, Int(Double(i) / 241 * 63), gain)
                let petal = 0.65 + 0.2 * sin(theta * 6 + t * 0.3 + l * 0.13)
                let r = radius * (petal + signal * 0.25) * (0.6 + l * 0.075)
                let angle = theta + t * 0.04 + l * 0.035
                let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
            trace(&c, p, color: colors[layer % 3], width: 1.1, glow: glow, opacity: 0.25 + l * 0.035)
        }
    }
}
