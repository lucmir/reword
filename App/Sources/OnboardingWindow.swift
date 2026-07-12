import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private var timer: Timer?

    func showIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Reword"
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        // Ask macOS to show the permission prompt.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if AXIsProcessTrusted() {
                    self?.timer?.invalidate()
                    self?.window?.close()
                }
            }
        }
    }
}

private struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 40))
            Text("Reword needs Accessibility permission")
                .font(.headline)
            Text("It's used to read the text you select and replace it with the rewritten version. Enable Reword in System Settings, then this window will close automatically.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 440)
    }
}
