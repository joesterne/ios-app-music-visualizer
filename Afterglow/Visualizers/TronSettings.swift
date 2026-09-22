import SwiftUI

enum TronMode: String, CaseIterable, Identifiable, Codable {
    case lightCycles
    case identityDiscs
    case circuitExpansion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lightCycles: "Light cycles"
        case .identityDiscs: "Identity discs"
        case .circuitExpansion: "Circuit expansion"
        }
    }

    var symbol: String {
        switch self {
        case .lightCycles: "point.topleft.down.to.point.bottomright.curvepath"
        case .identityDiscs: "circle.circle"
        case .circuitExpansion: "cpu"
        }
    }

    var subtitle: String {
        switch self {
        case .lightCycles: "Neon riders. Endless trails."
        case .identityDiscs: "Spin. Rebound. Repeat."
        case .circuitExpansion: "A circuit that never stops growing."
        }
    }
}

enum TronPalette: String, CaseIterable, Identifiable, Codable {
    case lightBlue
    case orange
    case red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lightBlue: "Light blue"
        case .orange: "Orange"
        case .red: "Red"
        }
    }

    var color: Color {
        switch self {
        case .lightBlue: Color(red: 0.40, green: 0.87, blue: 1)
        case .orange: Color(red: 1, green: 0.55, blue: 0.19)
        case .red: Color(red: 1, green: 0.20, blue: 0.28)
        }
    }
}
