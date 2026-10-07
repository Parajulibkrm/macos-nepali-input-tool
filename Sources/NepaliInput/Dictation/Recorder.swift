import AVFoundation

/// Records the default mic and converts it to 16 kHz mono Int16 on the fly.
final class Recorder {
    private let engine = AVAudioEngine()
    private let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
                                       channels: 1, interleaved: true)!
    private var converter: AVAudioConverter?
    private var samples: [Int16] = []
    private let lock = NSLock()
    /// Mic level 0...1, delivered on the main queue roughly every 40 ms.
    var onLevel: ((Float) -> Void)?
    /// Each converted 16 kHz chunk as it arrives, on the audio thread.
    var onSamples: (([Int16]) -> Void)?

    func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw NSError(domain: "Dictate", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No microphone available (check Microphone permission)"]) }
        converter = AVAudioConverter(from: format, to: target)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.append(buf)
        }
        engine.prepare()
        try engine.start()
    }

    func stop() -> [Int16] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); defer { lock.unlock() }
        return samples
    }

    private func append(_ buf: AVAudioPCMBuffer) {
        guard let converter else { return }
        let capacity = AVAudioFrameCount(Double(buf.frameLength) * target.sampleRate / buf.format.sampleRate) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buf
        }
        guard error == nil, out.frameLength > 0, let ch = out.int16ChannelData else { return }
        let chunk = UnsafeBufferPointer(start: ch[0], count: Int(out.frameLength))
        lock.lock(); samples.append(contentsOf: chunk); lock.unlock()
        onSamples?(Array(chunk))

        if let onLevel {
            var sum = 0.0
            for v in chunk { let f = Double(v) / 32768; sum += f * f }
            let db = 20 * log10(sqrt(sum / Double(chunk.count)) + 1e-9)
            let level = Float(min(1, max(0, (db + 55) / 40)))   // -55 dB → 0, -15 dB → 1
            DispatchQueue.main.async { onLevel(level) }
        }
    }
}
