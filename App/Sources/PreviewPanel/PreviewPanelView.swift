import SwiftUI

struct PreviewPanelView: View {
    @ObservedObject var model: PanelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
            footer
        }
        .padding([.horizontal, .bottom], 14)
        .padding(.top, 18) // below the titlebar ("Rewrite" + close button)
        .frame(width: 400)
    }

    private var header: some View {
        HStack {
            Image(systemName: "wand.and.stars")
            Picker("", selection: $model.selectedPresetID) {
                ForEach(model.presets) { preset in
                    Text(preset.name).tag(Optional(preset.id))
                }
            }
            .labelsHidden()
            .onChange(of: model.selectedPresetID) {
                if case .loading = model.state { return }
                model.onRetry()
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Rewriting…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        case .result(let text):
            ScrollView {
                Text(text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
            .frame(maxHeight: 180)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Button("Retry", action: model.onRetry)
            Spacer()
            Button("Copy", action: model.onCopy)
            Button("Apply", action: model.onApply)
                .keyboardShortcut(.defaultAction)
                .disabled(!isResult)
        }
        .disabled(model.state == .loading)
    }

    private var isResult: Bool {
        if case .result = model.state { return true }
        return false
    }
}
