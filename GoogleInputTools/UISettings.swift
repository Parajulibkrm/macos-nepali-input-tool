import SwiftUI

class UISettings {
    // when this is set to true, System UI will be used instead of custom window
    static let SystemUI = true

    // candidate window
    static let WindowPaddingX: CGFloat = 4
    static let WindowPaddingY: CGFloat = 6

    // candidate view
    static let TextColor = NSColor.white
    static let TextBackground = NSColor.black
    static let SelectionBackground = NSColor.systemBlue

    // candidate font
    static let FontSize: CGFloat = 16
    static let FontWeight = NSFont.Weight.regular
    static let Font = NSFont.systemFont(ofSize: FontSize, weight: FontWeight)
}
