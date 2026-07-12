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
    private let onboarding = OnboardingWindowController()

    private init() {}

    func start() {
        onboarding.showIfNeeded()
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
            SettingsMenuItem()
            Divider()
            Button("Quit Reword") {
                NSApp.terminate(nil)
            }
        }
        Settings {
            SettingsView()
        }
    }
}

/// Opens Settings and activates the app. A plain `SettingsLink` in an
/// LSUIElement app opens the window without activating, leaving it buried
/// behind the frontmost app's windows.
private struct SettingsMenuItem: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
    }
}
