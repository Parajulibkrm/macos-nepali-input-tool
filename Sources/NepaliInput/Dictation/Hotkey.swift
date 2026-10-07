import AppKit

/// A modifier key that can be held to talk. `mask` is its device-specific bit in the event flags
/// (so left and right keys can be told apart); `otherMask` is the same bit of its twin.
struct HotkeyKey: Identifiable, Hashable {
    let id: String
    let title: String
    let keyCode: UInt16
    let mask: UInt
    let otherMask: UInt
    let flag: NSEvent.ModifierFlags

    static let all = [
        HotkeyKey(id: "rightOption", title: "Right Option", keyCode: 61, mask: 0x40, otherMask: 0x20, flag: .option),
        HotkeyKey(id: "leftOption", title: "Left Option", keyCode: 58, mask: 0x20, otherMask: 0x40, flag: .option),
        HotkeyKey(id: "rightCommand", title: "Right Command", keyCode: 54, mask: 0x10, otherMask: 0x8, flag: .command),
        HotkeyKey(id: "rightControl", title: "Right Control", keyCode: 62, mask: 0x2000, otherMask: 0x1, flag: .control),
    ]
    static let `default` = all[0]

    static func == (a: HotkeyKey, b: HotkeyKey) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Hold-to-talk on a modifier key (Right Option by default). Pressing any other key while
/// holding cancels, so shortcuts that use the same modifier keep working.
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
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] in self?.feed($0) }) {
            monitors.append(m)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] in self?.feed($0); return $0 }) {
            monitors.append(m)
        }
    }

    /// Accepts a key event from any source; duplicates of the same event are ignored.
    func feed(_ e: NSEvent) {
        guard e.timestamp != lastTimestamp else { return }
        lastTimestamp = e.timestamp

        if e.type == .keyDown { otherKey(escape: e.keyCode == 53); return }
        guard e.type == .flagsChanged else { return }
        guard e.keyCode == key.keyCode else { otherKey(escape: false); return }
        let raw = e.modifierFlags.rawValue
        let down = raw & key.mask != 0
        // The same press also arrives from the other source with the modifier flag but without
        // this key's device bit; reading that copy as "released" cut every hold short. It only
        // counts as a release when the twin key (e.g. Left Option) is what keeps the flag set.
        if e.modifierFlags.contains(key.flag) && !down && raw & key.otherMask == 0 { return }
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
