import Foundation

/// Talks to the speech endpoint Chrome's Web Speech API used, with the shared Chromium key.
/// Unofficial: it can be rate-limited or switched off by Google at any time.
enum GoogleSpeech {
    static let key = "AIzaSyBOti4mM-6x9WDnZIjIeyEU21OpBXqWBgw"
    static let sampleRate = 16_000

    enum Failure: LocalizedError {
        case http(Int, String)
        var errorDescription: String? {
            switch self {
            case let .http(code, body): return "Google returned HTTP \(code): \(body.prefix(200))"
            }
        }
    }

    /// Long recordings lose words when sent in one request, so they are cut at pauses
    /// into ~10 s pieces that are recognized in parallel and joined back in order.
    static func transcribe(_ samples: [Int16], lang: String) async throws -> String {
        let chunks = Chunker.split(samples, sampleRate: sampleRate)
        let texts = try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (i, chunk) in chunks.enumerated() {
                group.addTask { (i, try await recognize(chunk, lang: lang)) }
            }
            var results: [(Int, String)] = []
            for try await r in group { results.append(r) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        return texts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func recognize(_ samples: [Int16], lang: String) async throws -> String {
        var comps = URLComponents(string: "https://www.google.com/speech-api/v2/recognize")!
        comps.queryItems = [
            URLQueryItem(name: "client", value: "chromium"),
            URLQueryItem(name: "lang", value: lang),
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "pFilter", value: "0"),
            URLQueryItem(name: "output", value: "json"),
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("audio/l16; rate=\(sampleRate)", forHTTPHeaderField: "Content-Type")

        // 300 ms of silence on each side so the first and last words aren't clipped.
        let pad = [Int16](repeating: 0, count: sampleRate * 3 / 10)
        let body = (pad + samples + pad).withUnsafeBufferPointer { Data(buffer: $0) }

        let (data, resp) = try await URLSession.shared.upload(for: req, from: body)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else { throw Failure.http(code, String(decoding: data, as: UTF8.self)) }

        // Response is one JSON object per line; the first is usually {"result":[]}.
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let results = obj["result"] as? [[String: Any]] else { continue }
            for r in results {
                if let alts = r["alternative"] as? [[String: Any]],
                   let text = alts.first?["transcript"] as? String {
                    return text
                }
            }
        }
        return ""
    }
}

enum Chunker {
    /// Splits audio longer than `maxSec` at the quietest 200 ms stretch between `minSec` and `maxSec`.
    static func split(_ s: [Int16], sampleRate: Int, maxSec: Double = 10, minSec: Double = 5) -> [[Int16]] {
        let maxLen = Int(maxSec * Double(sampleRate))
        let minLen = Int(minSec * Double(sampleRate))
        let frame = sampleRate / 50        // 20 ms
        let span = 10                       // 10 frames = 200 ms

        var chunks: [[Int16]] = []
        var start = 0
        while s.count - start > maxLen {
            var energies: [Double] = []
            var i = start + minLen
            while i + frame <= start + maxLen {
                var e = 0.0
                for j in i..<(i + frame) { let v = Double(s[j]); e += v * v }
                energies.append(e)
                i += frame
            }
            var cut = start + maxLen
            if energies.count >= span {
                var best = Double.infinity, bestIdx = 0
                var sum = energies[0..<span].reduce(0, +)
                for k in 0...(energies.count - span) {
                    if k > 0 { sum += energies[k + span - 1] - energies[k - 1] }
                    if sum < best { best = sum; bestIdx = k }
                }
                cut = start + minLen + (bestIdx + span / 2) * frame
            }
            chunks.append(Array(s[start..<cut]))
            start = cut
        }
        chunks.append(Array(s[start...]))
        return chunks
    }
}
