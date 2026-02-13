import SwiftUI

struct ChatView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            if state.chatManager.messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            SNESTheme.border.frame(height: 1)

            // Input bar
            inputBar
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundStyle(SNESTheme.textDisabled)

            Text("SNES Assistant")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SNESTheme.textSecondary)

            Text("Ask about the 65816,\nPPU registers, ca65/ld65...\nThe AI can also modify your assets!")
                .font(.system(size: 11))
                .foregroundStyle(SNESTheme.textDisabled)
                .multilineTextAlignment(.center)

            if !state.chatManager.isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("ANTHROPIC_API_KEY not set")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(SNESTheme.warning)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(SNESTheme.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(state.chatManager.messages.filter { $0.role != .toolResult }) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: state.chatManager.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: state.chatManager.messages.last?.content.count) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastVisible = state.chatManager.messages.last(where: { $0.role != .toolResult }) {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(lastVisible.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 6) {
            TextField("Message...", text: $state.chatManager.inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(SNESTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(SNESTheme.bgEditor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit {
                    if !state.chatManager.isStreaming {
                        sendWithTools()
                    }
                }

            Button {
                if state.chatManager.isStreaming {
                    state.chatManager.cancelStream()
                } else {
                    sendWithTools()
                }
            } label: {
                Image(systemName: state.chatManager.isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        state.chatManager.isStreaming
                            ? SNESTheme.danger
                            : (state.chatManager.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? SNESTheme.textDisabled
                                : SNESTheme.info)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!state.chatManager.isStreaming && state.chatManager.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(8)
        .background(SNESTheme.bgPanel)
    }

    // MARK: - Send with tool support

    private func sendWithTools() {
        state.chatManager.sendMessage(context: buildContext(), appState: state)
    }

    // MARK: - Build enriched context

    private func buildContext() -> ChatContext {
        var ctx = ChatContext()
        ctx.cartridgeConfig = state.projectManager.currentProject?.cartridge

        // Determine active editor from active tab
        if let tab = state.tabManager.activeTab {
            ctx.activeEditor = activeEditorFromTab(tab)

            switch ctx.activeEditor {
            case .code:
                ctx.activeFileName = tab.title
                if let project = state.projectManager.currentProject,
                   let srcDir = project.sourceDirectoryURL {
                    let fileURL = srcDir.appendingPathComponent(tab.title)
                    ctx.activeFileContent = try? String(contentsOf: fileURL, encoding: .utf8)
                }

            case .palette:
                let palettes = state.assetStore.palettes
                var summary = "\(palettes.count) palettes. "
                if let first = palettes.first {
                    let colors = first.colors.prefix(4).map { "R\($0.red)G\($0.green)B\($0.blue)" }
                    summary += "Palette 0 (\(first.name)): [\(colors.joined(separator: ", ")), ...]"
                }
                ctx.editorSummary = summary

            case .tile:
                let tiles = state.assetStore.tiles
                ctx.editorSummary = "\(tiles.count) tiles (8x8, \(tiles.first?.depth.label ?? "4bpp"))"

            case .tilemap:
                if let tm = state.assetStore.tilemaps.first {
                    ctx.editorSummary = "Tilemap '\(tm.name)' \(tm.width)x\(tm.height) tiles, \(state.assetStore.tiles.count) tiles available"
                }

            case .sprite:
                let totalAnims = state.assetStore.metaSprites.reduce(0) { $0 + $1.animations.count }
                ctx.editorSummary = "\(state.assetStore.metaSprites.count) sprites, \(totalAnims) animations, \(state.assetStore.spriteEntries.count)/128 OAM"

            case .controller:
                let assigned = SNESButton.allCases.filter { !state.assetStore.controllerMapping[$0].asmRoutine.isEmpty }
                ctx.editorSummary = "\(assigned.count)/12 buttons assigned: \(assigned.map { $0.label }.joined(separator: ", "))"

            case .world:
                ctx.editorSummary = "\(state.assetStore.worldZones.count) zones, \(state.assetStore.worldScreens.count) screens, \(state.assetStore.worldTransitions.count) transitions"

            default:
                break
            }
        }

        let errors = state.consoleMessages
            .filter { $0.type == .error }
            .suffix(10)
            .map { $0.text }
        if !errors.isEmpty {
            ctx.lastBuildErrors = Array(errors)
        }

        return ctx
    }

    private func activeEditorFromTab(_ tab: EditorTab) -> ActiveEditor {
        // Code files have file extensions
        if tab.id.hasSuffix(".asm") || tab.id.hasSuffix(".inc") || tab.id.hasSuffix(".cfg") || tab.id.hasSuffix(".s") {
            return .code
        }
        // Visual editors match by sidebar item id
        return ActiveEditor(rawValue: tab.id) ?? .none
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 30) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .system {
                    // Error messages: icon + scrollable text
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(SNESTheme.danger)

                        Text(message.content)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SNESTheme.textPrimary)
                            .textSelection(.enabled)
                            .lineSpacing(2)
                    }
                    .frame(maxHeight: 120)
                } else {
                    Text(message.content.isEmpty && message.toolCalls.isEmpty ? " " : message.content)
                        .font(.system(size: 12))
                        .foregroundStyle(SNESTheme.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(2)
                }

                // Tool calls display
                if !message.toolCalls.isEmpty {
                    ForEach(message.toolCalls) { tc in
                        toolCallBadge(tc)
                    }
                }

                Text(message.formattedTimestamp)
                    .font(.system(size: 9))
                    .foregroundStyle(SNESTheme.textDisabled)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if message.role != .user { Spacer(minLength: 30) }
        }
    }

    private func toolCallBadge(_ tc: ToolCall) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tc.isSuccess ? "wrench.and.screwdriver" : "exclamationmark.triangle")
                .font(.system(size: 9))
                .foregroundStyle(tc.isSuccess ? SNESTheme.success : SNESTheme.danger)

            Text(tc.name)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(SNESTheme.textSecondary)

            if let result = tc.result {
                Text("— \(result.prefix(60))")
                    .font(.system(size: 9))
                    .foregroundStyle(SNESTheme.textDisabled)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((tc.isSuccess ? SNESTheme.success : SNESTheme.danger).opacity(0.1))
        )
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user:
            return SNESTheme.info.opacity(0.15)
        case .assistant:
            return SNESTheme.bgPanel
        case .system:
            return SNESTheme.danger.opacity(0.15)
        case .toolResult:
            return SNESTheme.bgPanel
        }
    }
}
