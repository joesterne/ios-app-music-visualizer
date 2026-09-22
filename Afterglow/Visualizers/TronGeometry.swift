import Foundation

// Pure geometry, independent of SwiftUI and the audio source. All distances are
// normalized so the effects retain their proportions on phones and tablets.
struct TronPoint: Equatable, Sendable {
    var x: Double
    var y: Double

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var length: Double { hypot(x, y) }
}

struct TronPose {
    var point: TronPoint
    var angle: Double
}

struct CircuitTrace {
    var points: [TronPoint]
    var progress: Double
    var opacity: Double
}

enum TronGeometry {
    static func wrap(_ value: Double, period: Double) -> Double {
        guard period > 0 else { return 0 }
        return (value.truncatingRemainder(dividingBy: period) + period)
            .truncatingRemainder(dividingBy: period)
    }

    static func reflected(_ value: Double, lower: Double, upper: Double) -> Double {
        let span = upper - lower
        guard span > 0 else { return lower }
        let phase = wrap(value - lower, period: span * 2)
        return lower + (phase <= span ? phase : span * 2 - phase)
    }

    static func discPosition(index: Int, time: Double, aspect: Double, radius: Double) -> TronPoint {
        // Work in units of the shorter dimension to keep every disc circular.
        let width = max(1, aspect)
        let height = max(1, 1 / max(0.01, aspect))
        let speeds: [(Double, Double)] = [(0.17, 0.13), (-0.14, 0.19), (0.21, -0.12), (-0.12, -0.16)]
        let speed = speeds[index % speeds.count]
        return TronPoint(
            x: reflected(width * (0.2 + Double(index) * 0.19) + time * speed.0,
                         lower: radius, upper: width - radius),
            y: reflected(height * (0.22 + Double(index) * 0.17) + time * speed.1,
                         lower: radius, upper: height - radius)
        )
    }

    static func cycleRoute(index: Int) -> [TronPoint] {
        let routes: [[(Double, Double)]] = [
            [(0.12, 0.19), (0.74, 0.19), (0.74, 0.43), (0.88, 0.43), (0.88, 0.79), (0.39, 0.79), (0.39, 0.57), (0.12, 0.57)],
            [(0.23, 0.87), (0.23, 0.34), (0.53, 0.34), (0.53, 0.12), (0.85, 0.12), (0.85, 0.64), (0.66, 0.64), (0.66, 0.87)],
            [(0.09, 0.70), (0.09, 0.09), (0.36, 0.09), (0.36, 0.47), (0.62, 0.47), (0.62, 0.92), (0.45, 0.92), (0.45, 0.70)],
            [(0.94, 0.92), (0.77, 0.92), (0.77, 0.54), (0.47, 0.54), (0.47, 0.26), (0.94, 0.26)]
        ]
        let route = routes[index % routes.count].map { TronPoint(x: $0.0, y: $0.1) }
        return route + [route[0]]
    }

    static func length(of points: [TronPoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + ($1.1 - $1.0).length }
    }

    static func pose(on points: [TronPoint], distance: Double) -> TronPose {
        guard let first = points.first else { return TronPose(point: .init(x: 0, y: 0), angle: 0) }
        var remaining = max(0, distance)
        for (start, end) in zip(points, points.dropFirst()) {
            let delta = end - start
            let segmentLength = delta.length
            guard segmentLength > 0 else { continue }
            if remaining <= segmentLength {
                return TronPose(point: start + delta * (remaining / segmentLength), angle: atan2(delta.y, delta.x))
            }
            remaining -= segmentLength
        }
        return TronPose(point: points.last ?? first, angle: 0)
    }

    static func prefix(of points: [TronPoint], progress: Double) -> [TronPoint] {
        guard let first = points.first else { return [] }
        let target = length(of: points) * min(1, max(0, progress))
        var result = [first]
        var traversed = 0.0
        for (start, end) in zip(points, points.dropFirst()) {
            let segmentLength = (end - start).length
            if traversed + segmentLength > target {
                result.append(pose(on: [start, end], distance: target - traversed).point)
                return result
            }
            result.append(end)
            traversed += segmentLength
        }
        return result
    }

    static func cyclePose(index: Int, time: Double) -> TronPose {
        let route = cycleRoute(index: index)
        let distance = wrap(time * (0.11 + Double(index) * 0.012) + Double(index) * 0.61,
                            period: length(of: route))
        return pose(on: route, distance: distance)
    }

    static func cycleTrail(index: Int, time: Double, trailLength: Double = 0.68) -> [TronPoint] {
        let route = cycleRoute(index: index)
        let perimeter = length(of: route)
        let head = wrap(time * (0.11 + Double(index) * 0.012) + Double(index) * 0.61, period: perimeter)
        let start = head - min(trailLength, perimeter)
        var result = [pose(on: route, distance: wrap(start, period: perimeter)).point]
        // Retain exact vertices, including when a trail crosses the route's seam.
        for lap in -1...0 {
            var distance = Double(lap) * perimeter
            for (a, b) in zip(route, route.dropFirst()) {
                distance += (b - a).length
                if distance > start && distance < head { result.append(b) }
            }
        }
        result.append(pose(on: route, distance: head).point)
        return result
    }

    static func circuitTraces(time: Double) -> [CircuitTrace] {
        // New rings grow forever while the camera smoothly pulls back. Only eight
        // rings are rendered: neither memory nor per-frame work grows with time.
        let growth = max(0, time) / 4.8 + 2.5
        let newest = Int(floor(growth))
        var traces: [CircuitTrace] = []
        for ring in max(0, newest - 7)...newest {
            let outer = 0.62 * pow(1.52, Double(ring) - growth)
            let inner = outer / 1.52
            let progress = min(1, (growth - Double(ring)) * 1.7)
            for arm in 0..<8 {
                let angle = Double(arm) * .pi / 4
                let u = TronPoint(x: cos(angle), y: sin(angle))
                let v = TronPoint(x: -sin(angle), y: cos(angle))
                let start = u * inner
                let end = u * outer
                let elbow = u * (inner + (outer - inner) * 0.45)
                // Alternating stepped branches give the rings a PCB topology.
                let offset = v * ((outer - inner) * (arm.isMultiple(of: 2) ? 0.34 : -0.34))
                let points = [start, elbow, elbow + offset, end + offset, end]
                let opacity = min(1, max(0, (Double(ring) - growth + 8) / 2))
                traces.append(CircuitTrace(points: points, progress: progress, opacity: opacity))
                let spurStart = elbow + offset
                let spurEnd = spurStart + v * ((outer - inner) * 0.55)
                traces.append(CircuitTrace(points: [spurStart, spurEnd, spurEnd + u * ((outer - inner) * 0.23)],
                                           progress: max(0, (progress - 0.45) / 0.55), opacity: opacity * 0.65))
            }
        }
        return traces
    }
}
