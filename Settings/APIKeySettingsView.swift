//
//  APIKeySettingsView.swift
//  NotabilityClone
//

import SwiftUI

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var savedMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MonochromeHeading(title: "NVIDIA API Key", level: .h4)

            Text("Get a free API key from build.nvidia.com. Stored securely in macOS Keychain.")
                .font(MonochromeTypography.sm())
                .foregroundColor(MonochromeColors.mutedForeground)

            SecureField("NVIDIA API Key", text: $apiKey)
                .textFieldStyle(.plain)
                .padding(12)
                .overlay(Rectangle().stroke(MonochromeColors.border, lineWidth: MonochromeBorders.thin))

            if let savedMessage {
                Text(savedMessage)
                    .font(MonochromeTypography.sm())
                    .foregroundColor(.green)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(MonochromeTypography.sm())
                    .foregroundColor(.red)
            }

            HStack {
                MonochromeButton(title: "Remove Key", variant: .ghost) {
                    KeychainStore.deleteAPIKey()
                    apiKey = ""
                    savedMessage = "API key removed."
                    errorMessage = nil
                    NotificationCenter.default.post(name: .apiKeyDidChange, object: nil)
                }

                Spacer()

                MonochromeButton(title: "Cancel", variant: .ghost) {
                    dismiss()
                }

                MonochromeButton(title: "Save", variant: .primary) {
                    saveKey()
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(40)
        .frame(width: 480)
        .background(MonochromeColors.background)
        .onAppear {
            apiKey = KeychainStore.loadAPIKey() ?? ""
        }
    }

    private func saveKey() {
        do {
            try KeychainStore.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            savedMessage = "API key saved to Keychain."
            errorMessage = nil
            NotificationCenter.default.post(name: .apiKeyDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
            savedMessage = nil
        }
    }
}

#Preview {
    APIKeySettingsView()
}
