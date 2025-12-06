//
//  LLMClient.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
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

// MARK: - Client

final class LLMClient {
    private let apiKey: String
    private let baseURL: URL
    private let model: String
    private let session: URLSession
    
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
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        // Use SigV4 signing if AWS credentials are provided, otherwise use Bearer token
        if let accessKey = awsAccessKey,
           let secretKey = awsSecretKey,
           let region = awsRegion {
            let signer = AWSSigV4Signer(accessKey: accessKey, secretKey: secretKey, region: region)
            request = try signer.sign(request)
        } else if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            throw NSError(
                domain: "LLMClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Either AWS credentials (access key, secret key, region) or API key must be provided"]
            )
        }
        
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
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        // Use SigV4 signing if AWS credentials are provided, otherwise use Bearer token
        if let accessKey = awsAccessKey,
           let secretKey = awsSecretKey,
           let region = awsRegion {
            let signer = AWSSigV4Signer(accessKey: accessKey, secretKey: secretKey, region: region)
            request = try signer.sign(request)
        } else if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            throw NSError(
                domain: "LLMClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Either AWS credentials (access key, secret key, region) or API key must be provided"]
            )
        }

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



