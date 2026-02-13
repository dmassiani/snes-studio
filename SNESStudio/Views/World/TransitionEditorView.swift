import SwiftUI

struct TransitionEditorView: View {
    @Bindable var state: AppState
    @State private var selectedTransitionID: UUID?

    private var selectedIndex: Int? {
        state.assetStore.worldTransitions.firstIndex { $0.id == selectedTransitionID }
    }

    var body: some View {
        HSplitView {
            // Transition list
            transitionList
                .frame(width: 260)

            // Config panel
            if let idx = selectedIndex {
                transitionConfig(index: idx)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 32))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Text("Select a transition")
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.textDisabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - List

    private var transitionList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transitions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
                Button(action: addTransition) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(SNESTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(SNESTheme.bgPanel)

            Divider()

            List(selection: $selectedTransitionID) {
                ForEach(state.assetStore.worldTransitions) { transition in
                    transitionRow(transition)
                        .tag(transition.id)
                }
                .onDelete(perform: deleteTransitions)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(SNESTheme.bgPanel)
    }

    private func transitionRow(_ transition: WorldTransition) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(PyramidLevel.orchestre.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(transition.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SNESTheme.textPrimary)
                Text("\(transition.type.rawValue) - \(transition.durationFrames) frames")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            Spacer()
        }
    }

    // MARK: - Config

    private func transitionConfig(index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SNESTheme.textSecondary)
                    TextField("Name", text: $state.assetStore.worldTransitions[index].name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                // Type
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Picker("", selection: $state.assetStore.worldTransitions[index].type) {
                        ForEach(TransitionType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .labelsHidden()
                }

                // Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration (frames)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Stepper("\(state.assetStore.worldTransitions[index].durationFrames) frames",
                            value: $state.assetStore.worldTransitions[index].durationFrames,
                            in: 0...120)
                        .font(.system(size: 12, design: .monospaced))
                }

                // From/To screens
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Source screen")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Picker("", selection: $state.assetStore.worldTransitions[index].fromScreenID) {
                        Text("None").tag(UUID?.none)
                        ForEach(state.assetStore.worldScreens) { s in
                            Text(s.name).tag(UUID?.some(s.id))
                        }
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Target screen")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Picker("", selection: $state.assetStore.worldTransitions[index].toScreenID) {
                        Text("None").tag(UUID?.none)
                        ForEach(state.assetStore.worldScreens) { s in
                            Text(s.name).tag(UUID?.some(s.id))
                        }
                    }
                    .labelsHidden()
                }

                // Estimated cost
                Divider()
                transitionCostView(index: index)

                Spacer()
            }
            .padding(16)
        }
        .background(SNESTheme.bgPanel)
    }

    private func transitionCostView(index: Int) -> some View {
        let transition = state.assetStore.worldTransitions[index]
        let fromScreen = transition.fromScreenID.flatMap { id in
            state.assetStore.worldScreens.first { $0.id == id }
        }
        let toScreen = transition.toScreenID.flatMap { id in
            state.assetStore.worldScreens.first { $0.id == id }
        }

        return VStack(alignment: .leading, spacing: 4) {
            Text("Estimated cost")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SNESTheme.textSecondary)

            if let from = fromScreen, let to = toScreen {
                let cost = VRAMBudgetCalculator.transitionCost(
                    from: from, to: to, tiles: state.assetStore.tiles)

                HStack(spacing: 12) {
                    costLabel("Tiles to load", "\(cost.tilesToLoad)")
                    costLabel("Tiles to remove", "\(cost.tilesToRemove)")
                }
                HStack(spacing: 12) {
                    costLabel("Bytes", "\(cost.bytesToTransfer)")
                    costLabel("Frames", "\(cost.framesNeeded)")
                }

                if cost.isFeasible {
                    Label("Feasible in VBlank", systemImage: "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.success)
                } else {
                    Label("Too heavy for a single VBlank -- use progressive loading",
                          systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.warning)
                }
            } else {
                Text("Select the source and target screens")
                    .font(.system(size: 11))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
        }
    }

    private func costLabel(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(SNESTheme.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(SNESTheme.textDisabled)
        }
    }

    // MARK: - Actions

    private func addTransition() {
        var t = WorldTransition.empty()
        t.name = "Transition \(state.assetStore.worldTransitions.count + 1)"
        state.assetStore.worldTransitions.append(t)
        selectedTransitionID = t.id
    }

    private func deleteTransitions(at offsets: IndexSet) {
        state.assetStore.worldTransitions.remove(atOffsets: offsets)
        if let id = selectedTransitionID,
           !state.assetStore.worldTransitions.contains(where: { $0.id == id }) {
            selectedTransitionID = state.assetStore.worldTransitions.first?.id
        }
    }
}
