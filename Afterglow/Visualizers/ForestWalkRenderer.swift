import SwiftUI

/// An illustrated woodland scene kept separate from the signal renderers.
/// All motion comes from VisualizerClock, including animal fades and footfalls.
enum ForestWalkRenderer {
    static func draw(context: GraphicsContext, size: CGSize, palette: VisualPalette,
                     frame: AudioFrame, time: Double, sensitivity: Double, glow: Double, detail: Double) {
        let w = size.width, h = size.height, u = min(w, h)
        guard w > 1, h > 1 else { return }
        let t = time.isFinite ? max(0, time) : 0
        let energy = min(1, max(0, Double(frame.rms) * sensitivity * 3))
        let quality = min(1, max(0, detail))
        let random = ForestWalkGeometry.random
        var c = context
        c.blendMode = .normal
        let bounds = Path(CGRect(origin: .zero, size: size))
        c.fill(bounds, with: .linearGradient(Gradient(stops: [
            .init(color: Color(hex: 0x122F35), location: 0),
            .init(color: Color(hex: 0x759484), location: 0.4),
            .init(color: Color(hex: 0x102E26), location: 1)
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        c.fill(bounds, with: .radialGradient(Gradient(colors: [Color(hex: 0xF5E6A6).opacity(0.48), .clear]),
            center: CGPoint(x: w * 0.52, y: h * 0.29), startRadius: 0, endRadius: u * 0.5))
        for i in 0..<28 {
            let seed = Double(i)
            let x = random(seed + 80) * w
            let base = h * (0.39 + random(seed + 120) * 0.13)
            let height = h * (0.15 + random(seed + 160) * 0.25)
            line(&c, [(x, base), (x, base-height)], 0x264E49, u * 0.006, 0.35)
            polygon(&c, [(x-u*0.055,base-h*0.04),(x,base-height),(x+u*0.055,base-h*0.04)], 0x315D50, 0.4)
        }
        polygon(&c, [(0,h*0.47),(w*0.5,h*0.37),(w,h*0.47),(w,h),(0,h)], 0x183D2E)
        polygon(&c, [(w*0.485,h*0.38),(w*0.515,h*0.38),(w*0.57,h*0.56),(w*0.69,h*0.78),
                     (w*0.88,h),(w*0.12,h),(w*0.36,h*0.72),(w*0.46,h*0.53)], 0x938967)
        polygon(&c, [(w*0.49,h*0.39),(w*0.51,h*0.39),(w*0.53,h*0.57),(w*0.61,h*0.78),
                     (w*0.73,h),(w*0.32,h),(w*0.43,h*0.71)], 0xB0A07A, 0.55)
        let rows = Int(10 + quality * 8)
        let trees = (0..<rows).map { row in
            (row: row, z: (Double(row) / Double(rows) + t * 0.035).truncatingRemainder(dividingBy: 1))
        }.sorted { $0.z < $1.z }
        for tree in trees {
            let row = tree.row, depth = tree.z * tree.z
            for side in [-1.0, 1.0] {
                let seed = Double(row) * 13 + (side + 1) * 17
                let x = w * (0.5 + side * (0.07 + depth * (0.52 + random(seed) * 0.3)))
                let y = h * (0.39 + depth * 0.69), height = h * (0.16 + depth * 0.76)
                let width = u * (0.014 + depth * 0.043)
                let sway = sin(t * 0.6 + seed) * u * 0.004 * (1 + energy * 0.4)
                line(&c, [(x,y),(x+sway,y-height)], depth > 0.45 ? 0x172F29 : 0x36594A, width)
                line(&c, [(x-width*0.22,y),(x+sway-width*0.22,y-height)], 0x99A775, max(1,width*0.12), 0.22)
                for tier in 0..<3 {
                    let tip = y-height+height*Double(tier)*0.19, spread = height*(0.2+Double(tier)*0.025)
                    polygon(&c, [(x+sway,tip),(x-spread,tip+height*0.48),(x+spread,tip+height*0.48)], depth > 0.45 ? 0x174735 : 0x3C6550, 0.96)
                    polygon(&c, [(x+sway,tip),(x-spread,tip+height*0.48),(x,tip+height*0.38)], 0x769363, 0.16)
                }
            }
        }
        for i in 0..<4 {
            let n = Double(i)
            polygon(&c, [(w*(0.45+n*0.05),0),(w*(0.48+n*0.055),0),
                         (w*(0.19+n*0.24),h*0.86),(w*(0.08+n*0.24),h*0.86)], 0xFFE8A3, (0.024+energy*0.025)*glow)
        }
        for i in 0..<Int(12+quality*24) {
            let z = (random(Double(i)+260)+t*0.045).truncatingRemainder(dividingBy: 1), d = z*z
            let side = i % 2 == 1 ? -1.0 : 1.0
            let x = w*(0.5+side*(0.08+d*0.65)), y = h*(0.43+d*0.62), s = u*(0.002+d*0.012)
            ellipse(&c,x,y,s*1.6,s*0.55,0x91A579,0.45)
            line(&c,[(x-s*2,y-s),(x,y),(x+s,y-s*2)],0x659265,max(1,s*0.3),0.7)
        }
        if let encounter = ForestWalkGeometry.encounter(at: t) {
            animal(&c, encounter, w, h, u, t)
        }
        walker(&c,w,h,u,t)
        var lights = c
        lights.addFilter(.shadow(color: palette.accent.opacity(glow), radius: glow*u*0.018))
        for i in 0..<Int(8+quality*24) {
            let n = Double(i)
            let x = w*(0.08+random(n+400)*0.84)+sin(t*0.45+n)*u*0.018
            let y = h*(0.3+random(n+460)*0.53)+cos(t*0.6+n)*u*0.014
            let r = u*(0.0015+energy*0.0012)
            let alpha = (0.3+0.7*pow(sin(t+n),2))*(0.4+glow*0.6)
            lights.fill(Path(ellipseIn: CGRect(x:x-r,y:y-r,width:r*2,height:r*2)), with:.color(palette.accent.opacity(alpha)))
        }
    }

    private static func animal(_ context: inout GraphicsContext, _ e: ForestWalkGeometry.Encounter,
                               _ w: Double, _ h: Double, _ u: Double, _ t: Double) {
        var c = context
        let kind = e.kind, s = u * (kind == 0 ? 0.045 : kind == 3 ? 0.026 : 0.03)
        let x = w*(0.5+e.side*(0.18+e.depth*0.1)-e.side*sin(e.progress * .pi)*0.045)
        let hop = kind == 2 ? abs(sin(e.progress*19))*s*0.2 : 0
        c.translateBy(x:x,y:h*(e.depth+0.12)-hop)
        c.scaleBy(x:-e.side*s,y:s)
        c.opacity = e.opacity
        if kind == 3 {
            let flap = sin(t*6)*0.7
            line(&c,[(-1,-0.8-flap),(0,0),(1,-0.8-flap)],0xE4DCB5,0.14)
            ellipse(&c,0,0,0.18,0.3,0xCBB98F)
            return
        }
        let coat: UInt32 = kind == 0 ? 0xBF9B6A : kind == 1 ? 0xD48343 : 0xB1B2A0
        ellipse(&c,0,-0.55,kind == 0 ? 0.85 : 0.72,kind == 0 ? 0.46 : 0.38,coat)
        if kind == 1 {
            polygon(&c,[(-0.4,-0.45),(-1.65,-0.95),(-1.35,-0.3),(-0.5,-0.2)],coat)
            polygon(&c,[(-1.65,-0.95),(-1.35,-0.3),(-1.12,-0.36)],0xEFE3BD)
        }
        if kind == 2 {
            ellipse(&c,-0.66,-0.46,0.23,0.23,0xE2DCC2)
            ellipse(&c,0.52,-1.2,0.12,0.55,coat)
            ellipse(&c,0.8,-1.15,0.13,0.5,coat)
        }
        if kind == 0 {
            line(&c,[(0.5,-0.55),(0.75,-1.5)],coat,0.34)
            line(&c,[(0.65,-1.77),(0.4,-2.3),(0.2,-2.4)],0xD6BC8A,0.09)
            line(&c,[(0.4,-2.3),(0.62,-2.45)],0xD6BC8A,0.07)
        }
        ellipse(&c,kind == 0 ? 0.85 : 0.65,kind == 0 ? -1.55 : -0.85,0.38,0.26,coat)
        if kind != 2 {
            polygon(&c,[(0.48,kind == 0 ? -1.7 : -1),(0.5,kind == 0 ? -2 : -1.4),(0.8,kind == 0 ? -1.7 : -1)],coat)
        }
        for leg in 0..<4 {
            let lx = -0.48+Double(leg)*0.3, swing = sin(t*3+Double(leg))*0.09
            line(&c,[(lx,-0.35),(lx+swing,0.26)],coat,kind == 0 ? 0.12 : 0.15)
        }
        ellipse(&c,kind == 0 ? 1 : 0.8,kind == 0 ? -1.6 : -0.9,0.045,0.045,0x172B28)
    }

    private static func walker(_ c: inout GraphicsContext, _ w: Double, _ h: Double, _ u: Double, _ t: Double) {
        let stride = sin(t*4), s = u*0.075
        let x = w*0.5+sin(t*2)*u*0.003, y = h*0.76+cos(t*8)*u*0.002
        ellipse(&c,x,y+s*0.42,s*0.7,s*0.16,0x122C26,0.28)
        line(&c,[(x-s*0.2,y-s*0.3),(x-s*0.23-stride*s*0.18,y+s*0.3)],0x243D39,s*0.19)
        line(&c,[(x+s*0.2,y-s*0.3),(x+s*0.23+stride*s*0.18,y+s*0.3)],0x243D39,s*0.19)
        line(&c,[(x-s*0.35,y-s*1.23),(x-s*0.56,y-s*0.48+stride*s*0.14)],0xD4AB64,s*0.16)
        line(&c,[(x+s*0.35,y-s*1.23),(x+s*0.56,y-s*0.48-stride*s*0.14)],0xD4AB64,s*0.16)
        polygon(&c,[(x-s*0.31,y-s*1.45),(x+s*0.31,y-s*1.45),(x+s*0.4,y-s*0.27),(x-s*0.4,y-s*0.27)],0xD7AD62)
        ellipse(&c,x,y-s*1.76,s*0.24,s*0.29,0xD4B38A)
        ellipse(&c,x,y-s*1.93,s*0.32,s*0.14,0x647356)
        polygon(&c,[(x-s*0.26,y-s*1.35),(x+s*0.26,y-s*1.35),(x+s*0.28,y-s*0.57),(x-s*0.28,y-s*0.57)],0x42675D)
        line(&c,[(x-s*0.18,y-s*1.28),(x+s*0.18,y-s*1.28)],0xC8C092,s*0.055)
    }

    private static func polygon(_ c: inout GraphicsContext, _ points: [(Double, Double)], _ hex: UInt32, _ alpha: Double = 1) {
        var p = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { p.move(to: CGPoint(x:point.0,y:point.1)) }
            else { p.addLine(to: CGPoint(x:point.0,y:point.1)) }
        }
        p.closeSubpath(); c.fill(p,with:.color(Color(hex:hex).opacity(alpha)))
    }
    private static func line(_ c: inout GraphicsContext, _ points: [(Double, Double)], _ hex: UInt32, _ width: Double, _ alpha: Double = 1) {
        var p = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { p.move(to: CGPoint(x:point.0,y:point.1)) }
            else { p.addLine(to: CGPoint(x:point.0,y:point.1)) }
        }
        c.stroke(p,with:.color(Color(hex:hex).opacity(alpha)),style:StrokeStyle(lineWidth:width,lineCap:.round,lineJoin:.round))
    }
    private static func ellipse(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ hex: UInt32, _ alpha: Double = 1) {
        c.fill(Path(ellipseIn:CGRect(x:x-rx,y:y-ry,width:rx*2,height:ry*2)),with:.color(Color(hex:hex).opacity(alpha)))
    }
}
