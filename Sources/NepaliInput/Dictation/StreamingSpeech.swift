import Foundation

/// Streams audio to the full-duplex endpoint Chrome's Web Speech API uses: audio goes up on
/// one chunked POST while interim and final results come back on a paired GET.
/// Fastest and shows words live, but in testing Google sometimes dropped whole sentences.
final class StreamingSpeech: NSObject, Transcriber, URLSessionDataDelegate {
    var onText: ((String) -> Void)?

    private static let base = "https://www.google.com/speech-api/full-duplex/v1"

    private let queue = OperationQueue()                     // all state below is touched only here
    private let writeQueue = DispatchQueue(label: "dictate.upload")
    private var session: URLSession!
    private var upTask: URLSessionDataTask?
    private var downTask: URLSessionDataTask?
    private var output: OutputStream?
    private var buffer = Data()
    private var finals: [String] = []
    private var interim = ""
    private var failure: Error?
    private var done = false
    private var continuation: CheckedContinuation<String, Error>?

    init(lang: String) {
        super.init()
        queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: queue)

        let pair = String((0..<16).map { _ in "0123456789abcdef".randomElement()! })
        func url(_ path: String, _ extra: [URLQueryItem]) -> URL {
            var c = URLComponents(string: "\(Self.base)/\(path)")!
            c.queryItems = [URLQueryItem(name: "key", value: GoogleSpeech.key),
                            URLQueryItem(name: "pair", value: pair),
                            URLQueryItem(name: "output", value: "json")] + extra
            return c.url!
        }

        var down = URLRequest(url: url("down", []))
        down.timeoutInterval = 60

        var input: InputStream?
        Stream.getBoundStreams(withBufferSize: 1 << 18, inputStream: &input, outputStream: &output)
        output?.open()
        var up = URLRequest(url: url("up", [
            URLQueryItem(name: "lang", value: lang),
            URLQueryItem(name: "client", value: "chromium"),
            URLQueryItem(name: "continuous", value: nil),
            URLQueryItem(name: "interim", value: nil),
            URLQueryItem(name: "pFilter", value: "0"),
        ]))
        up.httpMethod = "POST"
        up.timeoutInterval = 60
        up.httpBodyStream = input
        up.setValue("audio/l16; rate=\(GoogleSpeech.sampleRate)", forHTTPHeaderField: "Content-Type")

        downTask = session.dataTask(with: down)
        upTask = session.dataTask(with: up)
        downTask?.resume()
        upTask?.resume()
    }

    func append(_ samples: [Int16]) {
        guard !samples.isEmpty else { return }
        writeQueue.async { [output] in
            guard let output else { return }
            samples.withUnsafeBytes { raw in
                let p = raw.bindMemory(to: UInt8.self).baseAddress!
                var offset = 0
                while offset < raw.count {
                    let n = output.write(p + offset, maxLength: raw.count - offset)
                    if n <= 0 { return }
                    offset += n
                }
            }
        }
    }

    /// Ends the upload and waits for Google's last results.
    func finish() async throws -> String {
        append([Int16](repeating: 0, count: GoogleSpeech.sampleRate * 3 / 10))  // trailing silence
        writeQueue.async { [output] in output?.close() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.queue.addOperation { self?.complete() }
        }
        return try await withCheckedThrowingContinuation { cont in
            queue.addOperation {
                if self.done { cont.resume(with: self.result()) } else { self.continuation = cont }
            }
        }
    }

    func cancel() {
        writeQueue.async { [output] in output?.close() }
        queue.addOperation { self.complete() }
    }

    // MARK: Private (on `queue`)

    private var text: String {
        (finals + [interim]).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func result() -> Result<String, Error> {
        if text.isEmpty, let failure { return .failure(failure) }
        return .success(text)
    }

    private func complete() {
        guard !done else { return }
        done = true
        session.invalidateAndCancel()   // also breaks the session → delegate retain cycle
        continuation?.resume(with: result())
        continuation = nil
    }

    private func parse(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let results = obj["result"] as? [[String: Any]], !results.isEmpty else { continue }
            var partial = ""
            for r in results {
                guard let t = (r["alternative"] as? [[String: Any]])?.first?["transcript"] as? String else { continue }
                if r["final"] as? Bool == true {
                    finals.append(t.trimmingCharacters(in: .whitespaces))
                } else {
                    partial += t
                }
            }
            interim = partial.trimmingCharacters(in: .whitespaces)
            let snapshot = text
            DispatchQueue.main.async { [onText] in onText?(snapshot) }
        }
    }

    // MARK: URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        if code != 200 {
            failure = GoogleSpeech.Failure.http(code, dataTask === upTask ? "streaming upload" : "streaming results")
            completionHandler(.cancel)
            complete()
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if dataTask === downTask { parse(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, (error as? URLError)?.code != .cancelled, failure == nil { failure = error }
        // Google closes the results stream once it has sent everything for the finished upload.
        if task === downTask {
            if !buffer.isEmpty { parse(Data("\n".utf8)) }
            complete()
        } else if error != nil {
            complete()
        }
    }
}
