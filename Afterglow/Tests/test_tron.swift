import Foundation

@main
struct TronTests {
    static func main() throws {
        // Upgrading the saved v1 object must preserve every original setting.
        let legacy = Data(#"{"style":"orbit","palette":"ember","sensitivity":2.1,"speed":1.4,"glow":0.2,"detail":0.8,"fps":30,"favorites":["bloom","terrain"]}"#.utf8)
        let old = try JSONDecoder().decode(VisualSettings.self, from: legacy)
        precondition(old.style == .orbit && old.palette == .ember)
        precondition(old.sensitivity == 2.1 && old.speed == 1.4 && old.glow == 0.2)
        precondition(old.detail == 0.8 && old.fps == 30 && old.favorites == [.bloom, .terrain])
        precondition(old.tronMode == .lightCycles && old.tronPalette == .lightBlue)
        for mode in TronMode.allCases {
            for palette in TronPalette.allCases {
                var settings = old
                settings.style = .tron; settings.tronMode = mode; settings.tronPalette = palette
                let restored = try JSONDecoder().decode(VisualSettings.self, from: JSONEncoder().encode(settings))
                precondition(restored == settings, "Tron selection must round-trip without losing preferences")
            }
        }
        precondition(VisualizerStyle.allCases.count == 11)
        var halo = old
        halo.style = .halo
        halo.favorites.append(.halo)
        let haloRestored = try JSONDecoder().decode(VisualSettings.self, from: JSONEncoder().encode(halo))
        precondition(haloRestored == halo, "Halo selection and favorites must preserve existing settings")

        var ironMan = halo
        ironMan.style = .ironMan
        ironMan.favorites.append(.ironMan)
        let ironManRestored = try JSONDecoder().decode(VisualSettings.self, from: JSONEncoder().encode(ironMan))
        precondition(ironManRestored == ironMan, "Iron Man must preserve Halo favorites and existing preferences")
        precondition(VisualizerStyle.ironMan.title == "Iron Man")

        // Every disc, including its largest audio-reactive radius, stays on screen
        // through rebounds in portrait, landscape, square, and ultrawide layouts.
        for aspect in [0.35, 0.56, 1, 1.78, 3.2] {
            for index in 0..<4 {
                for step in 0..<2_000 {
                    let t = Double(step) * 0.37
                    let p = TronGeometry.discPosition(index: index, time: t, aspect: aspect, radius: 0.1)
                    precondition(p.x >= 0.1 - 1e-9 && p.x <= max(1, aspect) - 0.1 + 1e-9)
                    precondition(p.y >= 0.1 - 1e-9 && p.y <= max(1, 1 / aspect) - 0.1 + 1e-9)
                    let next = TronGeometry.discPosition(index: index, time: t + 0.001, aspect: aspect, radius: 0.1)
                    precondition((next - p).length < 0.0004, "Bounces must be continuous")
                }
            }
        }
        for index in 0..<4 {
            for step in 0..<300 {
                let t = Double(step) * 0.13
                let trail = TronGeometry.cycleTrail(index: index, time: t)
                precondition(abs(TronGeometry.length(of: trail) - 0.68) < 1e-8, "Trail must retain length across route seams")
                precondition(trail.last == TronGeometry.cyclePose(index: index, time: t).point)
                for (a, b) in zip(trail, trail.dropFirst()) {
                    precondition(abs(a.x - b.x) < 1e-8 || abs(a.y - b.y) < 1e-8, "Cycle trails must retain right-angle corners")
                }
            }
        }
        for t in [0.0, 4.8, 50, 3_600, 86_400, 1_000_000] {
            let traces = TronGeometry.circuitTraces(time: t)
            precondition(!traces.isEmpty && traces.count <= 128, "Circuit growth must use bounded work")
            for trace in traces {
                precondition((0...1).contains(trace.progress))
                precondition(trace.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
                let partial = TronGeometry.prefix(of: trace.points, progress: trace.progress)
                precondition(abs(TronGeometry.length(of: partial) - TronGeometry.length(of: trace.points) * trace.progress) < 1e-8)
            }
        }
        print("PASS: Iron Man and Halo settings/favorites round-trip; legacy settings migration; all 9 Tron selections; 40,000 disc-boundary/continuity samples; 1,200 cycle trails; bounded circuit growth through 1,000,000 seconds.")
    }
}
