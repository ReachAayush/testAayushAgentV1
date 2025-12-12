//
//  StockRecommendationView.swift
//  AayushTestAppV1
//
//

import SwiftUI

/// View for displaying AI-powered stock recommendations.
///
/// **Purpose**: Provides UI for users to get stock recommendations from the LLM.
/// Displays ticker symbols and reasoning in a clean, organized format.
struct StockRecommendationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var agent: AgentController
    
    @State private var stocks: [StockRecommendation] = []
    @State private var stocksToAvoid: [StockRecommendation] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 50))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("Stock Recommendations")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SteelersTheme.textPrimary)
                            Text("AI-powered buy & avoid recommendations")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Get Recommendations Button
                        Button {
                            Task {
                                await getRecommendations()
                            }
                        } label: {
                            HStack {
                                if agent.isBusy {
                                    ProgressView()
                                        .tint(SteelersTheme.textOnGold)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(agent.isBusy ? "Analyzing..." : "Get Recommendations")
                                    .fontWeight(.semibold)
                            }
                        }
                        .steelersButton()
                        .padding(.horizontal, 20)
                        .disabled(agent.isBusy)
                        
                        // Stocks to Buy Display
                        if !stocks.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                    Text("Stocks to Buy")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Spacer()
                                    Text("\(stocks.count)")
                                        .font(.subheadline)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                }
                                .padding(.horizontal, 20)
                                
                                ForEach(stocks) { stock in
                                    StockCard(stock: stock, isPositive: true)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Divider between sections
                            if !stocksToAvoid.isEmpty {
                                Divider()
                                    .background(SteelersTheme.steelersGold.opacity(0.3))
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // Stocks to Avoid Display
                        if !stocksToAvoid.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                    Text("Stocks to Avoid")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Spacer()
                                    Text("\(stocksToAvoid.count)")
                                        .font(.subheadline)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                }
                                .padding(.horizontal, 20)
                                
                                ForEach(stocksToAvoid) { stock in
                                    StockCard(stock: stock, isPositive: false)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Raw LLM Response (if no structured data parsed)
                        if !agent.lastOutput.isEmpty && stocks.isEmpty && stocksToAvoid.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Analysis")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Spacer()
                                }
                                
                                Text(cleanOutput(agent.lastOutput))
                                    .font(.body)
                                    .foregroundColor(SteelersTheme.textPrimary)
                                    .textSelection(.enabled)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SteelersTheme.darkGray)
                                    .cornerRadius(12)
                            }
                            .padding()
                            .steelersCard()
                            .padding(.horizontal, 20)
                        }
                        
                        // Error Display
                        if let error = agent.errorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("Error")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(SteelersTheme.textSecondary)
                            }
                            .padding()
                            .steelersCard()
                            .padding(.horizontal, 20)
                        }
                        
                        // Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(SteelersTheme.steelersGold)
                                Text("Disclaimer")
                                    .font(.headline)
                                    .foregroundColor(SteelersTheme.textPrimary)
                            }
                            Text("These recommendations are AI-generated for informational purposes only. They are not financial advice. Always do your own research and consult with a financial advisor before making investment decisions.")
                                .font(.caption)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding()
                        .steelersCard()
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(SteelersTheme.steelersGold)
                    }
                }
            }
        }
    }
    
    private func getRecommendations() async {
        stocks = []
        stocksToAvoid = []
        
        let action = StockRecommendationAction(llm: agent.llmClient)
        await agent.run(action: action)
        
        // Parse stock data from embedded JSON in output
        if !agent.lastOutput.isEmpty {
            parseStocksFromOutput(agent.lastOutput)
        }
    }
    
    /// Parses stock data from LLM output (embedded as JSON comment).
    private func parseStocksFromOutput(_ output: String) {
        // Look for embedded JSON in comment
        guard let range = output.range(of: "<!--STOCK_DATA:", options: .backwards),
              let endRange = output.range(of: "-->", range: range.upperBound..<output.endIndex) else {
            // Try to parse JSON directly from the response
            if let jsonStart = output.range(of: "{"),
               let jsonEnd = output.range(of: "}", options: .backwards, range: jsonStart.upperBound..<output.endIndex) {
                let jsonString = String(output[jsonStart.lowerBound...jsonEnd.upperBound])
                parseStockJSON(jsonString)
            }
            return
        }
        
        let jsonString = String(output[range.upperBound..<endRange.lowerBound])
        parseStockJSON(jsonString)
    }
    
    /// Parses stock JSON data.
    private func parseStockJSON(_ jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            let logger = LoggingService.shared
            logger.debug("Failed to parse stock JSON", category: .action)
            return
        }
        
        // Parse stocks to buy - explicitly clear and populate
        stocks = []
        if let stocksArray = json["stocks"] as? [[String: Any]] {
            stocks = stocksArray.compactMap { stockDict in
                guard let ticker = stockDict["ticker"] as? String,
                      let reasoning = stockDict["reasoning"] as? String else {
                    return nil
                }
                
                return StockRecommendation(
                    ticker: ticker,
                    reasoning: reasoning
                )
            }
            let logger = LoggingService.shared
            logger.debug("Parsed \(stocks.count) stocks to buy", category: .action)
        }
        
        // Parse stocks to avoid - explicitly clear and populate
        stocksToAvoid = []
        if let avoidArray = json["stocksToAvoid"] as? [[String: Any]] {
            stocksToAvoid = avoidArray.compactMap { stockDict in
                guard let ticker = stockDict["ticker"] as? String,
                      let reasoning = stockDict["reasoning"] as? String else {
                    return nil
                }
                
                return StockRecommendation(
                    ticker: ticker,
                    reasoning: reasoning
                )
            }
            let logger = LoggingService.shared
            logger.debug("Parsed \(stocksToAvoid.count) stocks to avoid", category: .action)
        }
    }
    
    /// Removes embedded JSON comments from output for display.
    private func cleanOutput(_ output: String) -> String {
        var cleaned = output
        
        // Remove embedded JSON comments
        if let range = cleaned.range(of: "<!--STOCK_DATA:", options: .backwards),
           let endRange = cleaned.range(of: "-->", range: range.upperBound..<cleaned.endIndex) {
            cleaned.removeSubrange(range.lowerBound..<endRange.upperBound)
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Stock Card Component

/// Card component for displaying a single stock recommendation.
struct StockCard: View {
    let stock: StockRecommendation
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Ticker Symbol Badge with distinct styling
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPositive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .frame(width: 70, height: 40)
                    
                    Text(stock.ticker)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(isPositive ? .green : .red)
                }
                
                Spacer()
                
                // Stock icon with distinct styling
                Image(systemName: isPositive ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(isPositive ? .green : .red)
            }
            
            // Reasoning
            Text(stock.reasoning)
                .font(.body)
                .foregroundColor(SteelersTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(isPositive ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        .steelersCard()
    }
}

// MARK: - Stock Recommendation Model

/// Represents a stock recommendation with ticker and reasoning.
struct StockRecommendation: Identifiable {
    let id = UUID()
    let ticker: String
    let reasoning: String
}

#Preview("StockRecommendationView Preview") {
    let llm = LLMClient(apiKey: "preview", baseURL: URL(string: "https://example.com")!, model: "preview")
    let agent = AgentController(
        llmClient: llm,
        calendarClient: CalendarClient(),
        messagesClient: MessagesClient(),
        favoritesStore: FavoriteContactsStore()
    )
    return StockRecommendationView(agent: agent)
}
