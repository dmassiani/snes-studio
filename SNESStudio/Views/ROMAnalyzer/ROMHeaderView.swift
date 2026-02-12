import SwiftUI

struct ROMHeaderView: View {
    let header: ROMHeader
    let fileName: String
    let fileSize: Int
    let hasSMCHeader: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // File info
                sectionHeader("Fichier")
                infoRow("Nom", fileName)
                infoRow("Taille", formatFileSize(fileSize))
                infoRow("Header SMC", hasSMCHeader ? "Oui (512 octets)" : "Non")

                Divider().padding(.vertical, 8)

                // ROM Header
                sectionHeader("Header SNES")
                infoRow("Titre", header.title)
                infoRow("Mapping", header.mapping.rawValue)
                infoRow("Vitesse", header.speed.rawValue)
                infoRow("Chip Type", String(format: "$%02X", header.chipType))
                infoRow("ROM Size", "\(header.romSizeKB) KB")
                infoRow("RAM Size", "\(header.ramSizeKB) KB")
                infoRow("Pays", header.countryName)

                Divider().padding(.vertical, 8)

                // Checksum
                sectionHeader("Checksum")
                HStack(spacing: 8) {
                    Text("Checksum")
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .frame(width: 140, alignment: .trailing)
                    Text(String(format: "$%04X", header.checksum))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(header.checksumValid ? SNESTheme.success : SNESTheme.danger)
                    if header.checksumValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(SNESTheme.success)
                            .font(.system(size: 12))
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SNESTheme.danger)
                            .font(.system(size: 12))
                    }
                }
                .padding(.vertical, 2)

                infoRow("Complement", String(format: "$%04X", header.checksumComplement))

                Divider().padding(.vertical, 8)

                // Vectors
                sectionHeader("Vecteurs")
                infoRow("RESET", String(format: "$%04X", header.resetVector))
                infoRow("NMI (VBlank)", String(format: "$%04X", header.nmiVector))
                infoRow("IRQ", String(format: "$%04X", header.irqVector))
            }
            .padding(20)
        }
        .background(SNESTheme.bgEditor)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(PyramidLevel.hardware.accent)
            .padding(.bottom, 4)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(SNESTheme.textSecondary)
                .frame(width: 140, alignment: .trailing)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(SNESTheme.textPrimary)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes >= 1024 * 1024 {
            return String(format: "%.2f MB (%d octets)", Double(bytes) / (1024 * 1024), bytes)
        }
        return String(format: "%.1f KB (%d octets)", Double(bytes) / 1024, bytes)
    }
}
