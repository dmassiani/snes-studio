import SwiftUI

struct ControllerEditorView: View {
    @Bindable var state: AppState

    @State private var mapping = ControllerMapping()
    @State private var selectedButton: SNESButton? = nil
    @State private var showGeneratedCode: Bool = false
    @State private var undoMgr = EditorUndoManager<ControllerMapping>()

    var body: some View {
        HSplitView {
            // Left: Controller visual
            VStack(spacing: 0) {
                HStack {
                    Text("CONTROLLER MAPPING")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(SNESTheme.textSecondary)
                    Spacer()

                    Button {
                        showGeneratedCode.toggle()
                    } label: {
                        Text(showGeneratedCode ? "Pad" : "Code")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SNESTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(SNESTheme.bgPanel))
                    }
                    .buttonStyle(.plain)

                    Button("Generate input.asm") {
                        generateInputASM()
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SNESTheme.info)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(SNESTheme.info.opacity(0.15)))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(SNESTheme.bgPanel)
                .overlay(alignment: .bottom) {
                    SNESTheme.border.frame(height: 1)
                }

                if showGeneratedCode {
                    codePreview
                } else {
                    controllerVisual
                }
            }

            // Right: Action editor
            actionEditor
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
        }
        .background(SNESTheme.bgEditor)
        .onChange(of: selectedButton) {
            undoMgr.recordState(mapping)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorUndo)) { _ in
            if let prev = undoMgr.undo(current: mapping) { mapping = prev }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorRedo)) { _ in
            if let next = undoMgr.redo(current: mapping) { mapping = next }
        }
        .onChange(of: mapping) {
            state.assetStore.controllerMapping = mapping
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onAppear {
            mapping = state.assetStore.controllerMapping
        }
        .onDisappear {
            state.assetStore.controllerMapping = mapping
            NotificationCenter.default.post(name: .assetStoreDidChange, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .assetStoreDidChange)) { _ in
            mapping = state.assetStore.controllerMapping
        }
    }

    // MARK: - Controller Visual

    private var controllerVisual: some View {
        ZStack {
            // Background
            SNESTheme.bgEditor

            VStack {
                Spacer()

                ZStack {
                    // Controller body
                    ControllerBodyShape()
                        .fill(
                            LinearGradient(
                                colors: [SNESControllerColors.body, SNESControllerColors.bodyDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 400, height: 240)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                    // L bumper
                    buttonView(.l, x: -140, y: -15, width: 60, height: 20, color: SNESControllerColors.bumper, label: "L")
                    // R bumper
                    buttonView(.r, x: 140, y: -15, width: 60, height: 20, color: SNESControllerColors.bumper, label: "R")

                    // DPad
                    dpadView
                        .offset(x: -110, y: 40)

                    // Face buttons (ABXY) - SNES layout
                    buttonView(.x, x: 110, y: 15, width: 28, height: 28, color: SNESControllerColors.buttonX, label: "X")
                    buttonView(.a, x: 138, y: 40, width: 28, height: 28, color: SNESControllerColors.buttonA, label: "A")
                    buttonView(.b, x: 110, y: 65, width: 28, height: 28, color: SNESControllerColors.buttonB, label: "B")
                    buttonView(.y, x: 82, y: 40, width: 28, height: 28, color: SNESControllerColors.buttonY, label: "Y")

                    // Start / Select
                    buttonView(.select, x: -25, y: 60, width: 32, height: 12, color: SNESControllerColors.startSelect, label: "Sel", isOval: true)
                    buttonView(.start, x: 25, y: 60, width: 32, height: 12, color: SNESControllerColors.startSelect, label: "Sta", isOval: true)
                }

                Spacer()
            }
        }
    }

    private func buttonView(_ button: SNESButton, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: Color, label: String, isOval: Bool = false) -> some View {
        Button {
            selectedButton = button
        } label: {
            ZStack {
                if isOval {
                    Capsule()
                        .fill(color)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                } else {
                    Circle()
                        .fill(color)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }

                Text(label)
                    .font(.system(size: width < 20 ? 7 : 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: width, height: height)
            .overlay(
                Group {
                    if selectedButton == button {
                        if isOval {
                            Capsule().stroke(Color.white, lineWidth: 2)
                        } else {
                            Circle().stroke(Color.white, lineWidth: 2)
                        }
                    }
                }
            )
            // Show indicator if action assigned
            .overlay(alignment: .topTrailing) {
                if !mapping[button].asmRoutine.isEmpty {
                    Circle()
                        .fill(SNESTheme.success)
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .offset(x: x, y: y)
    }

    private var dpadView: some View {
        ZStack {
            DPadShape()
                .fill(SNESControllerColors.dpad)
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

            // Clickable areas
            dpadButton(.up, x: 0, y: -18)
            dpadButton(.down, x: 0, y: 18)
            dpadButton(.left, x: -18, y: 0)
            dpadButton(.right, x: 18, y: 0)
        }
    }

    private func dpadButton(_ button: SNESButton, x: CGFloat, y: CGFloat) -> some View {
        Button {
            selectedButton = button
        } label: {
            Circle()
                .fill(selectedButton == button ? Color.white.opacity(0.2) : Color.clear)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .offset(x: x, y: y)
    }

    // MARK: - Action Editor

    private var actionEditor: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ACTION")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(SNESTheme.bgPanel)
            .overlay(alignment: .bottom) {
                SNESTheme.border.frame(height: 1)
            }

            if let button = selectedButton {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Button: \(button.label)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SNESTheme.textPrimary)

                    Text("Bit mask: \(button.bitMask)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SNESTheme.textDisabled)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Label")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textDisabled)
                        TextField("ex: Jump", text: Binding(
                            get: { mapping[button].label },
                            set: { mapping[button].label = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ASM Routine")
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textDisabled)
                        TextField("ex: PlayerJump", text: Binding(
                            get: { mapping[button].asmRoutine },
                            set: { mapping[button].asmRoutine = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    }
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 24))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Text("Select a button")
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Spacer()
                }
            }

            Spacer()
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Code preview

    private var codePreview: some View {
        ScrollView {
            Text(mapping.generateASM())
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(SNESTheme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(SNESTheme.bgConsole)
    }

    // MARK: - Generate

    private func generateInputASM() {
        guard let project = state.projectManager.currentProject,
              let srcDir = project.sourceDirectoryURL else {
            state.appendConsole("Aucun projet ouvert", type: .error)
            return
        }

        let code = mapping.generateASM()
        let fileURL = srcDir.appendingPathComponent("input.asm")
        do {
            try code.write(to: fileURL, atomically: true, encoding: .utf8)
            state.appendConsole("input.asm genere (\(code.count) octets)", type: .success)
        } catch {
            state.appendConsole("Erreur: \(error.localizedDescription)", type: .error)
        }
    }
}
