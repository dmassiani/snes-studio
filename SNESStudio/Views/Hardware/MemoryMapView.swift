import SwiftUI

struct MemoryMapView: View {
    @Bindable var state: AppState
    @State private var selectedMapping: ROMMapping = .loROM

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Carte Memoire SNES")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SNESTheme.textPrimary)
                Spacer()
                Picker("Mapping", selection: $selectedMapping) {
                    ForEach(ROMMapping.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(SNESTheme.bgPanel)

            Divider()

            // Memory map diagram
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(regions, id: \.label) { region in
                        memoryRegion(region)
                    }
                }
                .padding(16)
            }
        }
        .background(SNESTheme.bgEditor)
        .onAppear {
            if let project = state.projectManager.currentProject {
                selectedMapping = project.cartridge.mapping
            }
        }
    }

    private struct MemoryRegion: Equatable {
        let startAddress: String
        let endAddress: String
        let label: String
        let detail: String
        let sizeKB: Int
        let color: Color
        let heightFactor: CGFloat
    }

    private var regions: [MemoryRegion] {
        switch selectedMapping {
        case .loROM:
            return loROMRegions
        case .hiROM:
            return hiROMRegions
        case .exHiROM:
            return exHiROMRegions
        case .sa1:
            return sa1Regions
        }
    }

    private var loROMRegions: [MemoryRegion] {
        [
            MemoryRegion(startAddress: "$0000", endAddress: "$1FFF",
                         label: "Scratch RAM", detail: "8 KB WRAM (miroir)", sizeKB: 8,
                         color: Color(hex: "4AFF9B"), heightFactor: 0.4),
            MemoryRegion(startAddress: "$2100", endAddress: "$21FF",
                         label: "PPU Registers", detail: "I/O Registres PPU", sizeKB: 0,
                         color: Color(hex: "FF8A4A"), heightFactor: 0.3),
            MemoryRegion(startAddress: "$4200", endAddress: "$44FF",
                         label: "CPU / DMA", detail: "CPU I/O, DMA, controleurs", sizeKB: 0,
                         color: Color(hex: "FFD04A"), heightFactor: 0.3),
            MemoryRegion(startAddress: "$7E0000", endAddress: "$7FFFFF",
                         label: "WRAM", detail: "128 KB Work RAM", sizeKB: 128,
                         color: Color(hex: "4AFF9B"), heightFactor: 1.0),
            MemoryRegion(startAddress: "$008000", endAddress: "$3FFFFF",
                         label: "ROM (Low)", detail: "LoROM banks $00-$7D (32KB par bank)", sizeKB: 2048,
                         color: Color(hex: "4A9EFF"), heightFactor: 1.2),
            MemoryRegion(startAddress: "$700000", endAddress: "$7DFFFF",
                         label: "SRAM", detail: "Sauvegarde cartouche", sizeKB: 32,
                         color: Color(hex: "9B6DFF"), heightFactor: 0.5),
        ]
    }

    private var hiROMRegions: [MemoryRegion] {
        [
            MemoryRegion(startAddress: "$0000", endAddress: "$1FFF",
                         label: "Scratch RAM", detail: "8 KB WRAM (miroir)", sizeKB: 8,
                         color: Color(hex: "4AFF9B"), heightFactor: 0.4),
            MemoryRegion(startAddress: "$2100", endAddress: "$21FF",
                         label: "PPU Registers", detail: "I/O Registres PPU", sizeKB: 0,
                         color: Color(hex: "FF8A4A"), heightFactor: 0.3),
            MemoryRegion(startAddress: "$4200", endAddress: "$44FF",
                         label: "CPU / DMA", detail: "CPU I/O, DMA, controleurs", sizeKB: 0,
                         color: Color(hex: "FFD04A"), heightFactor: 0.3),
            MemoryRegion(startAddress: "$7E0000", endAddress: "$7FFFFF",
                         label: "WRAM", detail: "128 KB Work RAM", sizeKB: 128,
                         color: Color(hex: "4AFF9B"), heightFactor: 1.0),
            MemoryRegion(startAddress: "$C00000", endAddress: "$FFFFFF",
                         label: "ROM (High)", detail: "HiROM banks $C0-$FF (64KB par bank)", sizeKB: 4096,
                         color: Color(hex: "4A9EFF"), heightFactor: 1.2),
            MemoryRegion(startAddress: "$206000", endAddress: "$3FFFFF",
                         label: "SRAM", detail: "Sauvegarde cartouche", sizeKB: 32,
                         color: Color(hex: "9B6DFF"), heightFactor: 0.5),
        ]
    }

    private var exHiROMRegions: [MemoryRegion] {
        [
            MemoryRegion(startAddress: "$0000", endAddress: "$1FFF",
                         label: "Scratch RAM", detail: "8 KB WRAM", sizeKB: 8,
                         color: Color(hex: "4AFF9B"), heightFactor: 0.4),
            MemoryRegion(startAddress: "$2100", endAddress: "$21FF",
                         label: "PPU Registers", detail: "I/O Registres PPU", sizeKB: 0,
                         color: Color(hex: "FF8A4A"), heightFactor: 0.3),
            MemoryRegion(startAddress: "$7E0000", endAddress: "$7FFFFF",
                         label: "WRAM", detail: "128 KB Work RAM", sizeKB: 128,
                         color: Color(hex: "4AFF9B"), heightFactor: 1.0),
            MemoryRegion(startAddress: "$C00000", endAddress: "$FFFFFF",
                         label: "ROM (High)", detail: "ExHiROM banks — jusqu'a 8 Mo", sizeKB: 8192,
                         color: Color(hex: "4A9EFF"), heightFactor: 1.5),
            MemoryRegion(startAddress: "$206000", endAddress: "$3FFFFF",
                         label: "SRAM", detail: "Sauvegarde cartouche", sizeKB: 32,
                         color: Color(hex: "9B6DFF"), heightFactor: 0.5),
        ]
    }

    private var sa1Regions: [MemoryRegion] {
        [
            MemoryRegion(startAddress: "$0000", endAddress: "$1FFF",
                         label: "Scratch RAM", detail: "8 KB WRAM", sizeKB: 8,
                         color: Color(hex: "4AFF9B"), heightFactor: 0.4),
            MemoryRegion(startAddress: "$2200", endAddress: "$23FF",
                         label: "SA-1 Registers", detail: "SA-1 I/O", sizeKB: 0,
                         color: Color(hex: "FF4A6A"), heightFactor: 0.3),
            MemoryRegion(startAddress: "$3000", endAddress: "$37FF",
                         label: "I-RAM", detail: "2 KB SA-1 Internal RAM", sizeKB: 2,
                         color: Color(hex: "FF8A4A"), heightFactor: 0.4),
            MemoryRegion(startAddress: "$400000", endAddress: "$5FFFFF",
                         label: "BW-RAM", detail: "256 KB SA-1 Bitmap RAM", sizeKB: 256,
                         color: Color(hex: "FFD04A"), heightFactor: 0.8),
            MemoryRegion(startAddress: "$C00000", endAddress: "$FFFFFF",
                         label: "ROM", detail: "SA-1 ROM banks (64KB)", sizeKB: 4096,
                         color: Color(hex: "4A9EFF"), heightFactor: 1.2),
            MemoryRegion(startAddress: "$7E0000", endAddress: "$7FFFFF",
                         label: "WRAM", detail: "128 KB Work RAM", sizeKB: 128,
                         color: Color(hex: "4AFF9B"), heightFactor: 1.0),
        ]
    }

    // MARK: - Memory Region View

    private func memoryRegion(_ region: MemoryRegion) -> some View {
        HStack(spacing: 0) {
            // Address column
            VStack(alignment: .trailing, spacing: 0) {
                Text(region.startAddress)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
                Spacer()
                Text(region.endAddress)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            .frame(width: 70)
            .padding(.trailing, 8)

            // Color bar
            RoundedRectangle(cornerRadius: 4)
                .fill(region.color.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(region.color.opacity(0.5), lineWidth: 1)
                )
                .overlay {
                    VStack(spacing: 2) {
                        Text(region.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(region.color)
                        Text(region.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(SNESTheme.textSecondary)
                        if region.sizeKB > 0 {
                            Text(region.sizeKB >= 1024 ? "\(region.sizeKB / 1024) MB" : "\(region.sizeKB) KB")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(SNESTheme.textDisabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: max(44, 44 * region.heightFactor))
        }
        .padding(.bottom, 2)
    }
}
