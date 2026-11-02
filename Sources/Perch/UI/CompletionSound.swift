import AppKit

/// The short click when you complete a todo in the panel. It is made in code,
/// so Perch ships no audio file.
@MainActor
enum CompletionSound {
    /// How many times the panel asked for the sound, played or not. The self-test reads it.
    private(set) static var requests = 0

    /// Plays unless Settings or macOS turned the sound off. Test runs stay silent.
    static func play() {
        requests += 1
        guard Prefs.shared.completionSound, systemAllowsInterfaceSounds, !Store.isOverridden else { return }
        sound?.stop()
        sound?.play()
    }

    /// System Settings > Sound > "Play user interface sound effects". On when never changed.
    static var systemAllowsInterfaceSounds: Bool {
        UserDefaults.standard.object(forKey: "com.apple.sound.uiaudio.enabled") as? Int != 0
    }

    static let sound = NSSound(data: wav())

    /// A key switch: a firm press, then a lighter release 45 ms later. Each click
    /// is a high tick, a lower body, and a burst of noise, all fading in a few
    /// milliseconds. 16-bit mono WAV.
    static func wav() -> Data {
        let rate = 44_100.0
        let length = Int(rate * 0.1)
        let clicks: [(start: Double, gain: Double, tick: Double, body: Double, decay: Double)] = [
            (0, 1, 2600, 900, 0.004),
            (0.045, 0.55, 3400, 1200, 0.003),
        ]
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
