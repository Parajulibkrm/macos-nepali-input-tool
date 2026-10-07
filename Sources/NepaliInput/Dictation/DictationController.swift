import AppKit
import AVFoundation
import ServiceManagement

/// Hold the dictation key (Right Option by default), speak, release: the words are typed where the cursor is.
/// While this input method is the active keyboard the text goes straight into the app;
/// otherwise it's pasted (which, like the global hotkey, needs Accessibility).
final class DictationController: NSObject, NSMenuDelegate {
    static let shared = DictationController()
    static let languages = [("ne-NP", "Nepali"), ("en-US", "English (US)"), ("hi-IN", "Hindi")]

    private enum State { case idle, listening, working }

    let hotkey = Hotkey()
    private let overlay = Overlay()
    private var statusItem: NSStatusItem?
    private var recorder: Recorder?
    private var transcriber: Transcriber?
    private var pressedAt = Date()
    private var status = ""
    private var state = State.idle { didSet { refreshIcon() } }

    private let defaults = UserDefaults.standard

    var lang: String {
        get { defaults.string(forKey: "dictationLanguage") ?? "ne-NP" }
        set { defaults.set(newValue, forKey: "dictationLanguage") }
    }

    var mode: Mode {
        get { Mode(rawValue: defaults.string(forKey: "dictationMode") ?? "") ?? .atOnce }
        set { defaults.set(newValue.rawValue, forKey: "dictationMode") }
    }

    var hotkeyKey: HotkeyKey {
        get { HotkeyKey.all.first { $0.id == defaults.string(forKey: "hotkeyKey") } ?? .default }
        set { defaults.set(newValue.id, forKey: "hotkeyKey"); hotkey.key = newValue }
    }

    var togglesHotkey: Bool {
        get { defaults.bool(forKey: "hotkeyToggle") }
        set { defaults.set(newValue, forKey: "hotkeyToggle"); hotkey.toggles = newValue }
    }

    var showsMenuBarIcon: Bool {
        get { defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showMenuBarIcon"); refreshStatusItem() }
    }

    func start() {
        hotkey.key = hotkeyKey
        hotkey.toggles = togglesHotkey
        hotkey.onPress = { [weak self] in self?.begin() }
        hotkey.onRelease = { [weak self] in self?.finish() }
        hotkey.onCancel = { [weak self] in self?.cancel() }
        refreshStatusItem()

        // First run: the setup guide walks through the permissions instead of a bare system prompt.
        if SetupWindowController.needsSetup {
            DispatchQueue.main.async { SetupWindowController.shared.show(.setup) }
        }
        // Global hotkey works once Accessibility is granted; until then dictation only
        // works while this keyboard is active (the input method sees the key itself).
        if AXIsProcessTrusted() {
            hotkey.startGlobalMonitoring()
        } else {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.hotkey.startGlobalMonitoring()
            }
        }
        setStatus(idleStatus)
    }

    private var idleStatus: String {
        AXIsProcessTrusted() ? (togglesHotkey ? "Press \(hotkeyKey.title) to start and stop dictating" : "Hold \(hotkeyKey.title) to dictate") : "Dictation works in this keyboard only (Accessibility off)"
    }

    func requestAccessibility() {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
    }

    // MARK: Dictation

    private func begin() {
        guard state == .idle else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            setStatus("Allow microphone access, then try again")
            hotkey.reset()
            return
        default:
            fail("Microphone is off: System Settings → Privacy & Security → Microphone")
            hotkey.reset()
            return
        }

