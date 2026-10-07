import AppKit

/// Pastes text at the cursor via the clipboard + ⌘V, then puts the old clipboard back.
enum Paster {
    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        let saved: [NSPasteboardItem] = (pb.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }

        pb.clearContents()
        pb.setString(text, forType: .string)
        // Tells clipboard managers not to record this entry.
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        for keyDown in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: keyDown)
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pb.clearContents()
            if !saved.isEmpty { pb.writeObjects(saved) }
        }
    }
}
