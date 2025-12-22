//
//  WebSearchService.swift
//  AayushTestAppV1
//
//

import Foundation

/// Service for performing web searches to get real-time information.
///
/// **Purpose**: Provides web search capability for actions that need current information,
/// such as NFL schedules, stock prices, etc.
///
/// **Architecture**: Service layer pattern - pure data access with no business logic.
struct WebSearchService {
    private let logger = LoggingService.shared
    
    /// Performs a web search using DuckDuckGo (free, no API key required).
    ///
    /// - Parameter query: The search query string
    /// - Returns: Search results as a formatted string
    /// - Throws: Network or parsing errors
    func search(_ query: String) async throws -> String {
        logger.debug("Web search initiated: query=\(query)", category: .action)
        
        // Use DuckDuckGo Lite (text-only, easier to parse)
        // Format: https://lite.duckduckgo.com/lite/?q=QUERY
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lite.duckduckgo.com/lite/?q=\(encodedQuery)") else {
            throw AppError.invalidResponse(underlying: NSError(domain: "WebSearchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid search query"]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Web search failed")
        }
        
        // Parse HTML response (simplified - extract text content)
        if let html = String(data: data, encoding: .utf8) {
            let text = extractTextFromHTML(html)
            // Limit to first 2000 chars to avoid token limits and focus on most relevant content
            let limitedText = String(text.prefix(2000))
            logger.debug("Web search completed: resultLength=\(limitedText.count) chars", category: .action)
            logger.debug("Web search raw HTML preview (first 500 chars): \(String(html.prefix(500)))", category: .action)
            return limitedText
        }
        
        throw AppError.invalidResponse(underlying: NSError(domain: "WebSearchService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not parse search results"]))
    }
    
    /// Extracts readable text from HTML (simplified implementation).
    private func extractTextFromHTML(_ html: String) -> String {
        var extractedText: [String] = []
        
        // DuckDuckGo Lite structure: results are in table rows with links
        // Look for actual result content - skip navigation/UI elements
        // Pattern: Extract text from table cells that contain result links
        // Skip elements that are clearly navigation (like "All Regions", country names, etc.)
        
        // Pattern 1: Extract result table rows - look for <tr> with result links
        let resultRowPattern = #"<tr[^>]*>.*?<a[^>]*href="[^"]*"[^>]*>(.*?)</a>.*?</tr>"#
        if let regex = try? NSRegularExpression(pattern: resultRowPattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            for match in matches.prefix(15) { // Get first 15 results
                if match.numberOfRanges > 1,
                   let linkRange = Range(match.range(at: 1), in: html) {
                    let linkText = String(html[linkRange])
                    // Filter out navigation elements (short text, common UI words)
                    let cleaned = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.count > 15 && 
                       !cleaned.lowercased().contains("all regions") &&
                       !cleaned.lowercased().contains("belgium") &&
                       !cleaned.lowercased().contains("canada") &&
                       !cleaned.lowercased().contains("duckduckgo") {
                        extractedText.append(cleaned)
                    }
                }
            }
        }
        
        // Pattern 2: Extract result descriptions/snippets from table cells
        // Look for cells that contain longer text (likely descriptions)
        let cellPattern = #"<td[^>]*>(.*?)</td>"#
        if let regex = try? NSRegularExpression(pattern: cellPattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let cellRange = Range(match.range(at: 1), in: html) {
                    let cellText = String(html[cellRange])
                    // Remove HTML tags from cell
                    var cleaned = cellText
                    let tagPattern = #"<[^>]+>"#
                    if let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: []) {
                        let tagRange = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
                        cleaned = tagRegex.stringByReplacingMatches(in: cleaned, options: [], range: tagRange, withTemplate: " ")
                    }
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Only include substantial content (likely descriptions)
                    if cleaned.count > 30 && 
                       !cleaned.lowercased().contains("all regions") &&
                       !cleaned.lowercased().contains("belgium") &&
                       !cleaned.lowercased().contains("canada") &&
                       !cleaned.lowercased().contains("duckduckgo") &&
                       !cleaned.lowercased().contains("regions") {
                        extractedText.append(cleaned)
                    }
                }
            }
        }
        
        // If we extracted specific results, use those
        if !extractedText.isEmpty {
            var result = extractedText.joined(separator: "\n")
            // Decode HTML entities
            result = result.replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Fallback: Remove all HTML tags and extract text, but filter better
        var cleaned = html
        let patterns = [
            #"<script[^>]*>.*?</script>"#,
            #"<style[^>]*>.*?</style>"#,
            #"<[^>]+>"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: " ")
            }
        }
        
        // Decode HTML entities
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        // Clean up whitespace and filter out navigation/UI elements
        let lines = cleaned.components(separatedBy: .newlines)
        let cleanedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                let lower = line.lowercased()
                return line.count > 20 && // Substantial content
                       !lower.contains("all regions") &&
                       !lower.contains("belgium") &&
                       !lower.contains("canada") &&
                       !lower.contains("duckduckgo") &&
                       !lower.contains("regions") &&
                       !lower.contains("czech republic") &&
                       !lower.contains("indonesia") &&
                       !lower.contains("malaysia") &&
                       !lower.contains("netherlands") &&
                       !lower.contains("new zealand") &&
                       !lower.contains("pakistan") &&
                       !lower.contains("philippines") &&
                       !lower.contains("saudi arabia") &&
                       !lower.contains("south africa") &&
                       !lower.contains("switzerland") &&
                       !lower.contains("thailand") &&
                       !lower.contains("united kingdom") &&
                       !lower.contains("vietnam")
            }
        return cleanedLines.joined(separator: "\n")
    }
}

