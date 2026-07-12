import Foundation

public final class PromptStore: ObservableObject {
    @Published public private(set) var presets: [Preset] = []
    private let fileURL: URL

    public static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reword/presets.json")
    }

    public init(fileURL: URL = PromptStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode([Preset].self, from: data),
           !loaded.isEmpty {
            presets = loaded
        } else {
            presets = Self.seedPresets
            save()
        }
    }

    public var defaultPreset: Preset {
        presets.first(where: \.isDefault) ?? presets[0]
    }

    public func add(_ preset: Preset) {
        presets.append(preset)
        save()
    }

    public func update(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        save()
    }

    public func delete(id: UUID) {
        if presets.count == 1, presets[0].id == id { return }
        presets.removeAll { $0.id == id }
        if !presets.isEmpty, !presets.contains(where: \.isDefault) {
            presets[0].isDefault = true
        }
        save()
    }

    public func setDefault(id: UUID) {
        guard presets.contains(where: { $0.id == id }) else { return }
        for index in presets.indices {
            presets[index].isDefault = (presets[index].id == id)
        }
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(presets).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("PromptStore save failed: \(error)")
        }
    }

    static let seedPresets: [Preset] = [
        Preset(name: "Improve writing",
               prompt: "You are a writing assistant. Rewrite the user's text to improve clarity, flow, and tone while preserving its meaning, language, and formatting. Return only the rewritten text, with no preamble or explanation.",
               isDefault: true),
        Preset(name: "Make formal",
               prompt: "Rewrite the user's text in a professional, formal tone suitable for business email, preserving its meaning and language. Return only the rewritten text."),
        Preset(name: "Make casual",
               prompt: "Rewrite the user's text in a friendly, casual tone suitable for chat (e.g. Slack), preserving its meaning and language. Return only the rewritten text."),
        Preset(name: "Fix grammar",
               prompt: "Correct spelling, grammar, and punctuation in the user's text. Change nothing else — keep wording, tone, and formatting. Return only the corrected text."),
        Preset(name: "Shorten",
               prompt: "Rewrite the user's text to be roughly half as long while keeping all essential meaning and the same tone and language. Return only the rewritten text."),
    ]
}
