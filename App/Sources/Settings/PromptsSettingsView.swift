import SwiftUI
import RewordCore

struct PromptsSettingsView: View {
    @ObservedObject var store = AppServices.shared.promptStore
    @State private var selectedID: UUID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(store.presets, selection: $selectedID) { preset in
                    HStack {
                        Text(preset.name)
                        if preset.isDefault {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .imageScale(.small)
                        }
                    }
                    .tag(preset.id)
                }
                HStack(spacing: 4) {
                    Button {
                        let preset = Preset(name: "New preset", prompt: "Rewrite the user's text.")
                        store.add(preset)
                        selectedID = preset.id
                    } label: { Image(systemName: "plus") }
                    Button {
                        if let id = selectedID {
                            store.delete(id: id)
                            selectedID = nil
                        }
                    } label: { Image(systemName: "minus") }
                    .disabled(selectedID == nil || store.presets.count <= 1)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(minWidth: 160, maxWidth: 200)

            if let id = selectedID,
               let preset = store.presets.first(where: { $0.id == id }) {
                PresetEditor(preset: preset, store: store)
                    .padding()
            } else {
                Text("Select a preset")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct PresetEditor: View {
    @State var preset: Preset
    let store: PromptStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $preset.name)
            Text("Prompt").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $preset.prompt)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
            HStack {
                Button("Make default") {
                    store.setDefault(id: preset.id)
                }
                .disabled(preset.isDefault)
                Spacer()
                Button("Save") {
                    store.update(preset)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
