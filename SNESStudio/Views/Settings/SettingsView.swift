import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var saved: Bool = false

    private let keychainKey = "anthropic_api_key"

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cle API Anthropic")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SNESTheme.textPrimary)

                    Text("Necessaire pour l'assistant IA integre. Obtenez une cle sur console.anthropic.com")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)

                    HStack(spacing: 8) {
                        Group {
                            if showKey {
                                TextField("sk-ant-...", text: $apiKey)
                            } else {
                                SecureField("sk-ant-...", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(SNESTheme.textSecondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Button("Sauvegarder") {
                            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                KeychainHelper.delete(key: keychainKey)
                            } else {
                                KeychainHelper.save(key: keychainKey, value: trimmed)
                            }
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                saved = false
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        if saved {
                            Label("Sauvegarde", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(SNESTheme.success)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 200)
        .onAppear {
            apiKey = KeychainHelper.read(key: keychainKey) ?? ""
        }
    }
}
