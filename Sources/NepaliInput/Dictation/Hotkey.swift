import AppKit

/// Hold-to-talk on Right Option. Pressing any other key while holding cancels,
/// so Option shortcuts (⌥-letter, ⌥⇧…) keep working.
///
/// Events arrive from two places: global monitors (any app, needs Accessibility) and the
/// input method itself while it's the active keyboard (no permission needed). When both
/// see the same event it's handled once.
final class Hotkey {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    var onCancel: () -> Void = {}

    private static let rightOptionKeyCode: UInt16 = 61
    private static let rightOptionMask: UInt = 0x40   // NX_DEVICERALTKEYMASK
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

        if e.type == .keyDown { otherKey(); return }
        guard e.type == .flagsChanged else { return }
        guard e.keyCode == Self.rightOptionKeyCode else { otherKey(); return }
        // The same key press also arrives from the other source with the Option flag but without
        // the right-key device bit; reading that copy as "released" cut every hold short.
        let option = e.modifierFlags.contains(.option)
        let down = e.modifierFlags.rawValue & Self.rightOptionMask != 0
        if option && !down { return }
        if down && !held { held = true; onPress() }
        else if !down && held { held = false; onRelease() }
    }

    private func otherKey() {
        guard held else { return }
        held = false
        onCancel()
    }
}
