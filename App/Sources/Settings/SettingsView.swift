import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            PromptsSettingsView()
                .tabItem { Label("Prompts", systemImage: "text.quote") }
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            APISettingsView()
                .tabItem { Label("API", systemImage: "key") }
        }
        .frame(width: 520, height: 380)
    }
}
