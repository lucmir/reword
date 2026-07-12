import AppKit
import SwiftUI

/// NSPanel that closes on Esc without needing key-window status tricks.
private final class DismissablePanel: NSPanel {
    var onCancel: () -> Void = {}
    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PreviewPanelController {
    let viewModel = PanelViewModel()
    private var panel: DismissablePanel?

    func show() {
        if panel == nil {
            let panel = DismissablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 240),
                styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: PreviewPanelView(model: viewModel))
            panel.onCancel = { [weak self] in self?.viewModel.onDismiss() }
            self.panel = panel
        }
        positionNearMouse()
        panel?.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func positionNearMouse() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 16)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            origin.x = min(max(origin.x, screen.visibleFrame.minX + 8),
                           screen.visibleFrame.maxX - size.width - 8)
            origin.y = min(max(origin.y, screen.visibleFrame.minY + 8),
                           screen.visibleFrame.maxY - size.height - 8)
        }
        panel.setFrameOrigin(origin)
    }
}
