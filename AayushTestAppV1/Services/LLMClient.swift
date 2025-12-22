//
//  LLMClient.swift
//  AayushTestAppV1
//
//

import Foundation

/// Client for interacting with Amazon Bedrock LLM API.
///
/// **Purpose**: Provides a clean, type-safe interface for LLM operations. Handles:
/// - API authentication and request formatting
/// - Response parsing and error handling
/// - Message sanitization and prompt echo stripping
/// - JSON schema enforcement for structured outputs
///
/// **Architecture**: Service layer pattern - pure data access with no business logic.
/// Used by actions like `HelloMessageAction`.
///
/// **API Compatibility**: Uses Bedrock's OpenAI-compatible Chat Completions endpoint,
/// making it compatible with standard OpenAI API patterns.
///
/// **Error Handling**: Converts HTTP errors and API failures into Swift errors with
/// descriptive messages. Handles malformed JSON responses gracefully.
///
/// **Security**: Requires API key (currently hardcoded - see README for security improvements).

// MARK: - Request / Response Models

struct LLMRequest: Encodable {
    let model: String
    let messages: [[String: String]]
}

struct LLMResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String?  // Optional to handle cases where content might be null (e.g., with response_format: json_object)
        }
        
        let message: Message
    }
    
    let choices: [Choice]
}

struct LLMMessagePayload: Decodable {
    let version: Int
    let message: String
    let debug: String?
}

// MARK: - Unified Message Type

/// Represents a message in the LLM conversation.
/// Provides type-safe conversion to API format.
enum LLMMessageRole: String {
    case system, user, assistant, tool
}

struct LLMMessage {
    let role: LLMMessageRole
    let content: String?
    let toolCallId: String?
    let toolCalls: [[String: Any]]?
    
    init(role: LLMMessageRole, content: String?, toolCallId: String? = nil, toolCalls: [[String: Any]]? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }
    
    /// Converts to simple API format (for basic requests)
    func toSimpleDict() -> [String: String]? {
        guard let content = content else { return nil }
        return ["role": role.rawValue, "content": content]
    }
    
    /// Converts to full API format (for tool-enabled requests)
    func toAPIDict() -> [String: Any] {
        var dict: [String: Any] = ["role": role.rawValue]
        
        if let content = content, !content.isEmpty {
            dict["content"] = content
        } else if toolCalls == nil {
            dict["content"] = NSNull()
        }
        
        if let toolCallId = toolCallId {
            dict["tool_call_id"] = toolCallId
        }
        
        if let toolCalls = toolCalls {
            dict["tool_calls"] = toolCalls
        }
        
        return dict
    }
}

// MARK: - Client

final class LLMClient {
    private let apiKey: String
    private let baseURL: URL
    private let model: String
    private let session: URLSession
    private let logger = LoggingService.shared

    enum ResponseFormatOption {
        case jsonObject
        case none

        var payload: [String: Any]? {
            switch self {
            case .jsonObject:
                return ["type": "json_object"]
            case .none:
                return nil
            }
        }
    }
    
    // AWS credentials for SigV4 signing (optional - if provided, will use SigV4 instead of Bearer token)
    private let awsAccessKey: String?
    private let awsSecretKey: String?
    private let awsRegion: String?
    
    /// - Parameters:
    ///   - apiKey: Your Amazon Bedrock bearer token (for OpenAI-compatible gateways) or can be empty if using AWS credentials
    ///   - baseURL: Bedrock OpenAI-compatible base URL, e.g.
    ///              https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1
    ///   - model: Bedrock model ID, e.g. "openai.gpt-oss-20b-1:0"
    ///   - awsAccessKey: AWS access key for SigV4 signing (optional)
    ///   - awsSecretKey: AWS secret key for SigV4 signing (optional)
    ///   - awsRegion: AWS region (e.g., "us-west-2") for SigV4 signing (optional)
    init(
        apiKey: String,
        baseURL: URL,
        model: String,
        session: URLSession = .shared,
        awsAccessKey: String? = nil,
        awsSecretKey: String? = nil,
        awsRegion: String? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.session = session
        self.awsAccessKey = awsAccessKey
        self.awsSecretKey = awsSecretKey
        self.awsRegion = awsRegion
    }
    
    // MARK: - Reusable Infrastructure Methods
    
