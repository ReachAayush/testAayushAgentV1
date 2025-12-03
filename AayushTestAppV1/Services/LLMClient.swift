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
/// Used by actions like `GoodMorningMessageAction`, `SummarizeDayAction`, and `RespondToTextAction`.
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
            let content: String
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

struct LLMTonePayload: Decodable {
    let version: Int
    let tone: String
    let debug: String?
}

// MARK: - Client

final class LLMClient {
    private let apiKey: String
    private let baseURL: URL
    private let model: String
    private let session: URLSession
    
    /// - Parameters:
    ///   - apiKey: Your Amazon Bedrock bearer token.
    ///   - baseURL: Bedrock OpenAI-compatible base URL, e.g.
    ///              https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1
    ///   - model: Bedrock model ID, e.g. "openai.gpt-oss-20b-1:0"
    init(
        apiKey: String,
        baseURL: URL,
        model: String,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.session = session
    }
    
    /// Generates a short, warm "good morning" text to your girlfriend.
    func generateGoodMorningMessage(
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
        
        let body = LLMRequest(
            model: model,
            messages: [
                [
                    "role": "system",
                    "content": "You write concise, single-message, natural-sounding text messages that feel personal and warm. No lists or multiple options."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        )
        
        // Bedrock OpenAI-compatible Chat Completions endpoint:
        // POST {baseURL}/chat/completions
        let url = baseURL.appendingPathComponent("chat/completions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "<no body>"
            throw NSError(
                domain: "LLMClient",
                code: httpStatusCode(from: response),
                userInfo: [NSLocalizedDescriptionKey: "Bedrock error. Response: \(raw)"]
            )
        }
        
        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
        let raw = decoded.choices.first?.message.content ?? ""
        return sanitizeSingleMessage(raw)
    }
    
    /// Generates a good morning message and a debug payload using a strict JSON schema.
    func generateGoodMorningMessagePayload(
        to name: String,
        styleHint: String? = nil
    ) async throws -> (message: String, debug: String?, prompt: String) {
        let needsNonRomantic = (styleHint ?? "").localizedCaseInsensitiveContains("avoid romantic language")
        let contextBlock = (styleHint ?? "").isEmpty ? "" : "\nCONTEXT:\n\(styleHint!)\n"
        let prompt = """
        You are composing a single, natural-sounding good morning text to a recipient named \(name).
        
        Requirements:
        - Output **EXACTLY ONE** message (not a list, not multiple variants).
        - Keep it **short (max ~25 words)**, warm, and personal.
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

        let body = LLMRequest(
            model: model,
            messages: [
                [
                    "role": "system",
                    "content": "Respond only with a single JSON object: {\"version\":1,\"message\":\"...\",\"debug\":\"...\"}. No other text, no code fences, no explanations."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        )

        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "<no body>"
            throw NSError(
                domain: "LLMClient",
                code: httpStatusCode(from: response),
                userInfo: [NSLocalizedDescriptionKey: "Bedrock error. Response: \(raw)"]
            )
        }

        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? ""
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
    
    // Helper to avoid force casts in the error path
    private func httpStatusCode(from response: URLResponse?) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? -1
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
}

extension LLMClient {
    /// Generates a friendly day summary from a plain-text schedule using a strict JSON schema.
    func generateDaySummaryPayload(from eventsText: String, styleHint: String? = nil) async throws -> (message: String, debug: String?) {
        let prompt = """
        You are composing a short, friendly summary of my day based on the following schedule:\n\nSCHEDULE:\n\n\(eventsText)\n\nRequirements:\n- Output EXACTLY ONE short paragraph (max ~60 words), friendly and encouraging.\n- Avoid bullet points or lists; write as natural prose.\n- If there are no events, provide a gentle, positive note for a free day.\n\nReturn ONLY a single-line JSON object with this exact schema:\n{"version":1,"message":"<final summary to show>","debug":"<optional notes>"}\nDo not include any text before or after the JSON.\n\n\(styleHint ?? "")
        """

        let body = LLMRequest(
            model: model,
            messages: [
                [
                    "role": "system",
                    "content": "Respond only with a single JSON object: {\"version\":1,\"message\":\"...\",\"debug\":\"...\"}. No other text, no code fences, no explanations."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        )

        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "<no body>"
            throw NSError(
                domain: "LLMClient",
                code: httpStatusCode(from: response),
                userInfo: [NSLocalizedDescriptionKey: "Bedrock error. Response: \(raw)"]
            )
        }

        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? ""
        if let jsonText = firstJSONObjectString(in: content), let payloadData = jsonText.data(using: .utf8) {
            do {
                let payload = try JSONDecoder().decode(LLMMessagePayload.self, from: payloadData)
                return (message: sanitizeSingleMessage(payload.message), debug: payload.debug)
            } catch {
                let sanitized = sanitizeSingleMessage(stripPromptEcho(content))
                return (message: sanitized, debug: "Model returned JSON-like output but failed to parse; sanitized.")
            }
        } else {
            let sanitized = sanitizeSingleMessage(stripPromptEcho(content))
            return (message: sanitized, debug: "Non-JSON model output; sanitized and echo-stripped.")
        }
    }
}

extension LLMClient {
    /// Generates a contextually appropriate response to a received text message using strict JSON schema.
    /// 
    /// - Parameters:
    ///   - messageContext: Formatted context including the recent message and optional conversation history
    ///   - senderName: Name of the person who sent the message
    ///   - styleHint: Optional style guidance (contact-specific hints, tone profile, etc.)
    /// - Returns: Tuple containing the generated response message and optional debug info
    /// 
    /// **Purpose**: Helps users craft appropriate responses that match their communication style
    /// while being contextually relevant to the incoming message.
    func generateTextResponsePayload(
        messageContext: String,
        senderName: String,
        styleHint: String? = nil
    ) async throws -> (message: String, debug: String?) {
        let prompt = """
        You are helping me respond to a text message I just received.
        
        \(messageContext)
        
        Requirements:
        - Generate EXACTLY ONE natural, conversational response (not a list, not multiple options).
        - Keep it short and appropriate (typically 1-3 sentences, max ~40 words).
        - Match the tone and energy of the incoming message (if they're casual, be casual; if formal, be formal).
        - Be genuine and authentic - don't overthink it.
        - Avoid emojis unless they genuinely fit the conversation style.
        - No bullet points, no quotes, no extra commentary.
        
        \(styleHint != nil ? "\nSTYLE GUIDANCE:\n\(styleHint!)\n" : "")
        
        Return ONLY a single-line JSON object with this exact schema:
        {"version":1,"message":"<final response to send>","debug":"<optional notes>"}
        Do not include any text before or after the JSON.
        """

        let body = LLMRequest(
            model: model,
            messages: [
                [
                    "role": "system",
                    "content": "Respond only with a single JSON object: {\"version\":1,\"message\":\"...\",\"debug\":\"...\"}. No other text, no code fences, no explanations."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        )

        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "<no body>"
            throw NSError(
                domain: "LLMClient",
                code: httpStatusCode(from: response),
                userInfo: [NSLocalizedDescriptionKey: "Bedrock error. Response: \(raw)"]
            )
        }

        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? ""
        if let jsonText = firstJSONObjectString(in: content), let payloadData = jsonText.data(using: .utf8) {
            do {
                let payload = try JSONDecoder().decode(LLMMessagePayload.self, from: payloadData)
                return (message: sanitizeSingleMessage(payload.message), debug: payload.debug)
            } catch {
                let sanitized = sanitizeSingleMessage(stripPromptEcho(content))
                return (message: sanitized, debug: "Model returned JSON-like output but failed to parse; sanitized.")
            }
        } else {
            let sanitized = sanitizeSingleMessage(stripPromptEcho(content))
            return (message: sanitized, debug: "Non-JSON model output; sanitized and echo-stripped.")
        }
    }
}

extension LLMClient {
    /// Generates a compact tone summary from user-provided message samples using strict JSON.
    func generateToneSummaryPayload(from samples: [String]) async throws -> (tone: String, debug: String?) {
        let joined = samples.joined(separator: "\n---\n")
        let prompt = """
        You will derive a concise writing tone profile from the user's own message samples below.

        SAMPLES:\n\n\(joined)

        Requirements:\n- Return a short descriptor (2-4 sentences max) that captures voice, warmth, playfulness, typical length, emoji usage, and phrasing.\n- Avoid quoting full sentences from samples; generalize characteristics.\n- Do not include implementation instructions.\n
        Return ONLY a single-line JSON object with this exact schema:\n{"version":1,"tone":"<short tone description>","debug":"<optional notes>"}\nDo not include any text before or after the JSON.
        """

        let body = LLMRequest(
            model: model,
            messages: [
                [
                    "role": "system",
                    "content": "Respond only with a single JSON object: {\"version\":1,\"tone\":\"...\",\"debug\":\"...\"}. No other text, no code fences, no explanations."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        )

        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "<no body>"
            throw NSError(
                domain: "LLMClient",
                code: httpStatusCode(from: response),
                userInfo: [NSLocalizedDescriptionKey: "Bedrock error. Response: \(raw)"]
            )
        }

        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? ""
        if let jsonText = firstJSONObjectString(in: content), let payloadData = jsonText.data(using: .utf8) {
            do {
                let payload = try JSONDecoder().decode(LLMTonePayload.self, from: payloadData)
                return (tone: sanitizeSingleMessage(payload.tone), debug: payload.debug)
            } catch {
                let sanitized = sanitizeSingleMessage(stripPromptEcho(content))
                return (tone: sanitized, debug: "Model returned JSON-like output but failed to parse; sanitized.")
            }
        } else {
            let sanitized = sanitizeSingleMessage(stripPromptEcho(content))
            return (tone: sanitized, debug: "Non-JSON model output; sanitized and echo-stripped.")
        }
    }
}
