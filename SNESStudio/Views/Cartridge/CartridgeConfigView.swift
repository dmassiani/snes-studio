import SwiftUI

struct CartridgeConfigView: View {
    @Bindable var state: AppState

    @State private var config: CartridgeConfig
    @State private var errorMessage: String?

    init(state: AppState) {
        self.state = state
        self._config = State(initialValue: state.projectManager.currentProject?.cartridge ?? .default)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 16))
                        .foregroundStyle(PyramidLevel.hardware.accent)
                    Text("CARTRIDGE CONFIGURATION")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(PyramidLevel.hardware.accent)
                }

                // Profile grid
                profileGrid

                SNESTheme.border.frame(height: 1)

                // Detail editors
                detailSection

                SNESTheme.border.frame(height: 1)

                // Summary
                summarySection

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.danger)
                }

                // Actions
                HStack {
                    Button("Apply") { applyConfig() }
                        .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        if let profile = CartridgeProfile.preset(for: config.selectedProfileID) {
                            config = CartridgeConfig.fromProfile(profile)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SNESTheme.textSecondary)
                }
            }
            .padding(20)
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Profile Grid

    private var profileGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK PROFILE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(SNESTheme.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
                ForEach(CartridgeProfile.presets) { profile in
                    CartridgeProfileCard(
                        profile: profile,
                        isSelected: config.selectedProfileID == profile.id
                    ) {
                        config = CartridgeConfig.fromProfile(profile)
                    }
                }
            }
        }
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CONFIGURATION DETAILS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(SNESTheme.textSecondary)

            // ROM
            GroupBox("ROM") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Size")
                            .font(.system(size: 12))
                            .foregroundStyle(SNESTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $config.romSizeKB) {
                            ForEach(config.availableROMSizes, id: \.self) { size in
                                Text(size >= 1024 ? "\(size / 1024) MB" : "\(size) KB").tag(size)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Mapping")
                            .font(.system(size: 12))
                            .foregroundStyle(SNESTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $config.mapping) {
                            ForEach(ROMMapping.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Speed")
                            .font(.system(size: 12))
                            .foregroundStyle(SNESTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $config.speed) {
                            ForEach(ROMSpeed.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }
                .padding(4)
            }

            // SRAM
            GroupBox("SRAM (save data)") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Size")
                            .font(.system(size: 12))
                            .foregroundStyle(SNESTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $config.sramSizeKB) {
                            ForEach(CartridgeConfig.sramSizes, id: \.self) { size in
                                Text(size == 0 ? "None" : "\(size) KB").tag(size)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                .padding(4)
            }

            // Enhancement chip
            GroupBox("Enhancement Chip") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Chip")
                            .font(.system(size: 12))
                            .foregroundStyle(SNESTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $config.chip) {
                            ForEach(EnhancementChip.allCases) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    if config.chip != .none {
                        Text(config.chip.description)
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.warning)
                    }
                }
                .padding(4)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUMMARY")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(SNESTheme.textSecondary)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    SummaryField(label: "Map byte", value: String(format: "$%02X", config.mappingHeaderByte))
                    SummaryField(label: "Type byte", value: String(format: "$%02X", config.cartridgeTypeByte))
                    SummaryField(label: "ROM byte", value: String(format: "$%02X", config.romSizeHeaderByte))
                }
                VStack(alignment: .leading, spacing: 4) {
                    SummaryField(label: "SRAM byte", value: String(format: "$%02X", config.sramSizeHeaderByte))
                    SummaryField(label: "Linker", value: config.linkerConfigName)
                    SummaryField(label: "ROM start", value: config.mapping.romStartAddress)
                }
            }
        }
    }

    // MARK: - Apply

    private func applyConfig() {
        do {
            try state.projectManager.updateCartridge(config)
            state.recalculateBudget()
            state.appendConsole("Cartridge config updated: \(config.mapping.rawValue) \(config.romSizeKB) KB", type: .success)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Profile Card

private struct CartridgeProfileCard: View {
    let profile: CartridgeProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? SNESTheme.textPrimary : SNESTheme.textSecondary)
                Text(profile.romSizeKB >= 1024 ? "\(profile.romSizeKB / 1024) MB" : "\(profile.romSizeKB) KB")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSelected ? PyramidLevel.hardware.accent : SNESTheme.textDisabled)
                Text(profile.mapping.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? PyramidLevel.hardware.accentBg : SNESTheme.bgPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? PyramidLevel.hardware.accent : SNESTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Field

private struct SummaryField: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(SNESTheme.textDisabled)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(SNESTheme.textPrimary)
        }
    }
}
