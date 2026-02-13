import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var saved: Bool = false
    @State private var selectedLanguage: AppLanguage = .system
    @State private var needsRestart: Bool = false

    private let keychainKey = "anthropic_api_key"

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Language")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SNESTheme.textPrimary)

                    Picker("", selection: $selectedLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                    .onChange(of: selectedLanguage) { _, newValue in
                        newValue.apply()
                        needsRestart = true
                    }

                    if needsRestart {
                        Label("Restart the app to apply the new language", systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.warning)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Anthropic API Key")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SNESTheme.textPrimary)

                    Text("Required for the built-in AI assistant. Get a key at console.anthropic.com")
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
                        Button("Save") {
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
                            Label("Saved", systemImage: "checkmark.circle.fill")
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
        .frame(width: 480, height: 340)
        .onAppear {
            apiKey = KeychainHelper.read(key: keychainKey) ?? ""
            selectedLanguage = AppLanguage.current
        }
    }
}

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case fr
    case es

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: String(localized: "System default")
        case .en:     "English"
        case .fr:     "Français"
        case .es:     "Español"
        }
    }

    static var current: AppLanguage {
        guard let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
              let first = langs.first else {
            return .system
        }
        // UserDefaults may store "fr-FR" style — match prefix
        for lang in AppLanguage.allCases where lang != .system {
            if first.hasPrefix(lang.rawValue) { return lang }
        }
        return .system
    }

    func apply() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}
