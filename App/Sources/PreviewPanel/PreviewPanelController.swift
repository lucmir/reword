import AppKit
import Combine
import SwiftUI

/// NSPanel that closes on Esc without needing key-window status tricks.
private final class DismissablePanel: NSPanel {
    var onCancel: () -> Void = {}
    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
    /// The titlebar close button triggers this; route through the coordinator's
    /// dismiss (cancels in-flight work) instead of closing the window directly.
    override func performClose(_ sender: Any?) {
        onCancel()
    }
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PreviewPanelController {
    let viewModel = PanelViewModel()
    private var panel: DismissablePanel?
    private var escMonitors: [Any] = []
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // The panel is sized when shown (usually in the loading state); grow or
        // shrink it when the content changes to a result or an error.
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.resizeToFit() }
            }
            .store(in: &cancellables)
    }

    private func resizeToFit() {
        guard let panel, panel.isVisible, let contentView = panel.contentView else { return }
        let fitting = contentView.fittingSize
        let newHeight = max(fitting.height, 160)
        guard abs(panel.frame.height - newHeight) > 1 else { return }
        // Keep the top edge anchored so the panel grows downward-stable
        // relative to where it appeared.
        var frame = panel.frame
        frame.origin.y += frame.height - newHeight
        frame.size = NSSize(width: 400, height: newHeight)
        panel.setFrame(frame, display: true, animate: true)
    }

    func show() {
        if panel == nil {
            let panel = DismissablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 240),
                styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: PreviewPanelView(model: viewModel))
            panel.onCancel = { [weak self] in self?.viewModel.onDismiss() }
            self.panel = panel
        }
        if let contentView = panel?.contentView {
            let fitting = contentView.fittingSize
            panel?.setContentSize(NSSize(width: 400, height: max(fitting.height, 160)))
        }
        positionNearMouse()
        panel?.orderFrontRegardless()
        installEscMonitors()
    }

    func close() {
        removeEscMonitors()
        panel?.orderOut(nil)
    }

    private func installEscMonitors() {
        guard escMonitors.isEmpty else { return }
        let handler: () -> Void = { [weak self] in self?.viewModel.onDismiss() }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            if event.keyCode == 53 { handler(); return nil }
            return event
        }) {
            escMonitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { event in
            if event.keyCode == 53 { handler() }
        }) {
            escMonitors.append(global)
        }
    }

    private func removeEscMonitors() {
        escMonitors.forEach { NSEvent.removeMonitor($0) }
        escMonitors.removeAll()
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
