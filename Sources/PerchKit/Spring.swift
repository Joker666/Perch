import CoreGraphics
import Foundation

/// A damped spring from 0 to 1, with SwiftUI's terms: `response` is the
/// period of one swing in seconds, and `dampingFraction` 1 has no overshoot.
public struct Spring: Sendable {
    public var response: Double
    public var dampingFraction: Double

    public init(response: Double, dampingFraction: Double) {
        self.response = response
        self.dampingFraction = dampingFraction
    }

    /// Progress `seconds` after the start, starting at rest. Can pass 1 on the overshoot.
    public func value(at seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        let omega = 2 * .pi / response
        let zeta = dampingFraction
        guard zeta < 1 else { return 1 - (1 + omega * seconds) * exp(-omega * seconds) }
        let damped = omega * (1 - zeta * zeta).squareRoot()
        return 1 - exp(-zeta * omega * seconds)
            * (cos(damped * seconds) + zeta * omega / damped * sin(damped * seconds))
    }

    /// The time after which the spring stays within `tolerance` of 1.
    public func settleTime(tolerance: Double = 0.001) -> Double {
        let step = 1.0 / 240
        var last = 0.0
        var t = 0.0
        while t < 5 {
            t += step
            if abs(value(at: t) - 1) > tolerance { last = t }
        }
        return last + step
    }

    /// `frame` scaled about its center, by `start` at progress 0 and by 1 at progress 1.
    public static func scaled(_ frame: CGRect, from start: Double, progress: Double) -> CGRect {
        let scale = start + (1 - start) * progress
        let width = frame.width * scale, height = frame.height * scale
        return CGRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height)
    }
}
