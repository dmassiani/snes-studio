import SwiftUI

struct ZoneListView: View {
    @Binding var zones: [WorldZone]
    @Binding var selectedZoneID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Zones")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SNESTheme.textSecondary)
                Spacer()
                Button(action: addZone) {
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

            // Zone list
            List(selection: $selectedZoneID) {
                ForEach(zones) { zone in
                    zoneRow(zone)
                        .tag(zone.id)
                }
                .onDelete(perform: deleteZones)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(SNESTheme.bgPanel)
    }

    private func zoneRow(_ zone: WorldZone) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: zone.colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(zone.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SNESTheme.textPrimary)
                Text("\(zone.type.rawValue) - Mode \(zone.bgMode) - \(zone.gridWidth)x\(zone.gridHeight)")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textDisabled)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func addZone() {
        let zoneNumber = zones.count + 1
        let colors = ["9B6DFF", "4A9EFF", "FF8A4A", "4AFF9B", "FF4A6A", "FFD04A"]
        var zone = WorldZone.empty()
        zone.name = "Zone \(zoneNumber)"
        zone.colorHex = colors[zones.count % colors.count]
        zones.append(zone)
        selectedZoneID = zone.id
    }

    private func deleteZones(at offsets: IndexSet) {
        zones.remove(atOffsets: offsets)
        if let selectedID = selectedZoneID, !zones.contains(where: { $0.id == selectedID }) {
            selectedZoneID = zones.first?.id
        }
    }
}