    /// Builds a URLRequest for the chat completions endpoint.
    ///
    /// - Parameters:
    ///   - messages: Array of messages in simple format [[String: String]]
    ///   - tools: Optional tool definitions for function calling
    /// - Returns: Configured URLRequest ready for authentication
    /// - Throws: Encoding errors if request body cannot be created
    private func buildRequest(
        messages: [[String: String]],
        tools: [[String: Any]]? = nil
    ) throws -> URLRequest {
        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        
        if let tools = tools, !tools.isEmpty {
            requestBody["tools"] = tools
            requestBody["tool_choice"] = "auto"
        }
        
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode request body
        if tools == nil {
            // Simple case: use Encodable struct
            let body = LLMRequest(model: model, messages: messages)
            request.httpBody = try JSONEncoder().encode(body)
        } else {
            // Complex case: use JSONSerialization for tools
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        }
        
        return request
    }
    
    /// Builds a URLRequest for the chat completions endpoint with tool support.
    ///
    /// - Parameters:
    ///   - messages: Array of messages in full format [[String: Any]]
    ///   - tools: Optional tool definitions for function calling
    /// - Returns: Configured URLRequest ready for authentication
    /// - Throws: Encoding errors if request body cannot be created
    private func buildRequestWithTools(
        messages: [[String: Any]],
        tools: [[String: Any]]? = nil
    ) throws -> URLRequest {
        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        
        if let tools = tools, !tools.isEmpty {
            requestBody["tools"] = tools
            requestBody["tool_choice"] = "auto"
        }
        
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return request
    }

