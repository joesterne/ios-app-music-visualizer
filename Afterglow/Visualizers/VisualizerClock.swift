import SwiftUI

/// Owned by the studio, so moving the renderer between layouts never restarts it.
/// A single configuration update keeps speed and pause state on one time boundary.
final class VisualizerClock: ObservableObject {
    struct Configuration: Equatable {
        let speed: Double
        let paused: Bool
    }

    private var reference = Date()
    private var accumulated: TimeInterval = 0
    private var paused = false
    private var speed: Double = 1

    func elapsed(at date: Date) -> TimeInterval {
        accumulated + (paused ? 0 : max(0, date.timeIntervalSince(reference)) * speed)
    }

    /// Rebase exactly once when either policy changes. This avoids a transition
    /// observing a new speed with an old pause state (or vice versa).
    func apply(_ configuration: Configuration, at date: Date = Date()) {
        let nextSpeed = configuration.speed.isFinite
            ? min(2, max(0.1, configuration.speed))
            : 0.65
        guard nextSpeed != speed || configuration.paused != paused else { return }
        accumulated = elapsed(at: date)
        reference = date
        speed = nextSpeed
        paused = configuration.paused
    }

    // Retained for deterministic native clock regressions and callers outside
    // StudioView. The studio itself always uses one atomic configuration update.
    func setPaused(_ value: Bool, at date: Date = Date()) {
        apply(.init(speed: speed, paused: value), at: date)
    }

    func setSpeed(_ value: Double, at date: Date = Date()) {
        apply(.init(speed: value, paused: paused), at: date)
    }
}
