import AppKit
import SwiftUI

/// Developer tools for testing dictation without the hotkey, e.g.
/// `NepaliInput --live sample.raw ne-NP`. Exits the process when a command ran.
func runDebugCommandIfRequested() throws {
    // Debug mode: `NepaliInput --transcribe <file.raw> [lang]` sends a 16 kHz mono s16le file
    // through the same pipeline as the app and prints the text.
    let args = CommandLine.arguments
    if args.count >= 3, args[1] == "--transcribe" {
        let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
        let samples = data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        let lang = args.count >= 4 ? args[3] : "ne-NP"
        let sem = DispatchSemaphore(value: 0)
        Task {
            do {
                let chunks = Chunker.split(samples, sampleRate: GoogleSpeech.sampleRate)
                print("chunks: \(chunks.map { String(format: "%.1fs", Double($0.count) / 16_000) })")
                print(try await GoogleSpeech.transcribe(samples, lang: lang))
            } catch {
                print("error: \(error.localizedDescription)")
            }
            sem.signal()
        }
        sem.wait()
        exit(0)
    }

    // Debug mode: `NepaliInput --live|--stream <file.raw> [lang]` feeds the file at real-time speed
    // through the At Once or Streaming pipeline and reports the wait after "release".
    if args.count >= 3, args[1] == "--live" || args[1] == "--stream" {
        let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
        let samples = data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        let lang = args.count >= 4 ? args[3] : "ne-NP"
        let sem = DispatchSemaphore(value: 0)
        let live = (args[1] == "--stream" ? Mode.streaming : Mode.atOnce).makeTranscriber(lang: lang)
        if args[1] == "--stream" { live.onText = { print("  … \($0)") } }
        Task {
            for i in stride(from: 0, to: samples.count, by: 1024) {
                live.append(Array(samples[i..<min(i + 1024, samples.count)]))
                try? await Task.sleep(nanoseconds: 64_000_000)
            }
            let released = Date()
            do {
                let text = try await live.finish()
                print(String(format: "(%.1fs after release) ", Date().timeIntervalSince(released)) + text)
            } catch {
                print("error: \(error.localizedDescription)")
            }
            sem.signal()
        }
        // Keep the main run loop alive so main-queue callbacks can run.
        while sem.wait(timeout: .now()) == .timedOut { RunLoop.main.run(until: Date() + 0.05) }
        exit(0)
    }

    // Debug mode: `NepaliInput --render-overlay <out.png> [text]` renders the overlay card to an image.
    if args.count >= 3, args[1] == "--render-overlay" {
        let model = Overlay.Model()
        model.text = args.count >= 4 ? args[3] : ""
        model.levels = model.levels.indices.map { i in max(0, sin(Double(i) / 3) * 0.8) * (i > 24 ? 1 : 0.15) }
        if let tiff = MainActor.assumeIsolated({ Overlay.snapshot(model) })?.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: args[2]))
        }
        exit(0)
    }

    // Debug mode: `NepaliInput --render-setup <out.png>` renders the setup guide to an image.
    if args.count >= 3, args[1] == "--render-setup" {
        MainActor.assumeIsolated {
            _ = NSApplication.shared
            let model = SetupModel()
            model.refresh()
            let view = SetupView(model: model, appName: "Nepali Input", onDone: {})
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            host.layoutSubtreeIfNeeded()
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[2]))
            }
        }
        exit(0)
    }
}
