import Foundation

/// Bounded visual controls. A soft knee preserves changes at high sensitivity
/// instead of pinning the geometry at its maximum on loud tracks.
struct AudioResponse {
    let energy: Double
    let bass: Double
    let mid: Double
    let treble: Double
    let hit: Double

    static func compress(_ value: Double, gain: Double) -> Double {
        guard value.isFinite, gain.isFinite else { return 0 }
        return 1 - exp(-max(0, value) * max(0, gain))
    }

    static func band(_ value: Double, gain: Double) -> Double {
        compress(pow(max(0, value), 2), gain: gain * 2.2)
    }

    init(rms: Double, bass: Double, mid: Double, treble: Double, beat: Double, sensitivity: Double) {
        energy = Self.compress(rms, gain: sensitivity * 4)
        self.bass = Self.band(bass, gain: sensitivity)
        self.mid = Self.band(mid, gain: sensitivity)
        self.treble = Self.band(treble, gain: sensitivity)
        hit = Self.compress(beat, gain: sensitivity * 1.8)
    }
}
