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
        case .tron: break // Drawn above with its own color selection.
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
