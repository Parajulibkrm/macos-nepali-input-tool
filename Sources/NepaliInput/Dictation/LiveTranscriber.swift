import Foundation

/// Sends audio to Google in pieces while you're still talking, cutting at natural pauses
/// (or at the quietest spot once a piece reaches 10 s). On release only the last few
/// seconds are left to transcribe, so the wait stays short however long you talk.
final class LiveTranscriber: Transcriber {
    var onText: ((String) -> Void)?

    private let lang: String
    private let rate = GoogleSpeech.sampleRate
    private let frame = GoogleSpeech.sampleRate / 50          // 20 ms
    private let queue = DispatchQueue(label: "dictate.chunks")  // all state below is touched only here
    private var pending: [Int16] = []
    private var frameRMS: [Double] = []                         // per 20 ms frame of `pending`
    private var allRMS: [Double] = []                           // every frame so far, for level stats
    private var tasks: [Task<String, Error>] = []

    init(lang: String) {
        self.lang = lang
    }

    func append(_ samples: [Int16]) {
        queue.async { self.ingest(samples) }
    }

    func finish() async throws -> String {
        let all: [Task<String, Error>] = await withCheckedContinuation { cont in
            queue.async {
                // Always send the tail: for short utterances the noise floor isn't reliable yet.
                if self.pending.count > self.rate * 3 / 10 { self.dispatch(self.pending) }
                self.pending = []
                cont.resume(returning: self.tasks)
            }
        }
        var texts: [String] = []
        var firstError: Error?
        for t in all {
            do { texts.append(try await t.value) } catch { firstError = firstError ?? error }
        }
        let text = texts.filter { !$0.isEmpty }.joined(separator: " ")
        if text.isEmpty, let firstError { throw firstError }
        return text
    }

    func cancel() {
        queue.async {
            self.tasks.forEach { $0.cancel() }
            self.pending = []
        }
    }

    // MARK: Private (on `queue`)

    private func ingest(_ samples: [Int16]) {
        pending += samples
        while (frameRMS.count + 1) * frame <= pending.count {
            let start = frameRMS.count * frame
            var sum = 0.0
            for j in start..<(start + frame) { let v = Double(pending[j]); sum += v * v }
            let rms = sqrt(sum / Double(frame))
            frameRMS.append(rms)
            allRMS.append(rms)
        }

        // Google's one-shot endpoint can drop a sentence when a piece contains a pause,
        // so pieces are cut at every pause once they're 2 s long.
        let seconds = Double(pending.count) / Double(rate)
        if seconds >= 10 {
            cut(Chunker.split(pending, sampleRate: rate)[0].count)
        } else if seconds >= 2, frameRMS.suffix(12).count == 12, frameRMS.suffix(12).allSatisfy({ $0 < quietLevel }) {
            cut((frameRMS.count - 6) * frame)   // cut in the middle of the 240 ms pause
        }
    }

    /// Background level (10th percentile) plus 15% of the way up to speech level (90th percentile).
    private var quietLevel: Double {
        let sorted = allRMS.sorted()
        let floor = sorted[sorted.count / 10], speech = sorted[sorted.count * 9 / 10]
        return floor + 0.15 * (speech - floor)
    }

    private func cut(_ n: Int) {
        let n = n / frame * frame
        guard n > 0 else { return }
        let chunk = Array(pending[0..<n])
        let peak = frameRMS[0..<(n / frame)].max() ?? 0
        let floor = allRMS.sorted()[allRMS.count / 10]
        let speech = peak > max(floor * 4, 100)
        pending.removeFirst(n)
        frameRMS.removeFirst(n / frame)
        if ProcessInfo.processInfo.environment["DICTATE_DEBUG"] != nil {
            print(String(format: "cut %.2fs speech=%d floor=%.0f max=%.0f", Double(n) / Double(rate), speech ? 1 : 0,
                         floor, peak))
        }
        if speech { dispatch(chunk) }   // pure silence isn't worth a request
    }

    private func dispatch(_ chunk: [Int16]) {
        let lang = self.lang
        tasks.append(Task {
            let text = try await GoogleSpeech.recognize(chunk, lang: lang)
            if ProcessInfo.processInfo.environment["DICTATE_DEBUG"] != nil { print("chunk → \(text)") }
            return text
        })
    }
}
