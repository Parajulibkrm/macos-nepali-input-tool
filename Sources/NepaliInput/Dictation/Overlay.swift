import AppKit
import SwiftUI

/// Small dark card with a neon edge at the bottom of the screen: live words (Streaming mode)
/// above a row of level bars while listening, a spinner while Google transcribes.
/// Never takes focus or mouse clicks.
final class Overlay {
    enum Phase { case listening, working }

    final class Model: ObservableObject {
        @Published var phase = Phase.listening
        @Published var levels = [CGFloat](repeating: 0, count: 44)
        @Published var text = ""

        func push(_ level: CGFloat) {
            levels.removeFirst()
            levels.append(level)
        }
    }

    let model = Model()
    private static let size = NSSize(width: 600, height: 150)

    private lazy var panel: NSPanel = {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = NSHostingView(rootView: PillView(model: model)
            .frame(width: Self.size.width, height: Self.size.height))
        return p
    }()

    func show(_ phase: Phase) {
        model.phase = phase
        if phase == .listening {
            model.levels = model.levels.map { _ in 0 }
            model.text = ""
        }
        guard !panel.isVisible else { return }
        // Bottom-center of the screen the mouse is on.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.midX - Self.size.width / 2, y: f.minY + 32))
        }
        panel.orderFrontRegardless()
    }

    func level(_ value: Float) {
        model.push(CGFloat(value))
    }

    func text(_ value: String) {
        model.text = value
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Renders the card offscreen (for `Dictate --render-overlay`).
    @MainActor static func snapshot(_ model: Model) -> NSImage? {
        let renderer = ImageRenderer(content: PillView(model: model)
            .frame(width: size.width, height: size.height)
            .background(Color(white: 0.92)))
        renderer.scale = 2
        return renderer.nsImage
    }
}

private struct PillView: View {
    @ObservedObject var model: Overlay.Model

    private static let width: CGFloat = 360
    private static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    private static let neon = AngularGradient(
        colors: [.pink, .purple, .blue, .cyan, .mint, .pink], center: .center)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.text.isEmpty {
                Text(model.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(3)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.phase == .listening {
                bars
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).environment(\.colorScheme, .dark)
                    Text("Transcribing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: model.text.isEmpty ? 240 : Self.width)   // compact until there are words to show
        .background(Self.shape.fill(Color.black.opacity(0.88)))
        .background(Self.shape.stroke(Self.neon, lineWidth: 6).blur(radius: 10).opacity(0.9))   // outer glow
        .overlay(Self.shape.strokeBorder(Self.neon, lineWidth: 1.5))                            // crisp edge
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 16)
        .animation(.easeOut(duration: 0.15), value: model.text.isEmpty)
    }

    /// Dots when quiet, rising into bars with your voice.
    private var bars: some View {
        // Fewer, recent bars in the compact card so they don't crowd.
        let levels = model.text.isEmpty ? Array(model.levels.suffix(28)) : model.levels
        return HStack(spacing: 0) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.35 + 0.6 * Double(levels[i])))
                    .frame(width: 4, height: max(4, levels[i] * 20))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 20)
        .animation(.linear(duration: 0.08), value: model.levels)
    }
}
