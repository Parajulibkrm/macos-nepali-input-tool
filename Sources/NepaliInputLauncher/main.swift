import AppKit

// Tiny stand-in that lives in /Applications so the input method can be found with Spotlight.
// It starts the real app (an input method, which has no Dock icon) and asks it to open its window.
let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Nepali Input"
let candidates = ["/Library/Input Methods", NSHomeDirectory() + "/Library/Input Methods"]
guard let path = candidates.map({ "\($0)/\(name).app" }).first(where: { FileManager.default.fileExists(atPath: $0) }) else {
    let alert = NSAlert()
    alert.messageText = "\(name) isn't installed"
    alert.informativeText = "Install it again, then add the keyboard in System Settings → Keyboard → Input Sources."
    alert.runModal()
    exit(1)
}

let url = URL(fileURLWithPath: path)
let config = NSWorkspace.OpenConfiguration()
config.activates = true
let wasRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleURL == url }

NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
    // A running app gets a "reopen" request straight away. One that just started needs a moment
    // before it's listening, so ask again.
    DispatchQueue.main.asyncAfter(deadline: .now() + (wasRunning ? 0.2 : 1.5)) {
        if wasRunning { exit(0) }
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in exit(0) }
    }
}
RunLoop.main.run()
