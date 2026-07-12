import Foundation

public struct Preset: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var prompt: String
    public var isDefault: Bool

    public init(id: UUID = UUID(), name: String, prompt: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.isDefault = isDefault
    }
}
