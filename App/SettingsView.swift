import SwiftUI
import WebKit
import UIKit

struct SettingsView: View {
    @AppStorage("streamy.keepAwake") private var keepAwake = true
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var showClearedAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Toggle(isOn: $keepAwake) {
                        Label("Keep screen awake", systemImage: "sun.max")
                    }
                    .onChange(of: keepAwake) { _, newValue in
                        UIApplication.shared.isIdleTimerDisabled = newValue
                    }

                    LabeledContent("Streaming service", value: "Xbox Cloud Gaming")
                    LabeledContent("App mode", value: "In-app WebKit")
                }

                Section("Privacy") {
                    Text("Streamy has no app account, ads, analytics, or backend. Microsoft handles Xbox sign-in and cloud streaming. Your sign-in session is stored by WebKit on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear Xbox sign-in and website data", systemImage: "trash")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Link(destination: URL(string: "https://www.xbox.com/play")!) {
                        Label("Xbox Cloud Gaming", systemImage: "gamecontroller")
                    }
                    Link(destination: URL(string: "https://support.xbox.com/")!) {
                        Label("Xbox Support", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Clear saved Xbox website data?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Website Data", role: .destructive) {
                    clearWebsiteData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This signs you out of Xbox in Streamy and removes saved website data from WebKit.")
            }
            .alert("Website data cleared", isPresented: $showClearedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Xbox website session and cached site data have been removed.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func clearWebsiteData() {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()

        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) {
                Task { @MainActor in
                    showClearedAlert = true
                }
            }
        }
    }
}
