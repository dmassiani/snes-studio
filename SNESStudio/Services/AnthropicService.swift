import Foundation

enum AnthropicError: LocalizedError {
    case noAPIKey
    case networkError(Error)
    case httpError(Int, String)
    case streamingError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Anthropic API key missing (ANTHROPIC_API_KEY)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .streamingError(let message):
            return "Streaming: \(message)"
        }
    }
}

// MARK: - Streaming result

enum StreamContentBlock {
    case text(String)
    case toolUse(id: String, name: String, input: [String: Any])
}

struct StreamResult {
    var textContent: String = ""
    var toolCalls: [StreamContentBlock] = []
    var stopReason: String = ""
}

final class AnthropicService: Sendable {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-5-20250929"

    var apiKey: String? {
        if let keychainKey = KeychainHelper.read(key: "anthropic_api_key"), !keychainKey.isEmpty {
            return keychainKey
        }
        return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
    }

    var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    // MARK: - API Message types

    struct APIMessage: Encodable {
        let role: String
        let content: String
    }

    struct APIMessageRich {
        let role: String
        let content: [[String: Any]]
    }

    // MARK: - Stream with tool support

    func streamMessage(
        system: String,
        messages: [APIMessageRich],
        tools: [[String: Any]]? = nil,
        maxTokens: Int = 4096,
        onDelta: @MainActor @Sendable @escaping (String) -> Void,
        onComplete: @MainActor @Sendable @escaping (StreamResult) -> Void,
        onError: @MainActor @Sendable @escaping (AnthropicError) -> Void
    ) -> Task<Void, Never> {
        Task {
            guard let key = apiKey, !key.isEmpty else {
                await MainActor.run { onError(.noAPIKey) }
                return
            }

            var request = URLRequest(url: Self.endpoint)
            request.httpMethod = "POST"
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "content-type")

            var body: [String: Any] = [
                "model": Self.model,
                "max_tokens": maxTokens,
                "stream": true,
                "system": system,
                "messages": messages.map { ["role": $0.role, "content": $0.content] },
            ]

            if let tools, !tools.isEmpty {
                body["tools"] = tools
            }

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                await MainActor.run { onError(.networkError(error)) }
                return
            }

            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode != 200 {
                    var errorBody = ""
                    for try await line in bytes.lines {
                        errorBody += line
                        if errorBody.count > 2000 { break }
                    }
                    // Try to extract a readable message from the API JSON error
                    let readableMessage = Self.parseAPIError(errorBody) ?? errorBody
                    let statusCode = httpResponse.statusCode
                    await MainActor.run {
                        onError(.httpError(statusCode, readableMessage))
                    }
                    return
                }

                var result = StreamResult()
                // Track current content block for tool_use
                var currentBlockType: String?
                var currentToolID: String?
                var currentToolName: String?
                var currentToolInputJSON = ""

                for try await line in bytes.lines {
                    if Task.isCancelled { break }

                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))

                    if jsonString == "[DONE]" { break }

                    guard let data = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let type = json["type"] as? String else { continue }

                    switch type {
                    case "content_block_start":
                        if let contentBlock = json["content_block"] as? [String: Any],
                           let blockType = contentBlock["type"] as? String {
                            currentBlockType = blockType
                            if blockType == "tool_use" {
                                currentToolID = contentBlock["id"] as? String ?? ""
                                currentToolName = contentBlock["name"] as? String ?? ""
                                currentToolInputJSON = ""
                            }
                        }

                    case "content_block_delta":
                        if let delta = json["delta"] as? [String: Any] {
                            let deltaType = delta["type"] as? String ?? ""
                            if deltaType == "text_delta", let text = delta["text"] as? String {
                                result.textContent += text
                                await MainActor.run { onDelta(text) }
                            } else if deltaType == "input_json_delta",
                                      let partial = delta["partial_json"] as? String {
                                currentToolInputJSON += partial
                            }
                        }

                    case "content_block_stop":
                        if currentBlockType == "tool_use",
                           let toolID = currentToolID,
                           let toolName = currentToolName {
                            var inputDict: [String: Any] = [:]
                            if let inputData = currentToolInputJSON.data(using: .utf8),
                               let parsed = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] {
                                inputDict = parsed
                            }
                            result.toolCalls.append(.toolUse(id: toolID, name: toolName, input: inputDict))
                        }
                        currentBlockType = nil
                        currentToolID = nil
                        currentToolName = nil
                        currentToolInputJSON = ""

                    case "message_delta":
                        if let delta = json["delta"] as? [String: Any],
                           let stopReason = delta["stop_reason"] as? String {
                            result.stopReason = stopReason
                        }

                    default:
                        break
                    }
                }

                if !Task.isCancelled {
                    await MainActor.run { onComplete(result) }
                }
            } catch is CancellationError {
                // Cancelled — no action needed
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { onError(.networkError(error)) }
                }
            }
        }
    }

    // MARK: - Error parsing

    private static func parseAPIError(_ body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else { return nil }
        let type = error["type"] as? String ?? "unknown"
        let message = error["message"] as? String ?? body
        return "[\(type)] \(message)"
    }

    // MARK: - Simple stream (backward compat)

    func streamMessage(
        system: String,
        messages: [APIMessage],
        maxTokens: Int = 4096,
        onDelta: @MainActor @Sendable @escaping (String) -> Void,
        onComplete: @MainActor @Sendable @escaping () -> Void,
        onError: @MainActor @Sendable @escaping (AnthropicError) -> Void
    ) -> Task<Void, Never> {
        let richMessages = messages.map {
            APIMessageRich(role: $0.role, content: [["type": "text", "text": $0.content]])
        }
        return streamMessage(
            system: system,
            messages: richMessages,
            tools: nil,
            maxTokens: maxTokens,
            onDelta: onDelta,
            onComplete: { _ in onComplete() },
            onError: onError
        )
    }
}
