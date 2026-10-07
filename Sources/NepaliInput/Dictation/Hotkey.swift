import AppKit

/// The key that starts dictation: a single modifier key (either side) or a function key.
/// For modifiers, `mask` is the key's device-specific bit in the event flags (so left and right
/// can be told apart) and `otherMask` the same bit of its twin; function keys have neither.
struct HotkeyKey: Identifiable, Hashable {
    let keyCode: UInt16
    let title: String
    let mask: UInt
    let otherMask: UInt
    let flag: NSEvent.ModifierFlags?

    var id: UInt16 { keyCode }
    var isModifier: Bool { flag != nil }

    private static let modifiers = [
        HotkeyKey(keyCode: 61, title: "Right Option", mask: 0x40, otherMask: 0x20, flag: .option),
        HotkeyKey(keyCode: 58, title: "Left Option", mask: 0x20, otherMask: 0x40, flag: .option),
        HotkeyKey(keyCode: 54, title: "Right Command", mask: 0x10, otherMask: 0x8, flag: .command),
        HotkeyKey(keyCode: 55, title: "Left Command", mask: 0x8, otherMask: 0x10, flag: .command),
        HotkeyKey(keyCode: 62, title: "Right Control", mask: 0x2000, otherMask: 0x1, flag: .control),
        HotkeyKey(keyCode: 59, title: "Left Control", mask: 0x1, otherMask: 0x2000, flag: .control),
        HotkeyKey(keyCode: 60, title: "Right Shift", mask: 0x4, otherMask: 0x2, flag: .shift),
        HotkeyKey(keyCode: 56, title: "Left Shift", mask: 0x2, otherMask: 0x4, flag: .shift),
        HotkeyKey(keyCode: 63, title: "Fn", mask: 0x800000, otherMask: 0, flag: .function),
    ]

    private static let functionKeys: [HotkeyKey] = [
        (122, 1), (120, 2), (99, 3), (118, 4), (96, 5), (97, 6), (98, 7), (100, 8), (101, 9), (109, 10),
        (103, 11), (111, 12), (105, 13), (107, 14), (113, 15), (106, 16), (64, 17), (79, 18), (80, 19), (90, 20),
    ].map { HotkeyKey(keyCode: UInt16($0.0), title: "F\($0.1)", mask: 0, otherMask: 0, flag: nil) }

    static let `default` = modifiers[0]

    /// The key for a recorded key code, or nil when it can't be used (letters, arrows…).
    static func forKeyCode(_ code: UInt16) -> HotkeyKey? {
        (modifiers + functionKeys).first { $0.keyCode == code }
    }

    static func == (a: HotkeyKey, b: HotkeyKey) -> Bool { a.keyCode == b.keyCode }
    func hash(into hasher: inout Hasher) { hasher.combine(keyCode) }
}

/// Hold-to-talk on one key (Right Option by default). Pressing any other key while holding
/// cancels, so shortcuts that use the same modifier keep working.
///
/// Events arrive from two places: global monitors (any app, needs Accessibility) and the
/// input method itself while it's the active keyboard (no permission needed). When both
/// see the same event it's handled once.
final class Hotkey {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    var onCancel: () -> Void = {}

    /// Press once to start and again to stop, instead of holding. Esc cancels.
    var toggles = false {
        didSet { if toggles != oldValue, held { held = false; onCancel() } }
    }

    /// Forget a press that the dictation controller refused (e.g. no microphone access).
    func reset() { held = false }

    var key = HotkeyKey.default {
        didSet {
            guard key != oldValue else { return }
            // Changing the key mid-hold must not leave a recording running.
            if held { held = false; onCancel() }
        }
    }
    private var monitors: [Any] = []
    private var held = false
    private var lastTimestamp: TimeInterval = -1

    var isMonitoringGlobally: Bool { !monitors.isEmpty }

    func startGlobalMonitoring() {
        guard monitors.isEmpty else { return }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp], handler: { [weak self] in self?.feed($0) }) {
            monitors.append(m)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp], handler: { [weak self] in self?.feed($0); return $0 }) {
            monitors.append(m)
        }
    }

    /// Accepts a key event from any source; duplicates of the same event are ignored.
    func feed(_ e: NSEvent) {
        guard e.timestamp != lastTimestamp else { return }
        lastTimestamp = e.timestamp

        if key.isModifier {
            if e.type == .keyDown { otherKey(escape: e.keyCode == 53); return }
            guard e.type == .flagsChanged else { return }
            guard e.keyCode == key.keyCode else { otherKey(escape: false); return }
            let raw = e.modifierFlags.rawValue
            // The same press also arrives from the other source with the modifier flag but without
            // this key's device bit; reading that copy as "released" cut every hold short. It only
            // counts as a release when the twin key (e.g. Left Option) is what keeps the flag set.
            let down = raw & key.mask != 0
            if let flag = key.flag, e.modifierFlags.contains(flag), !down, raw & key.otherMask == 0 { return }
            changed(down: down)
        } else {
            switch e.type {
            case .keyDown:
                if e.keyCode == key.keyCode { if !e.isARepeat { changed(down: true) } }
                else { otherKey(escape: e.keyCode == 53) }
            case .keyUp:
                if e.keyCode == key.keyCode { changed(down: false) }
            default:
                break
            }
        }
    }

    private func changed(down: Bool) {
        if toggles {
            guard down else { return }
            if held { held = false; onRelease() } else { held = true; onPress() }
        } else if down && !held {
            held = true; onPress()
        } else if !down && held {
            held = false; onRelease()
        }
    }

    private func otherKey(escape: Bool) {
        // Toggled dictation keeps running while you press other keys; only Esc cancels it.
        guard held, !toggles || escape else { return }
        held = false
        onCancel()
    }
}
