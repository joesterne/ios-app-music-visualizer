import Foundation

/// Block-world layout derived from world-column seeds, shared with `Web/minecraft.js`.
/// Nothing is stored between frames, so pause is exact and long sessions stay bounded.
enum MinecraftGeometry {
    enum Feature: Equatable { case plain, tree, torch, creeper }

    struct Column: Equatable {
        let height: Int
        let feature: Feature
    }

    static func random(_ seed: Double) -> Double {
        let value = sin(seed * 127.1 + 311.7) * 43758.5453
        return value - floor(value)
    }

    /// Surface height (1-6 blocks) eases between seeded control points every eight columns.
    static func column(_ index: Int) -> Column {
        let c = Double(index)
        let cell = floor(c / 8)
        let f = (c - cell * 8) / 8
        let s = f * f * (3 - 2 * f)
        let a = random(cell * 3 + 11), b = random(cell * 3 + 14), r = random(c * 5 + 2)
        let feature: Feature = r < 0.1 ? .tree : r < 0.16 ? .torch : r < 0.19 ? .creeper : .plain
        return Column(height: Int((1 + (a + (b - a) * s) * 5).rounded()), feature: feature)
    }

    /// Ore kinds: 0 coal, 1 iron, 2 gold (mids), 3 redstone (bass), 4 diamond (treble); nil is plain stone.
    static func ore(column: Int, depth: Int) -> Int? {
        guard depth >= 4 else { return nil }
        let r = random(Double(column) * 31 + Double(depth) * 17 + 5)
        return r < 0.08 ? min(4, Int(r / 0.08 * 5)) : nil
    }

    /// Columns scrolled past at 1.6 blocks per second. Non-finite or negative time starts at zero.
    static func scroll(at time: Double) -> Double {
        (time.isFinite ? max(0, time) : 0) * 1.6
    }
}
