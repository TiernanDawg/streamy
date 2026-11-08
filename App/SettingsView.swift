import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("frugalfork.appearance") private var appearance = "system"
    @State private var apiKey = ""
    @State private var keySaved = false
    @State private var keyError: String?
    @State private var isTestingAPIKey = false
    @State private var apiTestMessage: String?
    @State private var apiTestSucceeded = false
    @State private var showResetConfirmation = false

    private var hasKeyToTest: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.configuredGroqKey
    }

    var body: some View {
        @Bindable var model = model
        return Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section {
                SecureField("Groq API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: apiKey) { _, _ in
                        apiTestMessage = nil
                        apiTestSucceeded = false
                    }

                HStack {
                    Image(systemName: model.configuredGroqKey ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .foregroundStyle(model.configuredGroqKey ? .green : .secondary)
                    Text(model.configuredGroqKey ? "API key stored in iOS Keychain" : "No API key saved")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Save API key") {
                    do {
                        try KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        apiKey = ""
                        keySaved = true
                        keyError = nil
                        apiTestMessage = nil
                        apiTestSucceeded = false
                    } catch {
                        keyError = error.localizedDescription
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    Task {
                        isTestingAPIKey = true
                        apiTestMessage = nil
                        apiTestSucceeded = false
                        defer { isTestingAPIKey = false }

                        let typedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        do {
                            try await GroqService.testAPIKey(typedKey.isEmpty ? nil : typedKey)
                            apiTestSucceeded = true
                            apiTestMessage = typedKey.isEmpty
                                ? "Your saved key works. Groq completed a test request with the recipe model."
                                : "This key works. Tap Save API key to store it securely on this iPhone."
                        } catch {
                            apiTestMessage = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        if isTestingAPIKey { ProgressView() }
                        Text(isTestingAPIKey ? "Testing connection…" : "Test API key")
                    }
                }
                .disabled(isTestingAPIKey || !hasKeyToTest)

                if let apiTestMessage {
                    Label(apiTestMessage, systemImage: apiTestSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(apiTestSucceeded ? .green : .red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if keySaved {
                    Label("Saved securely", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
                if let keyError {
                    Text(keyError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("Remove API key", role: .destructive) {
                    do {
                        try KeychainStore.delete()
                        keySaved = false
                        apiTestMessage = nil
                        apiTestSucceeded = false
                    } catch {
                        keyError = error.localizedDescription
                    }
                }
                .disabled(!model.configuredGroqKey)
            } header: {
                Text("Groq AI")
            } footer: {
                Text("Test a newly entered key before saving it, or test the key already stored in Keychain. The key is sent directly to Groq and is never included in the app repository.")
            }

            Section("Walmart") {
                TextField("ZIP code", text: $model.zipCode)
                    .keyboardType(.numberPad)
                    .onChange(of: model.zipCode) { _, newValue in
                        model.zipCode = String(newValue.filter(\.isNumber).prefix(5))
                    }
                Text("Saved for reference. Walmart may ask you to choose a store or delivery ZIP on its website; the app cannot set your Walmart account location.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy & storage") {
                Label("Recipes, pantry and shopping lists stay on this device.", systemImage: "iphone")
                Label("No account, analytics, ads or subscription.", systemImage: "hand.raised")
                Button("Erase all local app data", role: .destructive) {
                    showResetConfirmation = true
                }
            }

            Section("About") {
                LabeledContent("App", value: "FrugalFork")
                LabeledContent("Version", value: "1.0")
                Link("Groq API documentation", destination: URL(string: "https://console.groq.com/docs")!)
                Link("Walmart.com", destination: URL(string: "https://www.walmart.com")!)
            }
        }
        .navigationTitle("Settings")
        .keyboardDoneButton()
        .scrollDismissesKeyboard(.interactively)
        .onAppear { keySaved = model.configuredGroqKey }
        .confirmationDialog("Erase recipes, pantry and shopping list?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Erase local data", role: .destructive) { model.resetLocalData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your Groq API key will remain in Keychain.")
        }
    }
}
