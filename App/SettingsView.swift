import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("savorcart.appearance") private var appearance = "system"
    @State private var apiKey = ""
    @State private var keySaved = false
    @State private var keyError: String?
    @State private var showResetConfirmation = false

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
            Section("Groq AI") {
                SecureField("Groq API key", text: $apiKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                HStack {
                    Image(systemName: model.configuredGroqKey ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .foregroundStyle(model.configuredGroqKey ? .green : .secondary)
                    Text(model.configuredGroqKey ? "API key stored in iOS Keychain" : "No API key saved")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("Save API key") {
                    do {
                        try KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        apiKey = ""
                        keySaved = true
                        keyError = nil
                    } catch { keyError = error.localizedDescription }
                }.disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if keySaved { Label("Saved securely", systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(.green) }
                if let keyError { Text(keyError).font(.footnote).foregroundStyle(.red) }
                Button("Remove API key", role: .destructive) {
                    do { try KeychainStore.delete(); keySaved = false }
                    catch { keyError = error.localizedDescription }
                }.disabled(!model.configuredGroqKey)
            } footer: {
                Text("Your key stays on this iPhone in Keychain. It is sent directly to Groq when you generate a recipe. Never paste it into a public repository.")
            }
            Section("Walmart") {
                TextField("ZIP code", text: $model.zipCode)
                    .keyboardType(.numberPad)
                    .onChange(of: model.zipCode) { _, newValue in
                        model.zipCode = String(newValue.filter(\.isNumber).prefix(5))
                    }
                Text("Saved for reference. Walmart may ask you to choose a store or delivery ZIP on its website; the app cannot set your Walmart account location.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Privacy & storage") {
                Label("Recipes, pantry and shopping lists stay on this device.", systemImage: "iphone")
                Label("No account, analytics, ads or subscription.", systemImage: "hand.raised")
                Button("Erase all local app data", role: .destructive) { showResetConfirmation = true }
            }
            Section("About") {
                LabeledContent("App", value: "SavorCart")
                LabeledContent("Version", value: "1.0")
                Link("Groq API documentation", destination: URL(string: "https://console.groq.com/docs")!)
                Link("Walmart.com", destination: URL(string: "https://www.walmart.com")!)
            }
        }
        .navigationTitle("Settings")
        .onAppear { keySaved = model.configuredGroqKey }
        .confirmationDialog("Erase recipes, pantry and shopping list?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Erase local data", role: .destructive) { model.resetLocalData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your Groq API key will remain in Keychain.")
        }
    }
}
