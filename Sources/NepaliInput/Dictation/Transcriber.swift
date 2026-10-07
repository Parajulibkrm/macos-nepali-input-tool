import Foundation

/// Turns audio fed in while the hotkey is held into text once it's released.
protocol Transcriber: AnyObject {
    /// Live text while speaking, on the main queue (only streaming provides it).
    var onText: ((String) -> Void)? { get set }
    /// Safe to call from the audio thread.
    func append(_ samples: [Int16])
    func finish() async throws -> String
    func cancel()
}

enum Mode: String, CaseIterable {
    case atOnce, streaming

    var title: String {
        switch self {
        case .atOnce: return "At Once (most accurate)"
        case .streaming: return "Streaming (live text, may drop words)"
        }
    }

    func makeTranscriber(lang: String) -> Transcriber {
        switch self {
        case .atOnce: return LiveTranscriber(lang: lang)
        case .streaming: return StreamingSpeech(lang: lang)
        }
    }
}