    /// Builds a raw URLRequest for chat completions with arbitrary body keys.
    private func buildRawRequest(body: [String: Any]) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Advanced text generation with optional temperature, max tokens, and response_format.
    /// Falls back to basic generation on HTTP 4xx errors that may indicate unsupported keys.
    func generateTextAdvanced(
        systemPrompt: String? = nil,
        userPrompt: String,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        responseFormat: ResponseFormatOption = .none
    ) async throws -> String {
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt { messages.append(["role": "system", "content": systemPrompt]) }
        messages.append(["role": "user", "content": userPrompt])

        var body: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        if let temperature = temperature { body["temperature"] = temperature }
        if let maxTokens = maxTokens { body["max_tokens"] = maxTokens }
        if let rf = responseFormat.payload { body["response_format"] = rf }

        do {
            var request = try buildRawRequest(body: body)
            try authenticateRequest(&request)
            let data = try await executeRequest(request)
            
            // Try to parse the response
            do {
                let decoded = try parseResponse(data)
                let raw = decoded.choices.first?.message.content ?? ""
                logger.debug("LLM response processed (advanced): messageLength=\(raw.count) chars", category: .llm)
                return raw
            } catch let parseError {
                // If parsing fails, try to extract content directly from JSON
                logger.warning("Failed to parse structured response, attempting manual extraction. Error=\(parseError.localizedDescription)", category: .llm)
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    logger.debug("Successfully extracted content from raw JSON: messageLength=\(content.count) chars", category: .llm)
                    return content
                }
                
                // If manual extraction also fails, rethrow the original parse error
                throw parseError
            }
        } catch {
            // If the provider rejects unsupported keys (e.g., response_format), retry without advanced options
            logger.warning("Advanced LLM request failed; retrying with basic generateText. Error=\(error.localizedDescription)", category: .llm)
            return try await generateText(systemPrompt: systemPrompt, userPrompt: userPrompt)
        }
    }
    
    /// Authenticates a URLRequest using either SigV4 signing or Bearer token.
    ///
    /// - Parameter request: The request to authenticate (modified in place)
    /// - Throws: `AppError.authenticationFailed` if no valid credentials are available
    private func authenticateRequest(_ request: inout URLRequest) throws {
        // Use SigV4 signing if AWS credentials are provided
        if let accessKey = awsAccessKey,
           let secretKey = awsSecretKey,
           let region = awsRegion {
            let signer = AWSSigV4Signer(accessKey: accessKey, secretKey: secretKey, region: region)
            request = try signer.sign(request)
        } else if !apiKey.isEmpty {
            // Fallback to Bearer token
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            throw AppError.authenticationFailed(
                reason: "Either AWS credentials (access key, secret key, region) or API key must be provided"
            )
        }
    }
    
    /// Executes a URLRequest and validates the HTTP response.
    ///
    /// - Parameter request: The authenticated request to execute
    /// - Returns: Response data if successful
    /// - Throws: `AppError` for HTTP errors or invalid responses
    private func executeRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            logger.error("Invalid HTTP response", category: .llm)
            throw AppError.invalidResponse(underlying: nil)
        }
        
        guard (200..<300).contains(http.statusCode) else {
            let errorType = http.statusCode >= 500 ? "http_5xx" : "http_4xx"
            logger.debug("LLM request failed: statusCode=\(http.statusCode), errorType=\(errorType)", category: .llm)
            let raw = String(data: data, encoding: .utf8) ?? "<no body>"
            logger.error("HTTP error \(http.statusCode): \(raw)", category: .llm)
            throw AppError.httpError(statusCode: http.statusCode, message: raw)
        }
        
        logger.debug("LLM request succeeded: statusCode=\(http.statusCode)", category: .llm)
        return data
    }
    
    /// Parses LLMResponse from response data.
    ///
    /// - Parameter data: Response data from the API
    /// - Returns: Decoded LLMResponse
    /// - Throws: Decoding errors if response cannot be parsed
    private func parseResponse(_ data: Data) throws -> LLMResponse {
        do {
            let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
            logger.debug("LLM response parsed successfully", category: .llm)
            return decoded
        } catch {
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("Failed to parse LLM response. Raw response (first 1000 chars): \(String(responseString.prefix(1000)))", category: .llm)
            } else {
                logger.error("Failed to parse LLM response. Data length: \(data.count) bytes", category: .llm)
            }
            throw error
        }
    }
    
    /// Executes a complete LLM request: build → authenticate → execute → parse.
    ///
    /// - Parameters:
    ///   - messages: Array of messages in simple format
    ///   - tools: Optional tool definitions
    /// - Returns: Decoded LLMResponse
    /// - Throws: Various AppErrors for authentication, network, or parsing failures
    private func performRequest(
        messages: [[String: String]],
        tools: [[String: Any]]? = nil
    ) async throws -> LLMResponse {
        var request = try buildRequest(messages: messages, tools: tools)
        try authenticateRequest(&request)
        let data = try await executeRequest(request)
        return try parseResponse(data)
    }
    
    /// Executes a complete LLM request with tool support: build → authenticate → execute → parse.
    ///
    /// - Parameters:
    ///   - messages: Array of messages in full format (supports tool calls)
    ///   - tools: Optional tool definitions
    /// - Returns: Response data for manual parsing (needed for tool call extraction)
    /// - Throws: Various AppErrors for authentication, network failures
    private func performRequestWithTools(
        messages: [[String: Any]],
        tools: [[String: Any]]? = nil
    ) async throws -> Data {
        var request = try buildRequestWithTools(messages: messages, tools: tools)
        try authenticateRequest(&request)
        return try await executeRequest(request)
    }
    
    // MARK: - Public API Methods
    
    /// Generates a hello message with time-of-day awareness and a debug payload using a strict JSON schema.
    func generateHelloMessagePayload(
        to name: String,
        styleHint: String? = nil
    ) async throws -> String {
        let prompt = """
        You are composing a single, natural-sounding good morning text to my girlfriend named \(name).
        
        Requirements:
        - Output EXACTLY ONE message (not a list, not multiple variants).
        - Keep it short (max ~25 words), warm, and personal.
        - Avoid greetings like “Good morning, [Name]” unless it feels natural.
        - Avoid emojis unless they genuinely add value.
        - No bullet points, no numbering, no quotes, no extra commentary.
        - Vary phrasing subtly across requests so it doesn’t feel templated.
        
        \(styleHint ?? "")
        """
        
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": "You write concise, single-message, natural-sounding text messages that feel personal and warm. No lists or multiple options."
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ]
        
        // Execute request using reusable infrastructure
        let response = try await performRequest(messages: messages)
        let raw = response.choices.first?.message.content ?? ""
        let sanitized = sanitizeSingleMessage(raw)
        
        logger.debug("LLM response processed: messageLength=\(sanitized.count) chars", category: .llm)
        return sanitized
    }
    
    /// Generates a text response from the LLM with a custom prompt.
    ///
    /// - Parameters:
    ///   - systemPrompt: Optional system prompt to set the context
    ///   - userPrompt: The user's prompt/question
    /// - Returns: The LLM's response text
    /// - Throws: Errors from LLM API or network issues
    func generateText(
        systemPrompt: String? = nil,
        userPrompt: String
    ) async throws -> String {
        // Build messages array
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": userPrompt])
        
        // Execute request using reusable infrastructure
        let response = try await performRequest(messages: messages)
        let raw = response.choices.first?.message.content ?? ""
        
        logger.debug("LLM response processed: messageLength=\(raw.count) chars", category: .llm)
        return raw
    }
    
    /// Generates a hello message with time-of-day awareness and a debug payload using a strict JSON schema.
    func generateHelloMessagePayload(
        to name: String,
        styleHint: String? = nil,
        timezoneIdentifier: String? = nil
    ) async throws -> (message: String, debug: String?, prompt: String) {
        // Determine time of day based on timezone
        let timeOfDayContext: String
        if let tzID = timezoneIdentifier, let timezone = TimeZone(identifier: tzID) {
            var calendar = Calendar.current
            calendar.timeZone = timezone
            let now = Date()
            let hour = calendar.component(.hour, from: now)
            
            switch hour {
            case 5..<12:
                timeOfDayContext = "It's morning in their timezone (\(tzID))."
            case 12..<17:
                timeOfDayContext = "It's afternoon in their timezone (\(tzID))."
            case 17..<21:
                timeOfDayContext = "It's evening in their timezone (\(tzID))."
            default:
                timeOfDayContext = "It's late evening/night in their timezone (\(tzID))."
            }
        } else {
            timeOfDayContext = ""
        }
        
        let needsNonRomantic = (styleHint ?? "").localizedCaseInsensitiveContains("avoid romantic language")
        let contextBlock = (styleHint ?? "").isEmpty ? "" : "\nCONTEXT:\n\(styleHint!)\n"
        let timeBlock = timeOfDayContext.isEmpty ? "" : "\nTIME CONTEXT:\n\(timeOfDayContext)\n"
        
        let prompt = """
        You are composing a single, natural-sounding hello/greeting text to a recipient named \(name).
        
        \(timeBlock)Requirements:
        - Output **EXACTLY ONE** message (not a list, not multiple variants).
        - Keep it **short (max ~25 words)**, warm, and personal.
        - **Time-of-Day Rule:** Match the greeting to the time of day in their timezone. Use "Good morning" for morning, "Good afternoon" for afternoon, "Good evening" for evening, or just "Hey/Hi" for late night. Make it feel natural and contextually appropriate.
        - **Subtlety Rule:** Use the context for emotional tone and key themes, but **DO NOT directly quote or summarize** the factual details of the relationship. Make the text feel genuinely spontaneous.
        - **Nickname Rule:** Adhere strictly to the required terms of address specified in the context (e.g., 'Mom'/'Dad', 'baby girl', 'bro', etc.).
        - **Style Rule:** Keep the text punchy and natural, using a maximum of **one or two relevant emojis** only if they genuinely enhance the mood.
        - No bullet points, no numbering, no quotes, no extra commentary.
        
        \(needsNonRomantic ? "- Avoid romantic language; use an appropriate family/sibling tone." : "")
        
        Return ONLY a single-line JSON object with this exact schema:
        {"version":1,"message":"<final sms to send>","debug":"<optional notes>"}
        Do not include any text before or after the JSON.
        \(contextBlock)
        """

        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": "Respond only with a single JSON object: {\"version\":1,\"message\":\"...\",\"debug\":\"...\"}. No other text, no code fences, no explanations."
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ]
        
        // Execute request using reusable infrastructure
        let response = try await performRequest(messages: messages)
        let content = response.choices.first?.message.content ?? ""
        
        logger.debug("LLM response processed: contentLength=\(content.count) chars", category: .llm)
        if let jsonText = firstJSONObjectString(in: content), let payloadData = jsonText.data(using: .utf8) {
            do {
                let payload = try JSONDecoder().decode(LLMMessagePayload.self, from: payloadData)
                return (message: sanitizeSingleMessage(payload.message), debug: payload.debug, prompt: prompt)
            } catch {
                let sanitized = sanitizeSingleMessage(stripPromptEcho(content))
                return (message: sanitized, debug: "Model returned JSON-like output but failed to parse; sanitized.", prompt: prompt)
            }
        } else {
            let sanitized = sanitizeSingleMessage(stripPromptEcho(content))
            return (message: sanitized, debug: "Non-JSON model output; sanitized and echo-stripped.", prompt: prompt)
        }
    }
    
    
    private func sanitizeSingleMessage(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove surrounding quotes if present
        if (text.hasPrefix("\"") && text.hasSuffix("\"")) || (text.hasPrefix("“") && text.hasSuffix("”")) {
            text = String(text.dropFirst().dropLast())
        }

        // Strip simple code fences/backticks if any
        if text.hasPrefix("```") {
            text = text.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
        }

        // Keep the last non-empty line if multiple lines were returned
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let last = lines.last { return last }
        return text
    }
    
    private func firstJSONObjectString(in text: String) -> String? {
        var result = ""
        var depth = 0
        var started = false
        for ch in text {
            if ch == "{" { depth += 1; started = true }
            if started { result.append(ch) }
            if ch == "}" {
                depth -= 1
                if started && depth == 0 { break }
            }
        }
        return started && depth == 0 ? result : nil
    }

    private func stripPromptEcho(_ text: String) -> String {
        let bannedPrefixes = [
            "You are composing",
            "Requirements:",
            "Return ONLY",
            "SCHEDULE:",
            "System:",
            "User:"
        ]
        var lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        lines.removeAll { line in
            bannedPrefixes.contains { prefix in line.hasPrefix(prefix) }
        }
        return lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Agentic Workflow Support (Function Calling)
    
    /// Executes an agentic workflow with function calling support.
    ///
    /// This method implements a ReAct-style agent loop where the LLM can:
    /// 1. Receive user instructions
    /// 2. Decide which tools/functions to call
    /// 3. Execute functions and receive results
    /// 4. Continue reasoning until completion
    ///
    /// - Parameters:
    ///   - userRequest: The user's initial request
    ///   - tools: Available tools/functions the agent can use
    ///   - maxIterations: Maximum number of LLM → function call iterations (default: 5)
    /// - Returns: Final result from the agent
    /// - Throws: Errors from LLM or tool execution
    func executeAgenticWorkflow(
        userRequest: String,
        tools: [LLMTool],
        maxIterations: Int = 5
    ) async throws -> String {
        logger.debug("Starting agentic workflow: request=\(userRequest), tools=\(tools.count)", category: .llm)
        
        var conversationHistory: [[String: Any]] = [
            [
                "role": "system",
                "content": """
                You are an intelligent AI assistant that can help users find restaurants and make reservations.
                You have access to tools that can search for restaurants and make reservations.
                
                When the user asks you to find a restaurant and make a reservation, follow these steps:
                1. Use the search_restaurants tool to find restaurants matching their criteria
                2. Analyze the results and select the best option
                3. Use the make_reservation tool to book a table
                4. Provide a friendly confirmation message
                
                Always be helpful and provide clear information about what you're doing.
                """
            ],
            [
                "role": "user",
                "content": userRequest
            ]
        ]
        
        for iteration in 0..<maxIterations {
            logger.debug("Agentic workflow iteration \(iteration + 1)/\(maxIterations)", category: .llm)
            
            // Prepare tool definitions for this request
            let toolDefinitions = tools.map { $0.definition }
            
            // Call LLM with current conversation history
            let response = try await callLLMWithTools(
                messages: conversationHistory,
                tools: toolDefinitions
            )
            
            // Check if LLM wants to call a function
            if let toolCall = response.toolCall, let toolCallId = response.toolCallId {
                // Add assistant's response to history with tool call
                // When tool_calls are present, content should be null or empty
                var assistantMessage: [String: Any] = ["role": "assistant"]
                assistantMessage["tool_calls"] = [[
                    "id": toolCallId,
                    "type": "function",
                    "function": [
                        "name": toolCall.name,
                        "arguments": toolCall.arguments
                    ]
                ]]
                // Only add content if it's non-empty (most tool calls have null/empty content)
                if let content = response.content, !content.isEmpty {
                    assistantMessage["content"] = content
                }
                conversationHistory.append(assistantMessage)
                logger.debug("LLM requested tool call: \(toolCall.name) (id: \(toolCallId))", category: .llm)
                
                // Find and execute the tool
                guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
                    let errorMsg = "Unknown tool: \(toolCall.name)"
                    logger.error(errorMsg, category: .llm)
                    conversationHistory.append([
                        "role": "tool",
                        "tool_call_id": toolCallId,
                        "content": "Error: \(errorMsg)"
                    ])
                    continue
                }
                
                // Execute tool
                do {
                    let toolResult = try await tool.execute(toolCall.arguments)
                    
                    // Add tool result to conversation (tool messages don't have "name" field)
                    conversationHistory.append([
                        "role": "tool",
                        "tool_call_id": toolCallId,
                        "content": toolResult
                    ])
                    
                    logger.debug("Tool execution completed: \(toolCall.name)", category: .llm)
                } catch {
                    let errorMsg = "Tool execution failed: \(error.localizedDescription)"
                    logger.error(errorMsg, error: error, category: .llm)
                    conversationHistory.append([
                        "role": "tool",
                        "tool_call_id": toolCallId,
                        "content": "Error: \(errorMsg)"
                    ])
                }
            } else {
                // No tool call - add assistant message and complete workflow
                var assistantMessage: [String: Any] = ["role": "assistant"]
                if let content = response.content {
                    assistantMessage["content"] = content
                }
                conversationHistory.append(assistantMessage)
                
                logger.debug("Agentic workflow completed after \(iteration + 1) iterations", category: .llm)
                return response.content ?? "Workflow completed."
            }
        }
        
        // Max iterations reached
        let finalMessage = conversationHistory.compactMap { msg -> String? in
            if msg["role"] as? String == "assistant",
               let content = msg["content"] as? String {
                return content
            }
            return nil
        }.last ?? "Workflow completed but reached max iterations."
        
        logger.warning("Agentic workflow reached max iterations (\(maxIterations))", category: .llm)
        return finalMessage
    }
    
    /// Internal method to call LLM with tool definitions.
    private func callLLMWithTools(
        messages: [[String: Any]],
        tools: [[String: Any]]
    ) async throws -> LLMToolResponse {
        // Convert messages to proper format (handle tool messages differently)
        let formattedMessages = messages.compactMap { msg -> [String: Any]? in
            guard let role = msg["role"] as? String else {
                return nil
            }
            
            // Handle tool messages (they have tool_call_id and content, but NOT name)
            if role == "tool" {
                if let toolCallId = msg["tool_call_id"] as? String,
                   let content = msg["content"] as? String {
                    return [
                        "role": role,
                        "tool_call_id": toolCallId,
                        "content": content
                    ]
                }
                return nil
            }
            
            // Handle assistant messages with tool_calls (if present)
            if role == "assistant" {
                var assistantMsg: [String: Any] = ["role": role]
                // If there are tool_calls, content should be null or empty string
                let hasToolCalls = msg["tool_calls"] != nil
                if let content = msg["content"] as? String, !content.isEmpty {
                    assistantMsg["content"] = content
                } else if !hasToolCalls {
                    // Only set content to null if there are no tool calls
                    assistantMsg["content"] = NSNull()
                }
                // Preserve tool_calls if they exist
                if let toolCalls = msg["tool_calls"] as? [[String: Any]] {
                    assistantMsg["tool_calls"] = toolCalls
                }
                return assistantMsg
            }
            
            // Regular user/system messages
            if let content = msg["content"] as? String {
                return ["role": role, "content": content]
            }
            
            return nil
        }
        
        // Execute request using reusable infrastructure
        let data = try await performRequestWithTools(messages: formattedMessages, tools: tools)
        
        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let choice = choices?.first
        let message = choice?["message"] as? [String: Any]
        
        let content = message?["content"] as? String
        let toolCalls = message?["tool_calls"] as? [[String: Any]]
        
        // Extract tool call if present
        var toolCall: LLMToolCall?
        var toolCallId: String?
        if let firstToolCall = toolCalls?.first {
            toolCallId = firstToolCall["id"] as? String
            let function = firstToolCall["function"] as? [String: Any]
            toolCall = LLMToolCall(
                name: function?["name"] as? String ?? "",
                arguments: function?["arguments"] as? String ?? "{}"
            )
        }
        
        return LLMToolResponse(content: content, toolCall: toolCall, toolCallId: toolCallId)
    }
}

// MARK: - Tool Support Types

/// Represents a tool/function available to the LLM agent.
struct LLMTool {
    let name: String
    let description: String
    let parameters: [String: Any]
    let execute: (String) async throws -> String // arguments JSON string -> result JSON string
    
    var definition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }
}

/// Response from LLM that may include tool calls.
struct LLMToolResponse {
    let content: String?
    let toolCall: LLMToolCall?
    let toolCallId: String?
}

/// Represents a tool call requested by the LLM.
struct LLMToolCall {
    let name: String
    let arguments: String // JSON string
}
