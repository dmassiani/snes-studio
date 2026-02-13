import Foundation

@Observable
final class ChatManager {
    var messages: [ChatMessage] = []
    var isStreaming: Bool = false
    var inputText: String = ""

    private let service = AnthropicService()
    private var activeTask: Task<Void, Never>?

    var isConfigured: Bool { service.isConfigured }

    private static let maxToolLoops = 5

    // MARK: - Send message with tool support

    @MainActor
    func sendMessage(context: ChatContext, appState: AppState) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        isStreaming = true

        let systemPrompt = buildSystemPrompt(context: context)
        let tools = AITools.tools(for: context.activeEditor)
        let executor = AIToolExecutor(appState: appState)

        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.runToolLoop(systemPrompt: systemPrompt, tools: tools, executor: executor, appState: appState, loopsRemaining: Self.maxToolLoops)
        }
    }

    @MainActor
    private func runToolLoop(systemPrompt: String, tools: [[String: Any]], executor: AIToolExecutor, appState: AppState?, loopsRemaining: Int) async {
        // Build API messages from conversation history
        let apiMessages = buildAPIMessages()

        // Append empty assistant placeholder for streaming
        messages.append(ChatMessage(role: .assistant, content: ""))
        let assistantIdx = messages.count - 1

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            activeTask = service.streamMessage(
                system: systemPrompt,
                messages: apiMessages,
                tools: tools.isEmpty ? nil : tools,
                onDelta: { [weak self] delta in
                    guard let self, assistantIdx < self.messages.count else { return }
                    self.messages[assistantIdx].content += delta
                },
                onComplete: { [weak self] result in
                    guard let self else {
                        continuation.resume()
                        return
                    }

                    // Extract tool calls from result
                    var toolCallModels: [ToolCall] = []
                    for block in result.toolCalls {
                        if case .toolUse(let id, let name, let input) = block {
                            toolCallModels.append(ToolCall(id: id, name: name, input: input))
                        }
                    }

                    if !toolCallModels.isEmpty, assistantIdx < self.messages.count {
                        self.messages[assistantIdx].toolCalls = toolCallModels
                    }

                    // If stop_reason is tool_use, execute tools and loop
                    if result.stopReason == "tool_use" && loopsRemaining > 0 && !toolCallModels.isEmpty {
                        // Execute each tool call
                        var toolResults: [(String, String, Bool)] = [] // (id, content, isError)
                        for tc in toolCallModels {
                            let toolResult = executor.execute(name: tc.name, id: tc.id, input: tc.input)
                            toolResults.append((toolResult.toolID, toolResult.content, toolResult.isError))
                            // Update the tool call with its result
                            if assistantIdx < self.messages.count,
                               let idx = self.messages[assistantIdx].toolCalls.firstIndex(where: { $0.id == tc.id }) {
                                self.messages[assistantIdx].toolCalls[idx].result = toolResult.content
                                self.messages[assistantIdx].toolCalls[idx].isSuccess = !toolResult.isError
                            }
                        }

                        // Add tool_result messages (invisible in UI but sent to API)
                        for (toolID, content, isError) in toolResults {
                            self.messages.append(ChatMessage(
                                role: .toolResult,
                                content: content,
                                toolCalls: [ToolCall(id: toolID, name: "", input: [:], result: content, isSuccess: !isError)]
                            ))
                        }

                        continuation.resume()

                        // Continue the loop
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            await self.runToolLoop(systemPrompt: systemPrompt, tools: tools, executor: executor, appState: appState, loopsRemaining: loopsRemaining - 1)
                        }
                        return
                    }

                    // Done — no more tool calls
                    self.isStreaming = false
                    self.activeTask = nil
                    continuation.resume()
                },
                onError: { [weak self] error in
                    guard let self else {
                        continuation.resume()
                        return
                    }
                    self.isStreaming = false
                    self.activeTask = nil

                    // Remove the empty assistant placeholder by index, not removeLast()
                    if assistantIdx < self.messages.count,
                       self.messages[assistantIdx].role == .assistant,
                       self.messages[assistantIdx].content.isEmpty,
                       self.messages[assistantIdx].toolCalls.isEmpty {
                        self.messages.remove(at: assistantIdx)
                    }

                    let errorText = error.localizedDescription
                    self.messages.append(ChatMessage(role: .system, content: errorText))

                    // Also log to console so user can always see it
                    appState?.appendConsole("IA: \(errorText)", type: .error)

                    continuation.resume()
                }
            )
        }
    }

    // MARK: - Build API messages

    @MainActor
    private func buildAPIMessages() -> [AnthropicService.APIMessageRich] {
        var apiMessages: [AnthropicService.APIMessageRich] = []

        for msg in messages {
            switch msg.role {
            case .user:
                guard !msg.content.isEmpty else { continue }
                apiMessages.append(AnthropicService.APIMessageRich(
                    role: "user",
                    content: [["type": "text", "text": msg.content]]
                ))

            case .assistant:
                guard !msg.content.isEmpty || !msg.toolCalls.isEmpty else { continue }
                var contentBlocks: [[String: Any]] = []
                if !msg.content.isEmpty {
                    contentBlocks.append(["type": "text", "text": msg.content])
                }
                for tc in msg.toolCalls {
                    contentBlocks.append([
                        "type": "tool_use",
                        "id": tc.id,
                        "name": tc.name,
                        "input": tc.input,
                    ])
                }
                apiMessages.append(AnthropicService.APIMessageRich(
                    role: "assistant",
                    content: contentBlocks
                ))

            case .toolResult:
                // Each tool result must be in a user message with role "user" and type "tool_result"
                for tc in msg.toolCalls {
                    apiMessages.append(AnthropicService.APIMessageRich(
                        role: "user",
                        content: [[
                            "type": "tool_result",
                            "tool_use_id": tc.id,
                            "content": tc.result ?? msg.content,
                            "is_error": !tc.isSuccess,
                        ] as [String: Any]]
                    ))
                }

            case .system:
                continue
            }
        }

        return apiMessages
    }

    // MARK: - Legacy send (no tools)

    @MainActor
    func sendMessage(context: ChatContext) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        messages.append(ChatMessage(role: .assistant, content: ""))
        isStreaming = true

        let apiMessages = messages
            .filter { $0.role != .system && $0.role != .toolResult && !$0.content.isEmpty }
            .map { AnthropicService.APIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        let systemPrompt = buildSystemPrompt(context: context)

        activeTask = service.streamMessage(
            system: systemPrompt,
            messages: apiMessages,
            onDelta: { [weak self] delta in
                guard let self, !self.messages.isEmpty else { return }
                self.messages[self.messages.count - 1].content += delta
            },
            onComplete: { [weak self] in
                self?.isStreaming = false
                self?.activeTask = nil
            },
            onError: { [weak self] error in
                guard let self else { return }
                self.isStreaming = false
                self.activeTask = nil
                if let last = self.messages.last, last.role == .assistant && last.content.isEmpty {
                    self.messages.removeLast()
                }
                self.messages.append(ChatMessage(role: .system, content: error.localizedDescription))
            }
        )
    }

    func cancelStream() {
        activeTask?.cancel()
        activeTask = nil
        isStreaming = false
    }

    func clearHistory() {
        cancelStream()
        messages.removeAll()
    }

    // MARK: - System prompt

    private func buildSystemPrompt(context: ChatContext) -> String {
        var parts: [String] = []

        parts.append("""
        You are an expert assistant in SNES (Super Nintendo) development. \
        You have deep knowledge of the 65816 processor (WDC 65C816), the ca65/ld65 assembler, \
        the PPU architecture (graphics modes 0-7), the SPC-700 (audio), DMA, \
        and all the subtleties of SNES hardware. \
        You answer concisely and technically. \
        When providing code, use ca65 syntax.
        """)

        // Tool use instructions
        if context.activeEditor != .none {
            parts.append("""
            You have access to tools to directly modify the project assets. \
            Use them when the user asks you to make visual modifications. \
            Do not ask for confirmation, execute the tools directly.
            """)
        }

        if let config = context.cartridgeConfig {
            parts.append("""
            Project cartridge: \(config.mapping.rawValue), \
            \(config.romSizeKB) KB ROM, \(config.sramSizeKB) KB SRAM, \
            \(config.speed.rawValue), chip: \(config.chip.rawValue)
            """)
        }

        // Active editor context
        if context.activeEditor != .none {
            parts.append("Active editor: \(context.activeEditor.rawValue)")
        }

        if let summary = context.editorSummary {
            parts.append("Editor context:\n\(summary)")
        }

        if let fileName = context.activeFileName {
            parts.append("Active file: \(fileName)")
        }

        if let content = context.activeFileContent {
            let truncated = content.count > 3000 ? String(content.prefix(3000)) + "\n... (truncated)" : content
            parts.append("File content:\n```asm\n\(truncated)\n```")
        }

        if let errors = context.lastBuildErrors, !errors.isEmpty {
            parts.append("Recent build errors:\n" + errors.joined(separator: "\n"))
        }

        return parts.joined(separator: "\n\n")
    }
}
