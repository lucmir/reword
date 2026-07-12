import SwiftUI
import RewordCore

struct APISettingsView: View {
    @State private var apiKey = ""
    @State private var status: String?
    @State private var testing = false

    private let secretStore = AppServices.shared.secretStore

    var body: some View {
        Form {
            SecureField("Anthropic API key", text: $apiKey)
                .onSubmit(saveKey)
            HStack {
                Button("Save", action: saveKey)
                Button("Test connection") {
                    testConnection()
                }
                .disabled(testing)
                if testing { ProgressView().controlSize(.small) }
            }
            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Text("Get a key at console.anthropic.com. Stored in the macOS Keychain.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .onAppear {
            apiKey = secretStore.get() ?? ""
        }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            secretStore.delete()
            status = "Key removed."
        } else {
            secretStore.set(trimmed)
            status = "Key saved to Keychain."
        }
    }

    private func testConnection() {
        saveKey()
        testing = true
        status = nil
        Task {
            do {
                _ = try await AppServices.shared.provider.transform(
                    text: "ping", prompt: "Reply with exactly: pong"
                )
                status = "Connection OK."
            } catch let error as AIError {
                status = "Failed: \(error.userMessage)"
            } catch {
                status = "Failed: \(error.localizedDescription)"
            }
            testing = false
        }
    }
}
