import SwiftUI

enum TronRenderer {
    static func draw(context: GraphicsContext, size: CGSize, mode: TronMode, palette: TronPalette,
                     frame: AudioFrame, time: Double, sensitivity: Double, glow: Double, detail: Double) {
        var c = context
        let bounds = CGRect(origin: .zero, size: size)
        let color = palette.color
        let energy = min(1, max(0, Double(frame.rms) * sensitivity * 3))
        c.fill(Path(bounds), with: .color(Color(hex: 0x030910)))
        c.fill(Path(bounds), with: .radialGradient(
            Gradient(colors: [color.opacity(0.065 + energy * 0.05), .clear]),
            center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 0,
            endRadius: max(size.width, size.height) * 0.65))
        c.blendMode = .plusLighter
        grid(&c, size: size, color: color)
        switch mode {
        case .lightCycles: cycles(&c, size: size, color: color, time: time, energy: energy, glow: glow, detail: detail)
        case .identityDiscs: discs(&c, size: size, color: color, time: time, energy: energy, glow: glow, detail: detail)
        case .circuitExpansion: circuits(&c, size: size, color: color, time: time, energy: energy, glow: glow)
        }
    }

    private static func grid(_ c: inout GraphicsContext, size: CGSize, color: Color) {
        let spacing = max(18, min(size.width, size.height) / 14)
        var path = Path()
        for x in stride(from: 0.0, through: size.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: 0.0, through: size.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
        }
        c.stroke(path, with: .color(color.opacity(0.055)), lineWidth: 0.7)
    }

