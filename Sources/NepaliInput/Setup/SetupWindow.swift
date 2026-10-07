import AppKit
import AVFoundation
import Carbon.HIToolbox
import SwiftUI

/// Live state of everything the user has to do once. Polled while the window is open,
/// so each step ticks itself off as soon as they finish it in System Settings.
final class SetupModel: ObservableObject {
    @Published var keyboardAdded = false
    @Published var keyboardSelected = false
    @Published var microphone = AVAuthorizationStatus.notDetermined
    @Published var accessibility = false
    @Published var tab = SettingsTab.setup

    private var timer: Timer?

    func startPolling() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let source = Self.inputSource()
        keyboardAdded = source.map { Self.bool($0, kTISPropertyInputSourceIsEnabled) } ?? false
        keyboardSelected = Self.currentKeyboardBundleID() == Bundle.main.bundleIdentifier
        microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibility = AXIsProcessTrusted()
    }

    func selectKeyboard() {
        if let source = Self.inputSource() { TISSelectInputSource(source) }
        refresh()
    }

    func requestMicrophone() {
        if microphone == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
        } else {
            Self.openSettings("Privacy_Microphone")
        }
    }

    static func openSettings(_ pane: String) {
        let url = pane.hasPrefix("com.apple") ? "x-apple.systempreferences:\(pane)"
                                              : "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }

    private static func inputSource() -> TISInputSource? {
        guard let id = Bundle.main.bundleIdentifier else { return nil }
        let filter = [kTISPropertyBundleID: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else { return nil }
        return list.first
    }

    private static func currentKeyboardBundleID() -> String? {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let raw = TISGetInputSourceProperty(current, kTISPropertyBundleID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }

    private static func bool(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue())
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel
    let appName: String
    let onDone: () -> Void
    @State private var tryText = ""

    private var micGranted: Bool { model.microphone == .authorized }
    private var required: Bool { model.keyboardAdded && micGranted }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set up \(appName)").font(.largeTitle.bold())
                Text("Type Nepali with a romanized keyboard, or hold Right Option and speak.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                StepCard(number: 1, title: "Add the keyboard", done: model.keyboardAdded) {
                    Text("System Settings → Keyboard → Input Sources → Edit… → **+** → choose **Nepali** → **\(appName)** → Add.")
                    Button("Open Keyboard Settings") { SetupModel.openSettings("com.apple.Keyboard-Settings.extension") }
                }
                StepCard(number: 2, title: "Switch to it", done: model.keyboardSelected, enabled: model.keyboardAdded) {
                    Text("Pick \(appName) from the input menu in the menu bar, or switch here.")
                    Button("Switch to \(appName)") { model.selectKeyboard() }
                }
                StepCard(number: 3, title: "Allow the microphone", done: micGranted) {
                    Text("Your voice is sent to Google for transcription only while you hold the key.")
                    Button(model.microphone == .notDetermined ? "Allow Microphone" : "Open Microphone Settings") {
                        model.requestMicrophone()
                    }
                }
                StepCard(number: 4, title: "Dictate in every keyboard (optional)", done: model.accessibility, optional: true) {
                    Text("Accessibility lets Right Option work and paste text even when another keyboard is active.")
                    Button("Grant Accessibility") {
                        DictationController.shared.requestAccessibility()
                        SetupModel.openSettings("Privacy_Accessibility")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Try it").font(.headline)
                TextField("Type “namaste” and press space, or hold Right Option and speak", text: $tryText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                Text("Typing: 1–9 picks a suggestion, space commits. Dictation: hold Right Option, speak, release. Any other key cancels.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(required ? "Done" : "Finish Later", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 540)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
    }
}

private struct StepCard<Content: View>: View {
    let number: Int
    let title: String
    let done: Bool
    var enabled = true
    var optional = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green : Color.secondary.opacity(0.2)).frame(width: 28, height: 28)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                if !done {
                    content.font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
        .opacity(enabled ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: done)
    }
}

/// Owns the setup window. Shown on first run and from "Setup Guide…" in the menus.
final class SetupWindowController: NSObject, NSWindowDelegate {
    static let shared = SetupWindowController()
    private static let doneKey = "setupCompleted"

    private var window: NSWindow?
    private let model = SetupModel()

    static var needsSetup: Bool { !UserDefaults.standard.bool(forKey: doneKey) }

    func show(_ tab: SettingsTab = .settings) {
        model.tab = tab
        if window == nil {
            let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Nepali Input"
            let host = NSHostingController(rootView: MainView(setup: model, settings: SettingsModel(), appName: name) { [weak self] in self?.finish() })
            let w = NSWindow(contentViewController: host)
            w.title = "\(name) Setup"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.doneKey)
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        // Closing the window counts as seen; it stays reachable from the menu.
        UserDefaults.standard.set(true, forKey: Self.doneKey)
    }
}
