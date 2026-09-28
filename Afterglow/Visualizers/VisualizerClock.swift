import SwiftUI

/// Owned by the studio, so moving the renderer between layouts never restarts it.
final class VisualizerClock: ObservableObject {
    private var reference = Date()
    private var accumulated: TimeInterval = 0
    private var paused = false
    private var speed: Double = 1

    func elapsed(at date: Date) -> TimeInterval {
        accumulated + (paused ? 0 : max(0, date.timeIntervalSince(reference)) * speed)
    }

    func setPaused(_ value: Bool, at date: Date = Date()) {
        guard value != paused else { return }
        accumulated = elapsed(at: date)
        reference = date
        paused = value
    }
    func setSpeed(_ value: Double, at date: Date = Date()) {
        let next = value.isFinite ? min(2, max(0.1, value)) : 0.65
        guard speed != next else { return }
        accumulated = elapsed(at: date)
        reference = date
        speed = next
    }
}
