#if os(macOS)
import AppKit
#else
import AVFoundation
#endif

/// The short clicks when you add or complete a todo in the panel. They are made
/// in code, so Perch ships no audio file.
@MainActor
enum FeedbackSound {
    enum Kind {
        /// One quiet tick when a new todo is saved.
        case add
        /// A key switch: a firm press, then a lighter release.
        case complete
    }

    /// How many times the panel asked for each sound, played or not. The self-test reads it.
    private(set) static var requests: [Kind: Int] = [:]

    /// Plays unless Settings or macOS turned sounds off. Test runs stay silent.
    static func play(_ kind: Kind) {
        requests[kind, default: 0] += 1
        guard Prefs.shared.playSounds, systemAllowsInterfaceSounds, !Store.isOverridden else { return }
        let sound = sound(kind)
        sound?.stop()
        #if os(macOS)
        sound?.play()
        #else
        sound?.currentTime = 0
        sound?.play()
        #endif
    }

    /// System Settings > Sound > "Play user interface sound effects". On when never
    /// changed. iOS has no such setting, and the ring switch mutes the clicks.
    static var systemAllowsInterfaceSounds: Bool {
        #if os(macOS)
        UserDefaults.standard.object(forKey: "com.apple.sound.uiaudio.enabled") as? Int != 0
        #else
        true
        #endif
    }

    #if os(macOS)
    typealias Player = NSSound
    private static func player(_ data: Data) -> Player? { NSSound(data: data) }
    #else
    typealias Player = AVAudioPlayer
    private static func player(_ data: Data) -> Player? { try? AVAudioPlayer(data: data) }
    #endif

    static func sound(_ kind: Kind) -> Player? {
        switch kind {
        case .add: add
        case .complete: complete
        }
    }

    private static let add = player(wav([(0, 0.7, 3200, 1100, 0.004)], seconds: 0.06))
    private static let complete = player(wav([(0, 1, 2600, 900, 0.004), (0.045, 0.55, 3400, 1200, 0.003)], seconds: 0.1))

    typealias Click = (start: Double, gain: Double, tick: Double, body: Double, decay: Double)

    /// Clicks made of a high tick, a lower body, and a burst of noise, all fading
    /// in a few milliseconds. 16-bit mono WAV.
    static func wav(_ clicks: [Click], seconds: Double) -> Data {
        let rate = 44_100.0
        let length = Int(rate * seconds)
        var seed: UInt32 = 0x5045_5243 // a fixed seed, so every launch makes the same click
        var previousNoise = 0.0
        var samples = [Int16](repeating: 0, count: length)
        for i in 0..<length {
            let time = Double(i) / rate
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = Double(seed >> 8) / Double(1 << 24) * 2 - 1
            let sharpNoise = noise - previousNoise // a rough high-pass
            previousNoise = noise
            var value = 0.0
            for click in clicks where time >= click.start {
                let t = time - click.start
                value += click.gain * min(t / 0.0004, 1) * (
                    0.55 * sin(2 * .pi * click.tick * t) * exp(-t / click.decay)
                    + 0.35 * sin(2 * .pi * click.body * t) * exp(-t / (click.decay * 2.5))
                    + 0.25 * sharpNoise * exp(-t / 0.0015))
            }
            samples[i] = Int16(max(-1, min(1, value * 0.6)) * Double(Int16.max))
        }
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(length * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        append(36 + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))           // format chunk size
        append(UInt16(1))            // PCM
        append(UInt16(1))            // mono
        append(UInt32(rate))
        append(UInt32(rate) * 2)     // bytes per second
        append(UInt16(2))            // bytes per frame
        append(UInt16(16))           // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(bytes)
        for sample in samples { append(sample) }
        return data
    }
}
