import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @AppStorage("model") private var model = "claude-opus-4-8"

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Transform selection:", name: .transform)
            Picker("Model:", selection: $model) {
                Text("Claude Opus 4.8 (best)").tag("claude-opus-4-8")
                Text("Claude Sonnet 5 (balanced)").tag("claude-sonnet-5")
                Text("Claude Haiku 4.5 (fastest)").tag("claude-haiku-4-5")
            }
        }
        .padding()
    }
}
