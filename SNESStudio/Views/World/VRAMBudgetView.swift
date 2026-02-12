import SwiftUI

struct VRAMBudgetView: View {
    @Bindable var state: AppState
    @State private var selectedScreenID: UUID?

    private var selectedScreen: WorldScreen? {
        state.assetStore.worldScreens.first { $0.id == selectedScreenID }
    }

    private var selectedZone: WorldZone? {
        guard let screen = selectedScreen else { return nil }
        return state.assetStore.worldZones.first { $0.id == screen.zoneID }
    }

    private var budget: VRAMBudget {
        guard let screen = selectedScreen, let zone = selectedZone else {
            return .empty()
        }
        return VRAMBudgetCalculator.budgetForScreen(screen: screen, zone: zone, tiles: state.assetStore.tiles)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedScreen != nil {
                        budgetOverview
                        Divider()
                        blockDetails
                        Divider()
                        exitCosts
                    } else if state.assetStore.worldScreens.isEmpty {
                        emptyState
                    }
                }
                .padding(16)
            }
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Budget VRAM")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SNESTheme.textPrimary)

            Spacer()

            Picker("Ecran", selection: $selectedScreenID) {
                Text("Choisir un ecran").tag(UUID?.none)
                ForEach(state.assetStore.worldScreens) { s in
                    Text(s.name).tag(UUID?.some(s.id))
                }
            }
            .frame(width: 200)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Budget Overview

    private var budgetOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VRAM: 64 Ko")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SNESTheme.textPrimary)
                Spacer()
                Text(String(format: "%.1f%% utilise", budget.percentage))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(budget.isOverBudget ? SNESTheme.danger : SNESTheme.success)
            }

            // Warning banner
            if budget.isOverBudget {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SNESTheme.danger)
                    Text("Depassement VRAM! Reduisez le nombre de tiles ou utilisez un mode BG avec moins de couleurs.")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.danger)
                }
                .padding(8)
                .background(SNESTheme.danger.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Main progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(SNESTheme.bgPanel)

                    HStack(spacing: 0) {
                        ForEach(budget.blocks.filter { $0.category != .free }) { block in
                            let fraction = CGFloat(block.sizeBytes) / CGFloat(budget.totalBytes)
                            Rectangle()
                                .fill(Color(hex: block.category.colorHex))
                                .frame(width: max(1, geo.size.width * fraction))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(height: 28)

            // Stats
            HStack(spacing: 20) {
                statBox("Utilise", formatBytes(budget.usedBytes), SNESTheme.textPrimary)
                statBox("Libre", formatBytes(budget.freeBytes), SNESTheme.success)
                statBox("Total", "65536 B", SNESTheme.textDisabled)
            }
        }
    }

    private func statBox(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(SNESTheme.textDisabled)
        }
    }

    // MARK: - Block Details

    private var blockDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detail par categorie")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SNESTheme.textSecondary)

            ForEach(budget.blocks) { block in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: block.category.colorHex))
                        .frame(width: 8, height: 8)

                    Text(block.label)
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.textPrimary)

                    Spacer()

                    Text(String(format: "$%04X", block.address))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)

                    Text(formatBytes(block.sizeBytes))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Exit Costs

    private var exitCosts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couts de transition des sorties")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SNESTheme.textSecondary)

            if let screen = selectedScreen, !screen.exits.isEmpty {
                ForEach(screen.exits) { exit in
                    if let targetID = exit.targetScreenID,
                       let target = state.assetStore.worldScreens.first(where: { $0.id == targetID }) {
                        let cost = VRAMBudgetCalculator.transitionCost(
                            from: screen, to: target, tiles: state.assetStore.tiles)

                        HStack(spacing: 8) {
                            Image(systemName: cost.isFeasible ? "checkmark.circle" : "exclamationmark.triangle")
                                .foregroundStyle(cost.isFeasible ? SNESTheme.success : SNESTheme.warning)
                                .font(.system(size: 11))

                            Text("-> \(target.name)")
                                .font(.system(size: 11))
                                .foregroundStyle(SNESTheme.textPrimary)

                            Spacer()

                            Text("\(cost.tilesToLoad) tiles, \(cost.bytesToTransfer) B, \(cost.framesNeeded) frames")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(SNESTheme.textDisabled)
                        }
                    }
                }
            } else {
                Text("Aucune sortie configuree")
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 32))
                .foregroundStyle(SNESTheme.textDisabled)
            Text("Creez des zones et ecrans dans le World Manager pour voir le budget VRAM")
                .font(.system(size: 12))
                .foregroundStyle(SNESTheme.textDisabled)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        }
        return "\(bytes) B"
    }
}
