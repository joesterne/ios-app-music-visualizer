import Foundation

/// Clock-derived encounters need no timers or growing particle collections.
/// The same seeds are used by the browser preview. A ten-second window contains
/// at most one animal, with variable arrival, duration, species and trail side.
enum ForestWalkGeometry {
    struct Encounter: Equatable {
        let kind: Int
        let side: Double
        let depth: Double
        let progress: Double
        let opacity: Double
    }

    static func random(_ seed: Double) -> Double {
        let value = sin(seed * 127.1 + 311.7) * 43758.5453
        return value - floor(value)
    }

    static func encounter(at time: Double) -> Encounter? {
        let t = time.isFinite ? max(0, time) : 0
        let slot = floor(t / 10)
        let start = random(slot * 7 + 1) * 2
        let duration = 5 + random(slot * 7 + 2) * 2
        let progress = (t - slot * 10 - start) / duration
        guard progress >= 0, progress < 1 else { return nil }
        return Encounter(kind: Int(random(slot * 7 + 3) * 4),
                         side: random(slot * 7 + 4) < 0.5 ? -1 : 1,
                         depth: 0.48 + random(slot * 7 + 5) * 0.18,
                         progress: progress, opacity: min(1, progress * 6, (1 - progress) * 6))
    }
}
