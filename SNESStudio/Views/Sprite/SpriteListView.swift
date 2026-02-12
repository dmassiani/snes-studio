import SwiftUI

struct SpriteListView: View {
    @Binding var entries: [OAMEntry]
    @Binding var selectedIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("OAM ENTRIES (\(entries.count)/128)")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(SNESTheme.textSecondary)

                Spacer()

                Button {
                    entries.append(OAMEntry())
                    selectedIndex = entries.count - 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(SNESTheme.textSecondary)
                }
                .buttonStyle(.plain)

                if let idx = selectedIndex, idx < entries.count {
                    Button {
                        entries.remove(at: idx)
                        selectedIndex = entries.isEmpty ? nil : min(idx, entries.count - 1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(SNESTheme.bgPanel)
            .overlay(alignment: .bottom) {
                SNESTheme.border.frame(height: 1)
            }

            // List
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(entries.indices, id: \.self) { idx in
                        spriteRow(index: idx)
                    }
                }
                .padding(6)
            }
            .background(SNESTheme.bgEditor)

            // Properties for selected entry
            if let idx = selectedIndex, idx >= 0, idx < entries.count {
                entryProperties(index: idx)
            }
        }
    }

    private func spriteRow(index: Int) -> some View {
        let entry = entries[index]
        return Button {
            selectedIndex = index
        } label: {
            HStack(spacing: 6) {
                Text("#\(index)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
                    .frame(width: 24)

                Text("\(entry.size.label)")
                    .font(.system(size: 10))
                    .foregroundStyle(SNESTheme.textSecondary)

                Text("(\(entry.x), \(entry.y))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)

                Spacer()

                Text("T\(entry.tileIndex)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(selectedIndex == index ? SNESTheme.info.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func entryProperties(index: Int) -> some View {
        VStack(spacing: 6) {
            SNESTheme.border.frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("X")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .frame(width: 14)
                    TextField("", value: $entries[index].x, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text("Y")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .frame(width: 14)
                    TextField("", value: $entries[index].y, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                }

                HStack {
                    Text("Tile")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textDisabled)
                    TextField("", value: $entries[index].tileIndex, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text("Pal")
                        .font(.system(size: 10))
                        .foregroundStyle(SNESTheme.textDisabled)
                    TextField("", value: $entries[index].paletteIndex, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 40)
                }

                HStack(spacing: 8) {
                    Picker("Size", selection: $entries[index].size) {
                        ForEach(SpriteSize.allCases, id: \.self) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .frame(width: 100)

                    Picker("Pri", selection: $entries[index].priority) {
                        ForEach(0..<4, id: \.self) { p in
                            Text("\(p)").tag(p)
                        }
                    }
                    .frame(width: 60)
                }

                HStack(spacing: 12) {
                    Toggle("FlipH", isOn: $entries[index].flipH)
                        .font(.system(size: 10))
                    Toggle("FlipV", isOn: $entries[index].flipV)
                        .font(.system(size: 10))
                }
                .foregroundStyle(SNESTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SNESTheme.bgPanel)
        }
    }
}
