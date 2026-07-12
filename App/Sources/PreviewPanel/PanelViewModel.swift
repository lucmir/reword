import Foundation
import RewordCore

enum PanelState: Equatable {
    case loading
    case result(String)
    case error(String)
}

@MainActor
final class PanelViewModel: ObservableObject {
    @Published var state: PanelState = .loading
    @Published var presets: [Preset] = []
    @Published var selectedPresetID: UUID?

    var onApply: () -> Void = {}
    var onCopy: () -> Void = {}
    var onRetry: () -> Void = {}
    var onDismiss: () -> Void = {}
}
