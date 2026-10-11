import Foundation

@main
struct ForestTests {
    static func main() {
        var kinds = Set<Int>(), sides = Set<Double>()
        var quiet = 0, visible = 0
        for i in 0..<10000 {
            let time = Double(i) * 0.1
            guard let e = ForestWalkGeometry.encounter(at: time) else { quiet += 1; continue }
            visible += 1; kinds.insert(e.kind); sides.insert(e.side)
            precondition(e == ForestWalkGeometry.encounter(at: time), "Pause must retain the encounter and pose")
            precondition((0..<4).contains(e.kind) && e.progress >= 0 && e.progress < 1)
            precondition((0...1).contains(e.opacity) && (0.48...0.66).contains(e.depth))
        }
        precondition(kinds.count == 4 && sides.count == 2)
        precondition(quiet > 1000 && visible > 4000)
        for time in [0.0, 10, 1_000_000, .nan, .infinity, -5] {
            if let e = ForestWalkGeometry.encounter(at: time) { precondition(e.opacity.isFinite) }
        }
        print("PASS: Forest encounter diversity, quiet gaps, deterministic pause, bounded geometry and long-running time.")
    }
}
