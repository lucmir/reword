import AppKit
import RewordCore

@MainActor
final class TransformCoordinator {
    private let captureService: TextCaptureService
    private let provider: AIProvider
    private let promptStore: PromptStore
    private let panel: PreviewPanelController

    private var captured: CapturedText?
    private var currentResult: String?
    private var task: Task<Void, Never>?

    init(captureService: TextCaptureService,
         provider: AIProvider,
         promptStore: PromptStore,
         panel: PreviewPanelController) {
        self.captureService = captureService
        self.provider = provider
        self.promptStore = promptStore
        self.panel = panel

        panel.viewModel.onApply = { [weak self] in self?.apply() }
        panel.viewModel.onCopy = { [weak self] in self?.copyResult() }
        panel.viewModel.onRetry = { [weak self] in self?.transform() }
        panel.viewModel.onDismiss = { [weak self] in self?.dismiss() }
    }

    func run() {
        task?.cancel()

        panel.viewModel.presets = promptStore.presets
        panel.viewModel.selectedPresetID = promptStore.defaultPreset.id

        do {
            captured = try captureService.captureSelection()
        } catch CaptureError.permissionDenied {
            captured = nil
            showError("Reword needs Accessibility permission. Open System Settings → Privacy & Security → Accessibility.")
            return
        } catch {
            captured = nil
            showError("Select some text first, then press the hotkey.")
            return
        }
        transform()
    }

    private func transform() {
        guard let captured else { return }
        let preset = promptStore.presets.first { $0.id == panel.viewModel.selectedPresetID }
            ?? promptStore.defaultPreset

        panel.viewModel.state = .loading
        panel.show()

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.provider.transform(text: captured.text, prompt: preset.prompt)
                guard !Task.isCancelled else { return }
                self.currentResult = result
                self.panel.viewModel.state = .result(result)
            } catch let error as AIError {
                guard !Task.isCancelled else { return }
                self.panel.viewModel.state = .error(error.userMessage)
            } catch {
                guard !Task.isCancelled else { return }
                self.panel.viewModel.state = .error("Something went wrong. Try again.")
            }
        }
    }

    private func apply() {
        guard let result = currentResult, let captured else { return }
        panel.close()
        do {
            try captureService.replaceSelection(with: result, using: captured.method)
        } catch {
            // Replacement failed — fall back to putting the result on the clipboard.
            copyToClipboard(result)
        }
        reset()
    }

    private func copyResult() {
        guard let result = currentResult else { return }
        copyToClipboard(result)
        panel.close()
        reset()
    }

    private func dismiss() {
        task?.cancel()
        panel.close()
        reset()
    }

    private func showError(_ message: String) {
        panel.viewModel.state = .error(message)
        panel.show()
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func reset() {
        captured = nil
        currentResult = nil
        task = nil
    }
}