    private static func neon(_ c: inout GraphicsContext, path: Path, color: Color,
                             width: Double, glow: Double, opacity: Double = 1) {
        if glow > 0.01 {
            var haze = c
            haze.addFilter(.blur(radius: 2 + glow * 6))
            haze.stroke(path, with: .color(color.opacity(opacity * glow * 0.65)),
                        style: StrokeStyle(lineWidth: width * 3.5, lineCap: .round, lineJoin: .round))
        }
        c.stroke(path, with: .color(color.opacity(opacity)),
                 style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        c.stroke(path, with: .color(.white.opacity(opacity * 0.5)),
                 style: StrokeStyle(lineWidth: width * 0.27, lineCap: .round, lineJoin: .round))
    }

    private static func path(_ points: [TronPoint], transform: (TronPoint) -> CGPoint) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { path.move(to: transform(point)) }
            else { path.addLine(to: transform(point)) }
        }
        return path
    }

    private static func cycles(_ c: inout GraphicsContext, size: CGSize, color: Color,
                               time: Double, energy: Double, glow: Double, detail: Double) {
        let unit = min(size.width, size.height)
        let scale = max(0.5, unit / 350)
        let map: (TronPoint) -> CGPoint = { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        for index in 0..<(detail > 0.55 ? 4 : 3) {
            let trail = TronGeometry.cycleTrail(index: index, time: time, trailLength: 0.68)
            neon(&c, path: path(trail, transform: map), color: color,
                 width: (2 + energy * 2.2) * scale, glow: glow, opacity: 0.62 + Double(index) * 0.09)
            let pose = TronGeometry.cyclePose(index: index, time: time)
            let point = map(pose.point)
            var bike = c
            bike.translateBy(x: point.x, y: point.y)
            bike.rotate(by: .radians(pose.angle))
            bike.scaleBy(x: scale, y: scale)
            // Two luminous wheel housings, a narrow chassis and a rider canopy.
            let chassis = Path(roundedRect: CGRect(x: -12, y: -4, width: 24, height: 8), cornerRadius: 3)
            var body = bike; body.blendMode = .normal
            body.fill(chassis, with: .color(Color(hex: 0x06131B)))
            neon(&bike, path: chassis, color: color, width: 1.4, glow: glow)
            for x in [-8.0, 8.0] {
                let wheel = Path(roundedRect: CGRect(x: x - 3, y: -6, width: 6, height: 12), cornerRadius: 3)
                neon(&bike, path: wheel, color: color, width: 1.7, glow: glow)
            }
            bike.fill(Path(ellipseIn: CGRect(x: -3, y: -2, width: 8, height: 4)), with: .color(.white.opacity(0.9)))
        }
    }

    private static func discs(_ c: inout GraphicsContext, size: CGSize, color: Color,
                              time: Double, energy: Double, glow: Double, detail: Double) {
        let unit = min(size.width, size.height)
        let radius = unit * (0.065 + energy * 0.014)
        let aspect = size.width / size.height
        for index in 0..<(detail > 0.55 ? 4 : 3) {
            let position = TronGeometry.discPosition(index: index, time: time, aspect: aspect, radius: 0.10)
            let center = CGPoint(x: position.x * unit, y: position.y * unit)
            // Short afterimages follow the reflected trajectory through each bounce.
            for ghost in stride(from: 6, through: 1, by: -1) {
                let p = TronGeometry.discPosition(index: index, time: time - Double(ghost) * 0.08,
                                                aspect: aspect, radius: 0.10)
                let rect = CGRect(x: p.x * unit - radius, y: p.y * unit - radius, width: radius * 2, height: radius * 2)
                c.stroke(Path(ellipseIn: rect), with: .color(color.opacity(Double(7 - ghost) * 0.025)), lineWidth: 1.2)
            }
            var disc = c
            disc.translateBy(x: center.x, y: center.y)
            disc.rotate(by: .radians(time * (index.isMultiple(of: 2) ? 1.2 : -1.5) + Double(index)))
            let outer = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
            var body = disc; body.blendMode = .normal
            body.fill(outer, with: .color(Color(hex: 0x071018).opacity(0.95)))
            neon(&disc, path: outer, color: color, width: max(1.5, unit * 0.006), glow: glow)
            let inner = radius * 0.58
            neon(&disc, path: Path(ellipseIn: CGRect(x: -inner, y: -inner, width: inner * 2, height: inner * 2)),
                 color: color, width: max(1, unit * 0.003), glow: glow * 0.7, opacity: 0.7)
            var marks = Path()
            for mark in 0..<3 {
                let start = Double(mark) * 120 + 12
                marks.move(to: CGPoint(x: cos(start * .pi / 180) * radius * 0.81,
                                      y: sin(start * .pi / 180) * radius * 0.81))
                marks.addArc(center: .zero, radius: radius * 0.81,
                             startAngle: .degrees(start), endAngle: .degrees(start + 72), clockwise: false)
            }
            neon(&disc, path: marks, color: color, width: max(1.2, unit * 0.005), glow: glow, opacity: 0.85)
        }
    }

    private static func circuits(_ c: inout GraphicsContext, size: CGSize, color: Color,
                                 time: Double, energy: Double, glow: Double) {
        let unit = max(size.width, size.height) * 1.9
        let map: (TronPoint) -> CGPoint = {
            CGPoint(x: size.width / 2 + $0.x * unit, y: size.height / 2 + $0.y * unit)
        }
        var allTraces = Path(), terminals = Path(), pulses = Path()
        for (index, trace) in TronGeometry.circuitTraces(time: time).enumerated() {
            guard trace.progress > 0 else { continue }
            let points = TronGeometry.prefix(of: trace.points, progress: trace.progress)
            let wire = path(points, transform: map)
            c.stroke(wire, with: .color(color.opacity(0.42 * trace.opacity)), lineWidth: 1)
            allTraces.addPath(wire)
            if let end = points.last {
                let p = map(end)
                terminals.addEllipse(in: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
            }
            let distance = TronGeometry.length(of: points)
            let p = map(TronGeometry.pose(on: points, distance: distance * TronGeometry.wrap(time * 0.24 + Double(index) * 0.19, period: 1)).point)
            pulses.addEllipse(in: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3))
        }
        // Batch glow into one pass rather than blurring every circuit segment.
        neon(&c, path: allTraces, color: color, width: 0.9 + energy * 0.8, glow: glow, opacity: 0.65)
        c.stroke(terminals, with: .color(color.opacity(0.65)), lineWidth: 1)
        c.fill(pulses, with: .color(.white.opacity(0.55 + energy * 0.4)))
        let chipSize = min(size.width, size.height) * 0.075
        let chip = Path(roundedRect: CGRect(x: size.width / 2 - chipSize, y: size.height / 2 - chipSize,
                                           width: chipSize * 2, height: chipSize * 2), cornerRadius: 3)
        var body = c; body.blendMode = .normal
        body.fill(chip, with: .color(Color(hex: 0x030910)))
        neon(&c, path: chip, color: color, width: 1.4, glow: glow)
        c.draw(Text("GRID").font(.system(size: max(6, chipSize * 0.4), weight: .medium, design: .monospaced))
            .foregroundStyle(color), at: CGPoint(x: size.width / 2, y: size.height / 2))
    }
}