        let rec = Recorder()
        let live = mode.makeTranscriber(lang: lang)
        live.onText = { [weak self] in self?.overlay.text($0) }
        rec.onLevel = { [weak self] in self?.overlay.level($0) }
        rec.onSamples = { live.append($0) }
        do {
            try rec.start()
        } catch {
            live.cancel()
            fail(error.localizedDescription)
            hotkey.reset()
            return
        }
        recorder = rec
        transcriber = live
        pressedAt = Date()
        state = .listening
        overlay.show(.listening)
        NSSound(named: "Tink")?.play()
    }

    private func finish() {
        guard state == .listening, let rec = recorder, let live = transcriber else { return }
        recorder = nil
        transcriber = nil
        let samples = rec.stop()
        // A tap shorter than this is almost certainly accidental.
        guard Date().timeIntervalSince(pressedAt) > 0.3 else {
            live.cancel()
            state = .idle
            overlay.hide()
            return
        }

        state = .working
        overlay.show(.working)
        let lang = self.lang
        Task {
            do {
                let streamed = try await live.finish()
                // Streaming can come back empty when Google drops the utterance; retry once in one go.
                let text = streamed.isEmpty && live is StreamingSpeech
                    ? try await GoogleSpeech.transcribe(samples, lang: lang)
                    : streamed
                await MainActor.run {
                    self.overlay.hide()
                    self.state = .idle
                    if text.isEmpty {
                        self.fail("Didn't catch that")
                    } else {
                        self.deliver(text + " ")
                    }
                }
            } catch {
                await MainActor.run {
                    self.overlay.hide()
                    self.state = .idle
                    self.fail(error.localizedDescription)
                }
            }
        }
    }

    private func cancel() {
        guard state == .listening, let rec = recorder else { return }
        recorder = nil
        _ = rec.stop()
        transcriber?.cancel()
        transcriber = nil
        overlay.hide()
        state = .idle
    }

    private func deliver(_ text: String) {
        if let input = InputController.active, input.insertDictation(text) {
            setStatus(idleStatus)
        } else if AXIsProcessTrusted() {
            Paster.paste(text)
            setStatus(idleStatus)
        } else {
            fail("Turn on Accessibility to dictate into other keyboards")
        }
    }

    private func fail(_ message: String) {
        NSSound(named: "Basso")?.play()
        setStatus(message)
    }

    var statusText: String { status }

    private func setStatus(_ text: String) {
        status = text
    }

    // MARK: Menus

    private func refreshStatusItem() {
        if showsMenuBarIcon, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
            refreshIcon()
        } else if !showsMenuBarIcon, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let (symbol, tint): (String, NSColor?) = switch state {
        case .idle: ("mic", nil)
        case .listening: ("mic.fill", .systemRed)
        case .working: ("ellipsis.circle", nil)
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Dictation")
        button.contentTintColor = tint
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu, target: self, action: #selector(menuAction(_:)))
    }

    /// Dictation settings, shared by the menu-bar icon and the input method's own menu.
    /// Input-method menus send actions to the input controller, which forwards to `menuAction`.
    func populate(_ menu: NSMenu, target: AnyObject?, action: Selector) {
        menu.removeAllItems()
        func item(_ title: String, _ tag: String, on: Bool = false) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
            i.target = target
            i.representedObject = tag
            i.state = on ? .on : .off
            return i
        }

        let header = NSMenuItem(title: "Dictation: \(status)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if !AXIsProcessTrusted() {
            menu.addItem(item("Enable Dictation in All Keyboards…", "accessibility"))
        }

        let langMenu = NSMenu()
        for (code, name) in Self.languages { langMenu.addItem(item(name, "lang:\(code)", on: code == lang)) }
        let langItem = NSMenuItem(title: "Dictation Language", action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        let keyMenu = NSMenu()
        for k in HotkeyKey.all { keyMenu.addItem(item(k.title, "key:\(k.id)", on: k == hotkeyKey)) }
        keyMenu.addItem(.separator())
        keyMenu.addItem(item("Hold to Talk", "behavior:hold", on: !togglesHotkey))
        keyMenu.addItem(item("Press to Start / Stop", "behavior:toggle", on: togglesHotkey))
        let keyItem = NSMenuItem(title: "Dictation Key", action: nil, keyEquivalent: "")
        keyItem.submenu = keyMenu
        menu.addItem(keyItem)

        let modeMenu = NSMenu()
        for m in Mode.allCases { modeMenu.addItem(item(m.title, "mode:\(m.rawValue)", on: m == mode)) }
        let modeItem = NSMenuItem(title: "Dictation Mode", action: nil, keyEquivalent: "")
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        menu.addItem(.separator())
        menu.addItem(item("Show Icon in Menu Bar", "menubar", on: showsMenuBarIcon))
        menu.addItem(item("Start at Login", "login", on: startsAtLogin))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", "settings"))
        menu.addItem(item("Setup Guide…", "setup"))
    }

    var startsAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message when the system refuses.
    func setStartsAtLogin(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @objc func menuAction(_ sender: NSMenuItem) {
        let tag = sender.representedObject as? String ?? ""
        if tag.hasPrefix("lang:") {
            lang = String(tag.dropFirst(5))
        } else if tag.hasPrefix("key:"), let k = HotkeyKey.all.first(where: { $0.id == String(tag.dropFirst(4)) }) {
            hotkeyKey = k
        } else if tag.hasPrefix("behavior:") {
            togglesHotkey = tag == "behavior:toggle"
        } else if tag.hasPrefix("mode:"), let m = Mode(rawValue: String(tag.dropFirst(5))) {
            mode = m
        } else if tag == "menubar" {
            showsMenuBarIcon.toggle()
        } else if tag == "login" {
            if let error = setStartsAtLogin(!startsAtLogin) { setStatus("Start at Login failed: \(error)") }
        }
        NotificationCenter.default.post(name: .dictationSettingsChanged, object: nil)
        switch tag {
        case "settings": SetupWindowController.shared.show(.settings)
        case "setup": SetupWindowController.shared.show(.setup)
        case "accessibility":
            requestAccessibility()
            SetupModel.openSettings("Privacy_Accessibility")
        default: break
        }
    }
}

extension Notification.Name {
    /// Posted when a setting changes from the menus, so an open settings window can follow.
    static let dictationSettingsChanged = Notification.Name("dictationSettingsChanged")
}
