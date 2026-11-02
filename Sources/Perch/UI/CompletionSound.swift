import AppKit

/// The short chime when you complete a todo in the panel. It is made in code,
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

    /// Two soft rising notes (E6, then B6), each a sine with a quiet octave
    /// that fades out fast. 16-bit mono WAV.
    static func wav() -> Data {
        let rate = 44_100.0
        let length = Int(rate * 0.32)
        let notes: [(start: Double, frequency: Double)] = [(0, 1318.5), (0.07, 1975.5)]
        var samples = [Int16](repeating: 0, count: length)
        for i in 0..<length {
            let time = Double(i) / rate
            var value = 0.0
            for note in notes where time >= note.start {
                let t = time - note.start
                let envelope = min(t / 0.004, 1) * exp(-t / 0.06)
                value += envelope * (sin(2 * .pi * note.frequency * t) + 0.12 * sin(4 * .pi * note.frequency * t))
            }
            samples[i] = Int16(max(-1, min(1, value * 0.22)) * Double(Int16.max))
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
