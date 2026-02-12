import SwiftUI

struct LayerViewerView: View {
    @Bindable var state: AppState
    @State private var selectedMode: Int = 1
    @State private var showBG1 = true
    @State private var showBG2 = true
    @State private var showBG3 = true
    @State private var showBG4 = false
    @State private var showSprites = true

    private var modeInfo: BGModeInfo {
        BGModeInfo.allModes[selectedMode]
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            HSplitView {
                // Canvas area
                canvasArea
                    .frame(minWidth: 300)

                // Info panel
                infoPanel
                    .frame(width: 260)
            }
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Couches BG")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SNESTheme.textPrimary)

            Spacer()

            Picker("Mode", selection: $selectedMode) {
                ForEach(0..<8) { m in
                    Text("Mode \(m)").tag(m)
                }
            }
            .frame(width: 100)

            Divider().frame(height: 16)

            layerToggle("BG1", isOn: $showBG1, available: modeInfo.layers[0].depth != nil)
            layerToggle("BG2", isOn: $showBG2, available: modeInfo.layers[1].depth != nil)
            layerToggle("BG3", isOn: $showBG3, available: modeInfo.layers[2].depth != nil)
            layerToggle("BG4", isOn: $showBG4, available: modeInfo.layers[3].depth != nil)
            layerToggle("OBJ", isOn: $showSprites, available: true)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(SNESTheme.bgPanel)
    }

    private func layerToggle(_ label: String, isOn: Binding<Bool>, available: Bool) -> some View {
        Toggle(label, isOn: isOn)
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
            .foregroundStyle(available ? SNESTheme.textPrimary : SNESTheme.textDisabled)
            .disabled(!available)
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        VStack {
            Spacer()
            Canvas { context, size in
                let screenW: CGFloat = 256
                let screenH: CGFloat = 224
                let scale = min(size.width / screenW, size.height / screenH)
                let offsetX = (size.width - screenW * scale) / 2
                let offsetY = (size.height - screenH * scale) / 2

                // Background
                let screenRect = CGRect(x: offsetX, y: offsetY, width: screenW * scale, height: screenH * scale)
                context.fill(Path(screenRect), with: .color(Color.black))

                // Draw layer previews (simplified grid patterns)
                let activeLayers = getActiveLayers()
                for (index, layer) in activeLayers.enumerated() {
                    let opacity = 0.3 + Double(index) * 0.15
                    drawLayerGrid(context: context, in: screenRect, layer: layer, opacity: opacity)
                }

                // Screen border
                context.stroke(Path(screenRect), with: .color(SNESTheme.border), lineWidth: 1)

                // Label
                let labelPoint = CGPoint(x: offsetX + 4, y: offsetY + screenH * scale + 4)
                context.draw(
                    Text("256 x 224").font(.system(size: 10, design: .monospaced)).foregroundStyle(SNESTheme.textDisabled),
                    at: labelPoint, anchor: .topLeading
                )
            }
            .frame(minWidth: 280, minHeight: 260)
            Spacer()
        }
        .background(SNESTheme.bgEditor)
    }

    private func getActiveLayers() -> [BGLayerInfo] {
        var layers: [BGLayerInfo] = []
        let toggles = [showBG1, showBG2, showBG3, showBG4]
        for (i, layer) in modeInfo.layers.enumerated() {
            if layer.depth != nil && toggles[i] {
                layers.append(layer)
            }
        }
        return layers
    }

    private func drawLayerGrid(context: GraphicsContext, in rect: CGRect, layer: BGLayerInfo, opacity: Double) {
        let colors: [Color] = [
            Color(hex: "4A9EFF"),
            Color(hex: "9B6DFF"),
            Color(hex: "FF8A4A"),
            Color(hex: "FFD04A"),
        ]
        let color = colors[min(layer.layer, colors.count - 1)]

        // Draw a grid pattern representing the layer
        let tileScale = rect.width / 32.0  // 32 tiles across
        for row in 0..<28 {
            for col in 0..<32 {
                // Checkerboard pattern offset by layer
                if (row + col + layer.layer) % 3 == 0 {
                    let tileRect = CGRect(
                        x: rect.minX + CGFloat(col) * tileScale,
                        y: rect.minY + CGFloat(row) * tileScale,
                        width: tileScale,
                        height: tileScale
                    )
                    context.fill(Path(tileRect), with: .color(color.opacity(opacity)))
                }
            }
        }
    }

    // MARK: - Info Panel

    private var infoPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Mode description
                VStack(alignment: .leading, spacing: 4) {
                    Text(modeInfo.label)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PyramidLevel.hardware.accent)
                    Text(modeInfo.description)
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.textSecondary)
                }

                Divider()

                // Layer details
                Text("Couches disponibles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)

                ForEach(0..<4, id: \.self) { i in
                    let layer = modeInfo.layers[i]
                    HStack(spacing: 8) {
                        Circle()
                            .fill(layer.depth != nil ? Color(hex: ["4A9EFF", "9B6DFF", "FF8A4A", "FFD04A"][i]) : SNESTheme.textDisabled)
                            .frame(width: 8, height: 8)

                        Text("BG\(i + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(layer.depth != nil ? SNESTheme.textPrimary : SNESTheme.textDisabled)

                        Spacer()

                        if let depth = layer.depth {
                            Text(depth.label)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(SNESTheme.textSecondary)
                            Text("\(layer.maxColors) couleurs")
                                .font(.system(size: 11))
                                .foregroundStyle(SNESTheme.textDisabled)
                        } else {
                            Text("Inactive")
                                .font(.system(size: 11))
                                .foregroundStyle(SNESTheme.textDisabled)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Divider()

                // Mode-specific info
                if modeInfo.isMode7 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mode 7 Special")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SNESTheme.warning)
                        Text("Rotation/Scaling matrice 2D")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.textSecondary)
                        Text("1024 tiles 8x8, 256 couleurs")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.textSecondary)
                        Text("128x128 tilemap")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.textSecondary)
                    }
                }

                // Sprites info
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sprites (OBJ)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Text("128 sprites max, 4bpp")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Text("32 par scanline")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                    Text("8 palettes de 16 couleurs")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                }
            }
            .padding(16)
        }
        .background(SNESTheme.bgPanel)
    }
}
