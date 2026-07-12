import SwiftUI
import RewordCore

@MainActor
final class AppServices: ObservableObject {
    static let shared = AppServices()

    let promptStore = PromptStore()
    let secretStore: SecretStore = KeychainSecretStore()
    let captureService = TextCaptureService(
        accessibility: AccessibilityCaptureStrategy(),
        clipboard: ClipboardCaptureStrategy()
    )
    private var hotkeyManager: HotkeyManager?

    private init() {}

    func start() {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleTransform()
        }
    }

    func handleTransform() {
        do {
            let captured = try captureService.captureSelection()
            NSLog("Reword captured (\(captured.method)): \(captured.text)")
        } catch {
            NSLog("Reword capture failed: \(error)")
        }
    }
}

@main
struct RewordApp: App {
    @StateObject private var services = AppServices.shared

    init() {
        AppServices.shared.start()
    }

    var body: some Scene {
        MenuBarExtra("Reword", systemImage: "wand.and.stars") {
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit Reword") {
                NSApp.terminate(nil)
            }
        }
        Settings {
            Text("Settings coming soon")
                .frame(width: 400, height: 200)
        }
    }
}
