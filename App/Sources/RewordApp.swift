import SwiftUI
import RewordCore

@MainActor
final class AppServices: ObservableObject {
    static let shared = AppServices()
    let promptStore = PromptStore()
    private init() {}
}

@main
struct RewordApp: App {
    @StateObject private var services = AppServices.shared

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
