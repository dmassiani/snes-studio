import SwiftUI

struct ConsoleView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("CONSOLE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(SNESTheme.textSecondary)

                Spacer()

                Button {
                    Task { await state.buildProject() }
                } label: {
                    Text("Build")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(SNESTheme.bgEditor))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await state.buildProject() }
                } label: {
                    Text("Build & Run")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SNESTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(SNESTheme.bgEditor))
                }
                .buttonStyle(.plain)

                Button {
                    state.clearConsole()
                } label: {
                    Text("Clear")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SNESTheme.textDisabled)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(SNESTheme.bgEditor))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(SNESTheme.bgPanel)
            .overlay(alignment: .bottom) {
                SNESTheme.border.frame(height: 1)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(state.consoleMessages) { msg in
                            HStack(alignment: .top, spacing: 8) {
                                Text(msg.formattedTimestamp)
                                    .foregroundStyle(SNESTheme.textDisabled)

                                Text(msg.type.prefix)
                                    .foregroundStyle(msg.type.color)
                                    .frame(width: 36, alignment: .leading)

                                if let ref = msg.fileRef {
                                    Text(msg.text)
                                        .foregroundStyle(msg.type.color)
                                        .underline()
                                        .onTapGesture {
                                            state.openFileAtLine(file: ref.file, line: ref.line)
                                        }
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                } else {
                                    Text(msg.text)
                                        .foregroundStyle(msg.type.color)
                                }

                                Spacer()
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .id(msg.id)
                        }
                    }
                    .textSelection(.enabled)
                }
                .onChange(of: state.consoleMessages.count) {
                    if let last = state.consoleMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .background(SNESTheme.bgConsole)
        }
    }
}
