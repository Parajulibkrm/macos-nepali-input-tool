import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case settings = "Settings", setup = "Setup"
    var id: String { rawValue }
}

/// Mirrors the dictation preferences so SwiftUI can bind to them; changes write straight through.
final class SettingsModel: ObservableObject {
    private let dictation = DictationController.shared

    @Published var lang: String { didSet { dictation.lang = lang } }
    @Published var mode: Mode { didSet { dictation.mode = mode } }
    @Published var hotkey: HotkeyKey { didSet { dictation.hotkeyKey = hotkey } }
    @Published var toggles: Bool { didSet { dictation.togglesHotkey = toggles } }
    @Published var showsMenuBarIcon: Bool { didSet { dictation.showsMenuBarIcon = showsMenuBarIcon } }
    @Published var startsAtLogin: Bool
    @Published var loginError: String?

    init() {
        lang = dictation.lang
        mode = dictation.mode
        hotkey = dictation.hotkeyKey
        toggles = dictation.togglesHotkey
        showsMenuBarIcon = dictation.showsMenuBarIcon
        startsAtLogin = dictation.startsAtLogin
        NotificationCenter.default.addObserver(forName: .dictationSettingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
    }

    private func reload() {
        lang = dictation.lang
        mode = dictation.mode
        hotkey = dictation.hotkeyKey
        toggles = dictation.togglesHotkey
        showsMenuBarIcon = dictation.showsMenuBarIcon
        startsAtLogin = dictation.startsAtLogin
    }

    func setStartsAtLogin(_ on: Bool) {
        loginError = dictation.setStartsAtLogin(on)
        startsAtLogin = dictation.startsAtLogin
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings").font(.largeTitle.bold())

            Section("Dictation") {
                Row("Language", note: "What you speak.") {
                    Picker("", selection: $model.lang) {
                        ForEach(DictationController.languages, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .labelsHidden().frame(width: 170)
                }
                Row("Dictation key") {
                    Picker("", selection: $model.hotkey) {
                        ForEach(HotkeyKey.all) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().frame(width: 170)
                }
                Row("Behavior", note: model.toggles
                    ? "Press the key to start, press it again to type. Esc cancels."
                    : "Hold the key while you speak, release to type. Any other key cancels.") {
                    Picker("", selection: $model.toggles) {
                        Text("Hold").tag(false)
                        Text("Toggle").tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 170)
                }
                Row("Mode", note: model.mode == .atOnce
                    ? "Sends pauses to Google while you talk. Text appears after you release."
                    : "Shows words as you speak, but Google can drop some.") {
                    Picker("", selection: $model.mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0 == .atOnce ? "At Once" : "Streaming").tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 170)
                }
            }

            Section("General") {
                Row("Show icon in menu bar") {
                    Toggle("", isOn: $model.showsMenuBarIcon).labelsHidden()
                }
                Row("Start at login", note: model.loginError) {
                    Toggle("", isOn: Binding(get: { model.startsAtLogin }, set: model.setStartsAtLogin))
                        .labelsHidden()
                }
            }
        }
        .padding(24)
        .frame(width: 540, alignment: .leading)
    }
}

private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
        }
    }
}

private struct Row<Control: View>: View {
    let title: String
    let note: String?
    @ViewBuilder let control: Control
    init(_ title: String, note: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title; self.note = note; self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let note { Text(note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

/// Window root: Settings and the setup guide behind one switcher.
struct MainView: View {
    @ObservedObject var setup: SetupModel
    @ObservedObject var settings: SettingsModel
    let appName: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $setup.tab) {
                ForEach(SettingsTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 200).padding(.top, 8)
            switch setup.tab {
            case .settings: SettingsView(model: settings)
            case .setup: SetupView(model: setup, appName: appName, onDone: onDone)
            }
        }
    }
}
