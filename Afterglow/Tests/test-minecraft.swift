import Foundation

@main
struct MinecraftTests {
    static func main() {
        var heights = Set<Int>(), ores = Set<Int>()
        var trees = 0, torches = 0, creepers = 0
        for index in -2000..<20000 {
            let column = MinecraftGeometry.column(index)
            precondition((1...6).contains(column.height), "Surface stays within six blocks")
            precondition(abs(MinecraftGeometry.column(index + 1).height - column.height) <= 2, "Neighboring columns are walkable")
            precondition(column == MinecraftGeometry.column(index), "Pause must retain the same world")
            heights.insert(column.height)
            switch column.feature {
            case .tree: trees += 1
            case .torch: torches += 1
            case .creeper: creepers += 1
            case .plain: break
            }
            precondition(MinecraftGeometry.ore(column: index, depth: 2) == nil, "Dirt never contains ore")
            if let ore = MinecraftGeometry.ore(column: index, depth: 6) { ores.insert(ore) }
        }
        precondition(heights.count == 6 && ores == Set(0...4))
        precondition(trees > 1500 && torches > 800 && creepers > 300)
        for time in [0.0, 10, 1_000_000, .nan, .infinity, -5] {
            let scroll = MinecraftGeometry.scroll(at: time)
            precondition(scroll.isFinite && scroll >= 0)
        }
        print("PASS: Minecraft terrain bounds and walkability, all ores, recurring features, deterministic pause and long-running time.")
    }
}
