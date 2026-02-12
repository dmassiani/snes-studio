import SwiftUI

struct RegistersView: View {
    @State private var searchText = ""
    @State private var selectedCategory: RegisterCategory?
    @State private var selectedRegister: SNESRegister?

    private var filteredRegisters: [SNESRegister] {
        SNESRegister.allRegisters.filter { reg in
            let matchesCategory = selectedCategory == nil || reg.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                reg.name.localizedCaseInsensitiveContains(searchText) ||
                reg.fullName.localizedCaseInsensitiveContains(searchText) ||
                reg.description.localizedCaseInsensitiveContains(searchText) ||
                reg.id.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        HSplitView {
            // Register list
            VStack(spacing: 0) {
                toolbar
                Divider()
                registerList
            }
            .frame(minWidth: 380)

            // Detail panel
            detailPanel
                .frame(minWidth: 280, idealWidth: 320)
        }
        .background(SNESTheme.bgEditor)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SNESTheme.textDisabled)
            TextField("Rechercher...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            Picker("", selection: $selectedCategory) {
                Text("Tous").tag(RegisterCategory?.none)
                ForEach(RegisterCategory.allCases) { cat in
                    Text(cat.rawValue).tag(RegisterCategory?.some(cat))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Text("\(filteredRegisters.count) registres")
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textDisabled)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Register List

    private var registerList: some View {
        List(filteredRegisters, selection: $selectedRegister) { reg in
            registerRow(reg)
                .tag(reg)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func registerRow(_ reg: SNESRegister) -> some View {
        HStack(spacing: 8) {
            Text(reg.id)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(PyramidLevel.hardware.accent)
                .frame(width: 56, alignment: .leading)

            Text(reg.name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(SNESTheme.textPrimary)
                .frame(width: 100, alignment: .leading)

            Text(reg.fullName)
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            accessBadge(reg.access)
        }
        .padding(.vertical, 2)
    }

    private func accessBadge(_ access: RegisterAccess) -> some View {
        Text(access.rawValue)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(accessColor(access))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(accessColor(access).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func accessColor(_ access: RegisterAccess) -> Color {
        switch access {
        case .writeOnly: return SNESTheme.warning
        case .readOnly:  return SNESTheme.info
        case .readWrite: return SNESTheme.success
        }
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if let reg = selectedRegister {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(reg.id)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundStyle(PyramidLevel.hardware.accent)
                                accessBadge(reg.access)
                            }
                            Text(reg.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(SNESTheme.textPrimary)
                            Text(reg.fullName)
                                .font(.system(size: 12))
                                .foregroundStyle(SNESTheme.textSecondary)
                        }

                        Divider()

                        // Description
                        Text(reg.description)
                            .font(.system(size: 12))
                            .foregroundStyle(SNESTheme.textPrimary)

                        // Bit fields
                        if let bits = reg.bits, !bits.isEmpty {
                            Divider()
                            Text("Bit Fields")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SNESTheme.textSecondary)

                            ForEach(bits, id: \.position) { field in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("[\(field.position)]")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(SNESTheme.info)
                                        .frame(width: 40, alignment: .trailing)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(field.name)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(SNESTheme.textPrimary)
                                        Text(field.description)
                                            .font(.system(size: 11))
                                            .foregroundStyle(SNESTheme.textSecondary)
                                    }
                                }
                            }
                        }

                        // Category
                        Divider()
                        HStack {
                            Text("Categorie")
                                .font(.system(size: 11))
                                .foregroundStyle(SNESTheme.textDisabled)
                            Spacer()
                            Text(reg.category.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(SNESTheme.textSecondary)
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(SNESTheme.textDisabled)
                    Text("Selectionnez un registre")
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.textDisabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(SNESTheme.bgPanel)
    }
}
