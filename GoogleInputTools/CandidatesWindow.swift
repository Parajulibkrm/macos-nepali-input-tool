import Foundation
import InputMethodKit
import SwiftUI

class CandidatesWindow: NSWindow {

    static let shared = CandidatesWindow()

    var _view: CandidatesView

    override init(
        contentRect: NSRect, styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool
    ) {
        self._view = CandidatesView()

        super.init(
            contentRect: contentRect, styleMask: NSWindow.StyleMask.borderless,
            backing: backingStoreType, defer: flag)

        self.isOpaque = false
        self.level = NSWindow.Level.floating
        self.backgroundColor = NSColor.clear

        self._view = CandidatesView.init(frame: self.frame)
        self.contentView = _view
        self.orderFront(nil)
    }

    func update(sender: IMKTextInput) {
        let caretPosition = self.getCaretPosition(sender: sender)

        let numberedCandidates = InputContext.shared.numberedCandidates
        let text = numberedCandidates.joined(separator: " ")
        let textToPaint: NSMutableAttributedString = NSMutableAttributedString.init(string: text)

        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UISettings.Font
        ]

        textToPaint.addAttributes(attributes, range: NSMakeRange(0, text.count))

        // do not paint by default
        var rect: NSRect = NSZeroRect

        // calculate candidate window position and size
        if text.count > 0 {
            rect = NSMakeRect(
                caretPosition.x,
                caretPosition.y - textToPaint.size().height - UISettings.WindowPaddingY * 2,
                textToPaint.size().width + UISettings.WindowPaddingX * 2,
                textToPaint.size().height + UISettings.WindowPaddingY * 2)
        }

        NSLog(
            "CandidatesWindow::update rect: (%.0f, %.0f, %.0f, %.0f)",
            rect.origin.x, rect.origin.y, rect.width, rect.height)

        self.setFrame(rect, display: true)

        // adjust candidate view
        self._view.setNeedsDisplay(rect)
    }

    func getCaretPosition(sender: IMKTextInput) -> NSPoint {
        var pos: NSPoint
        let lineHeightRect: UnsafeMutablePointer<NSRect> = UnsafeMutablePointer<NSRect>.allocate(
            capacity: 1)

        sender.attributes(forCharacterIndex: 0, lineHeightRectangle: lineHeightRect)

        let rect = lineHeightRect.pointee
        pos = NSMakePoint(rect.origin.x, rect.origin.y)

        return pos
    }

    func show() {
        self.setIsVisible(true)
    }

    func hide() {
        self.setIsVisible(false)
    }
}
