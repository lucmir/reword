import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let transform = Self("transform", default: .init(.r, modifiers: [.command, .shift]))
}

@MainActor
final class HotkeyManager {
    init(onTransform: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .transform, action: onTransform)
    }
}
