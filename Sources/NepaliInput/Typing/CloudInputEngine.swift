import Foundation

enum InputTool: String {
    case Nepali = "transliteration_en_ne"
}

class CloudInputEngine {

    static let shared = CloudInputEngine()

    let _inputTool = InputTool.Nepali
    let _candidateNum = 11

    /// Always calls `complete`, with no candidates when the request or the reply is bad.
    func requestCandidates(
        _ text: String,
        complete: @escaping (_ candidates: [String], _ matchedLength: [Int]?) -> Void
    ) {
        var components = URLComponents(string: "https://inputtools.google.com/request")!
        components.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "ime", value: _inputTool.rawValue),
            URLQueryItem(name: "num", value: String(_candidateNum)),
            URLQueryItem(name: "cp", value: "0"),
            URLQueryItem(name: "cs", value: "1"),
            URLQueryItem(name: "ie", value: "utf-8"),
            URLQueryItem(name: "oe", value: "utf-8"),
            URLQueryItem(name: "app", value: "demopage"),
        ]
        guard let url = components.url else {
            complete([], nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            // Expected: ["SUCCESS", [[input, [candidates], [], {"matched_length": [...]}]]]
            guard let data,
                  let response = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  response.first as? String == "SUCCESS",
                  let results = response.dropFirst().first as? [Any],
                  let candidateObject = results.first as? [Any],
                  candidateObject.count > 1,
                  let candidateArray = candidateObject[1] as? [String]
            else {
                complete([], nil)
                return
            }
            let candidateMeta = candidateObject.count > 3 ? candidateObject[3] as? [String: Any] : nil
            complete(candidateArray, candidateMeta?["matched_length"] as? [Int])
        }

        task.resume()
    }

    func requestCandidatesSync(_ text: String) -> ([String], [Int]?) {
        let semaphore = DispatchSemaphore(value: 0)

        var candidates: [String] = []
        var matchedLength: [Int]? = []
        requestCandidates(text) { result, length in
            candidates = result
            matchedLength = length
            semaphore.signal()
        }

        semaphore.wait()

        return (candidates, matchedLength)
    }
}
