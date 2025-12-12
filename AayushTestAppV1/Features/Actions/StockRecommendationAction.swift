//
//  StockRecommendationAction.swift
//  AayushTestAppV1
//
//

import Foundation

/// Action that asks the LLM to provide interesting stocks to consider buying today.
///
/// **Purpose**: Uses LLM to analyze market conditions and recommend stocks with
/// reasoning. Returns structured data with ticker symbols and explanations.
///
/// **Architecture**: Follows the `AgentAction` protocol. Uses LLMClient to generate
/// stock recommendations with reasoning.
struct StockRecommendationAction: AgentAction {
    // MARK: - AgentAction Conformance
    let id = "stock-recommendation"
    let displayName = "Stock Recommendations"
    let summary = "Get AI-powered stock recommendations: stocks to buy and stocks to avoid."
    
    // MARK: - Dependencies
    let llm: LLMClient
    
    // MARK: - AgentAction Implementation
    
    /// Executes the stock recommendation workflow.
    ///
    /// Uses two separate, focused prompts for better quality:
    /// 1. Stocks to buy - focused on opportunities
    /// 2. Stocks to avoid - focused on risks
    ///
    /// - Returns: `AgentActionResult.text` containing stock recommendations with embedded JSON
    /// - Throws: Errors from LLM API or network issues
    func run() async throws -> AgentActionResult {
        let logger = LoggingService.shared
        logger.debug("Stock recommendation action started", category: .action)
        
        // Get today's date in a readable format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let todayDateString = dateFormatter.string(from: Date())
        
        var stocksToBuy: [[String: String]] = []
        var stocksToAvoid: [[String: String]] = []
        var combinedText = ""
        
        // First prompt: Stocks to BUY
        logger.debug("Requesting stocks to buy", category: .action)
        let buySystemPrompt = """
        You are a financial analyst specializing in identifying stocks with high potential for price appreciation.
        Focus on stocks that are interesting to consider buying on \(todayDateString) based on current market conditions, 
        news, trends, technical analysis, earnings, or sector movements.
        """
        
        let buyUserPrompt = """
        Please provide 3-5 stocks to consider buying on \(todayDateString). For each stock, include:
        1. The stock ticker symbol (e.g., AAPL, MSFT, TSLA)
        2. A brief reason why it's a good buy on \(todayDateString) (market news, earnings, technical patterns, sector trends, etc.)
        3. Keep the reasoning concise but informative (2-3 sentences per stock)
        
        Format your response as a clear list with ticker symbols and reasoning. 
        At the end, include a JSON object with this exact structure:
        {
          "stocks": [
            {
              "ticker": "AAPL",
              "reasoning": "Brief explanation here"
            }
          ]
        }
        """
        
        do {
            let buyResponse = try await llm.generateText(
                systemPrompt: buySystemPrompt,
                userPrompt: buyUserPrompt
            )
            combinedText += "## Stocks to Buy\n\n\(buyResponse)\n\n"
            
            // Extract buy stocks from JSON
            if let buyStocks = extractStocksFromResponse(buyResponse, key: "stocks") {
                stocksToBuy = buyStocks
            }
        } catch {
            logger.error("Failed to get buy recommendations: \(error.localizedDescription)", category: .action)
            // Continue to avoid recommendations even if buy fails
        }
        
        // Second prompt: Stocks to AVOID
        logger.debug("Requesting stocks to avoid", category: .action)
        let avoidSystemPrompt = """
        You are a financial analyst specializing in identifying stocks with high risk of price decline.
        Focus on stocks that should be avoided or sold on \(todayDateString) based on negative news, 
        poor earnings outlook, technical breakdown, sector headwinds, or other risk factors.
        """
        
        let avoidUserPrompt = """
        Please provide 3-5 stocks to avoid or consider selling on \(todayDateString). For each stock, include:
        1. The stock ticker symbol
        2. A brief reason why it should be avoided or sold on \(todayDateString) (negative news, poor earnings outlook, technical breakdown, sector headwinds, etc.)
        3. Keep the reasoning concise but informative (2-3 sentences per stock)
        
        Format your response as a clear list with ticker symbols and reasoning. 
        At the end, include a JSON object with this exact structure:
        {
          "stocksToAvoid": [
            {
              "ticker": "XYZ",
              "reasoning": "Brief explanation here"
            }
          ]
        }
        """
        
        do {
            let avoidResponse = try await llm.generateText(
                systemPrompt: avoidSystemPrompt,
                userPrompt: avoidUserPrompt
            )
            combinedText += "## Stocks to Avoid\n\n\(avoidResponse)"
            
            // Extract avoid stocks from JSON
            if let avoidStocks = extractStocksFromResponse(avoidResponse, key: "stocksToAvoid") {
                stocksToAvoid = avoidStocks
            }
        } catch {
            logger.error("Failed to get avoid recommendations: \(error.localizedDescription)", category: .action)
            // Continue even if avoid fails - we may still have buy recommendations
        }
        
        // Combine results into final JSON
        var finalMessage = combinedText.isEmpty ? "Stock recommendations generated." : combinedText
        
        if !stocksToBuy.isEmpty || !stocksToAvoid.isEmpty {
            var combinedJSON: [String: Any] = [:]
            if !stocksToBuy.isEmpty {
                combinedJSON["stocks"] = stocksToBuy
            }
            if !stocksToAvoid.isEmpty {
                combinedJSON["stocksToAvoid"] = stocksToAvoid
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: combinedJSON),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                finalMessage += "\n\n<!--STOCK_DATA:" + jsonString + "-->"
            }
        }
        
        logger.debug("Stock recommendation completed: \(stocksToBuy.count) to buy, \(stocksToAvoid.count) to avoid", category: .action)
        
        return .text(finalMessage)
    }
    
    /// Extracts stock arrays from LLM response JSON.
    private func extractStocksFromResponse(_ response: String, key: String) -> [[String: String]]? {
        // Look for JSON in the response
        guard let jsonStart = response.range(of: "{"),
              let jsonEnd = response.range(of: "}", options: .backwards, range: jsonStart.upperBound..<response.endIndex) else {
            return nil
        }
        
        let jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let stocksArray = json[key] as? [[String: Any]] else {
            return nil
        }
        
        return stocksArray.compactMap { stockDict in
            guard let ticker = stockDict["ticker"] as? String,
                  let reasoning = stockDict["reasoning"] as? String else {
                return nil
            }
            return ["ticker": ticker, "reasoning": reasoning]
        }
    }
}
