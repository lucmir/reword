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
    let panel = PreviewPanelController()
    private(set) lazy var provider: AIProvider = AnthropicProvider(
        apiKey: { [secretStore] in secretStore.get() },
        model: { UserDefaults.standard.string(forKey: "model") ?? "claude-opus-4-8" }
    )
    private(set) lazy var coordinator = TransformCoordinator(
        captureService: captureService,
        provider: provider,
        promptStore: promptStore,
        panel: panel
    )
    private var hotkeyManager: HotkeyManager?

    private init() {}

    func start() {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.coordinator.run()
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
