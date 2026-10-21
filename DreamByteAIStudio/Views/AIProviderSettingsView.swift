import SwiftUI

struct AIProviderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: AIProvider = .openRouter
    @State private var apiKey = ""
    @State private var hasSavedKey = false
    @State private var statusMessage: String?
    @State private var isError = false

    private let store = KeychainSecretStore()
    private let electricBlue = Color(red: 0.12, green: 0.62, blue: 1.0)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(selectedProvider.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("AI provider")
                }

                Section {
                    SecureField(selectedProvider.placeholder, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .textContentType(.password)

                    HStack {
                        Label(hasSavedKey ? "A key is saved on this device" : "No key saved", systemImage: hasSavedKey ? "checkmark.shield.fill" : "key")
                            .font(.footnote)
                            .foregroundStyle(hasSavedKey ? .green : .secondary)
                        Spacer()
                    }

                    Button {
                        saveKey()
                    } label: {
                        Label("Save API key securely", systemImage: "lock.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(role: .destructive) {
                        deleteKey()
                    } label: {
                        Label("Delete saved key", systemImage: "trash")
                    }
                    .disabled(!hasSavedKey)
                } header: {
                    Text("Your API key")
                } footer: {
                    Text("The key is stored in the iOS Keychain on this device only. It is not embedded in the app, committed to GitHub, or included in .dbedit project files. Anyone who can access your provider account may incur usage charges, so protect your device and provider account.")
                }

                Section("Model") {
                    if selectedProvider == .openRouter {
                        Text("Default suggestion: \(selectedProvider.defaultModel)")
                        Text("Model selection will become editable when provider requests are implemented. Check OpenRouter for current model availability and pricing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Gemini model selection will be added with the Motion Graphics integration.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(isError ? .red : .green)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.025, green: 0.04, blue: 0.09))
            .navigationTitle("AI Providers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: refreshStatus)
            .onChange(of: selectedProvider) { _, _ in
                apiKey = ""
                statusMessage = nil
                refreshStatus()
            }
        }
        .tint(electricBlue)
        .preferredColorScheme(.dark)
    }

    private func refreshStatus() {
        hasSavedKey = store.containsKey(for: selectedProvider)
    }

    private func saveKey() {
        do {
            try store.save(apiKey, for: selectedProvider)
            apiKey = ""
            hasSavedKey = store.containsKey(for: selectedProvider)
            statusMessage = "API key saved to Keychain. Provider requests are not implemented yet."
            isError = false
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    private func deleteKey() {
        do {
            try store.deleteKey(for: selectedProvider)
            apiKey = ""
            hasSavedKey = false
            statusMessage = "Saved key deleted from this device."
            isError = false
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }
}
