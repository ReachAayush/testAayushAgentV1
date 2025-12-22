//
//  NFLMatchupsAction.swift
//  AayushTestAppV1
//
//

import Foundation

/// Action that fetches NFL Week matchups with LLM predictions and analysis.
///
/// **Purpose**: Uses LLM to generate NFL matchups for the current week with predictions.
///
/// **Architecture**: Follows the `AgentAction` protocol. Uses a single-step approach:
/// 1. Generate complete matchup data (schedule + analysis) in one LLM call
/// 2. Parse and return structured JSON
struct NFLMatchupsAction: AgentAction {
    // MARK: - AgentAction Conformance
    let id = "nfl-matchups"
    let displayName = "This Week's NFL Matchups"
    let summary = "Get NFL week matchups with AI-powered predictions and analysis."
    
    // MARK: - Dependencies
    let llmClient: LLMClient
    
    // MARK: - AgentAction Implementation
    
    /// Fetches NFL matchups with LLM analysis.
    ///
    /// - Returns: `AgentActionResult.text` containing JSON string with matchups data
    /// - Throws: Errors from LLM API or network issues
    func run() async throws -> AgentActionResult {
        let logger = LoggingService.shared
        let startTime = Date()
        logger.debug("NFL Matchups action started", category: .action)
        
        // Compute cache key for current week
        let cacheKey: String = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(identifier: "America/Los_Angeles")
            return "nfl-week-\(df.string(from: Date()))"
        }()
        
        // Check cache first
        if let cached = await NFLMatchupsCache.shared.get(forKey: cacheKey) {
            logger.debug("Returning cached NFL matchups", category: .action)
            return .text(cached)
        }
        
        // Calculate week number from current date
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        
        // NFL season starts around September 4-7
        var weekNumber = 1
        if month >= 9 {
            // September onwards - calculate week from Sep 4
            if let seasonStart = calendar.date(from: DateComponents(year: year, month: 9, day: 4)),
               let daysSince = calendar.dateComponents([.day], from: seasonStart, to: now).day {
                weekNumber = max(1, min(18, (daysSince / 7) + 1))
            }
        }
        
        // Simple, direct prompt - no web search, no complex instructions
        let systemPrompt = """
        You are a JSON API. Output ONLY valid JSON. No explanations, no reasoning blocks, no other text.
        
        Your response must start with { and end with }.
        """
        
        let userPrompt = """
        Generate NFL Week \(weekNumber) \(year) matchups with predictions.
        
        Output JSON with this exact structure:
        {
          "nfl_week_data": {
            "week_number": \(weekNumber),
            "season_year": \(year),
            "games": [
              {
                "matchup": "AWAY @ HOME",
                "predicted_winner": "TEAM",
                "predicted_score": "XX-YY",
                "date_time_slot": "Sun 1p ET",
                "venue_environment": {
                  "type": "Outdoor",
                  "weather_condition": "Mild"
                },
                "teams": {
                  "away": {
                    "name": "TEAM",
                    "current_record": "W-L",
                    "record_away": "W-L",
                    "rankings": {"offense": N, "defense": N}
                  },
                  "home": {
                    "name": "TEAM",
                    "current_record": "W-L",
                    "record_home": "W-L",
                    "rankings": {"offense": N, "defense": N}
                  }
                },
                "key_factors": {
                  "injuries_summary": "...",
                  "star_group": "TEAM + group",
                  "weak_group": "TEAM + group"
                }
              }
            ]
          }
        }
        
        Include 16 games (all 32 teams). Use team abbreviations (KC, SF, BUF, etc.).
        Use realistic records for week \(weekNumber) (e.g., 8-6, 10-4, etc.).
        """
        
        // Single LLM call - no retries, no fallbacks
        let response: String
        do {
            response = try await llmClient.generateTextAdvanced(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                temperature: 0.3,
                maxTokens: 2000,
                responseFormat: .none  // Don't use jsonObject - model doesn't support it well
            )
        } catch {
            logger.error("LLM call failed: \(error.localizedDescription)", category: .action)
            throw error
        }
        
        // Extract JSON from response
        let jsonString = extractJSON(from: response)
        
        // Validate JSON
        guard let data = jsonString.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: data) else {
            logger.error("Invalid JSON extracted from LLM response", category: .action)
            logger.debug("Extracted JSON: \(jsonString.prefix(500))", category: .action)
            throw AppError.invalidResponse(underlying: NSError(domain: "NFLMatchupsAction", code: 1, userInfo: [NSLocalizedDescriptionKey: "LLM did not return valid JSON"]))
        }
        
        // Cache and return
        await NFLMatchupsCache.shared.set(jsonString, forKey: cacheKey)
        let elapsed = Date().timeIntervalSince(startTime)
        logger.debug("NFL Matchups action completed: time=\(String(format: "%.2f", elapsed))s", category: .action)
        
        return .text(jsonString)
    }
    
    // MARK: - JSON Extraction
    
    /// Extracts JSON from LLM response, handling reasoning blocks and other formatting.
    private func extractJSON(from response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove reasoning blocks
        let reasoningPattern = #"<reasoning[^>]*>.*?</reasoning>"#
        if let regex = try? NSRegularExpression(pattern: reasoningPattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // Remove code fences
        let codeFencePattern = #"```(?:json)?\s*\n?(.*?)\n?```"#
        if let regex = try? NSRegularExpression(pattern: codeFencePattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            if let match = regex.firstMatch(in: cleaned, options: [], range: range),
               match.numberOfRanges > 1,
               let jsonRange = Range(match.range(at: 1), in: cleaned) {
                cleaned = String(cleaned[jsonRange])
            }
        }
        
        // Remove XML tags
        let xmlPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: xmlPattern, options: []) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // Find first { and last } to extract JSON object
        if let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}"),
           firstBrace < lastBrace {
            cleaned = String(cleaned[firstBrace...lastBrace])
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Safe Array Indexing Helper
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
