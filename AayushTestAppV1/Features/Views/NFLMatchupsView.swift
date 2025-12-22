//
//  NFLMatchupsView.swift
//  AayushTestAppV1
//
//

import SwiftUI

/// View for displaying NFL week matchups with LLM predictions.
///
/// **Purpose**: Parses JSON response from NFLMatchupsAction and displays
/// matchups in a clean, easy-to-read table format with predictions,
/// scores, key factors, and team rankings.
struct NFLMatchupsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var agent: AgentController
    
    @State private var games: [NFLGame] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                            Image(systemName: "sportscourt.fill")
                                .font(.system(size: 50))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("This Week's NFL Matchups")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SteelersTheme.textPrimary)
                            Text("AI-powered predictions & analysis")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Fetch Button
                        Button {
                            Task {
                                await fetchMatchups()
                            }
                        } label: {
                            HStack {
                                if isLoading || agent.isBusy {
                                    ProgressView()
                                        .tint(SteelersTheme.textOnGold)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(isLoading || agent.isBusy ? "Loading..." : "Get Matchups")
                                    .fontWeight(.semibold)
                            }
                        }
                        .steelersButton()
                        .padding(.horizontal, 20)
                        .disabled(isLoading || agent.isBusy)
                        
                        // Matchups Table
                        if !games.isEmpty {
                            VStack(spacing: 16) {
                                ForEach(games) { game in
                                    GameCard(game: game)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Error Display
                        if let error = errorMessage {
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
                        if games.isEmpty && !isLoading {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(SteelersTheme.steelersGold)
                                    Text("How it works")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                }
                                Text("Tap 'Get Matchups' to fetch AI-powered predictions for all NFL Week 15 games. The analysis includes predicted winners, scores, key injuries, and strategic matchups.")
                                    .font(.caption)
                                    .foregroundColor(SteelersTheme.textSecondary)
                            }
                            .padding()
                            .steelersCard()
                            .padding(.horizontal, 20)
                        }
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
    
    private func fetchMatchups() async {
        let logger = LoggingService.shared
        logger.debug("NFL Matchups view: Starting to fetch matchups", category: .ui)
        
        isLoading = true
        errorMessage = nil
        games = []
        
        let action = NFLMatchupsAction(llmClient: agent.llmClient)
        logger.debug("NFL Matchups view: Executing action", category: .ui)
        await agent.run(action: action)
        
        if let error = agent.errorMessage {
            logger.error("NFL Matchups view: Action failed with error: \(error)", category: .ui)
            errorMessage = error
            isLoading = false
            return
        }
        
        logger.debug("NFL Matchups view: Action completed, parsing response. Response length: \(agent.lastOutput.count) chars", category: .ui)
        // Parse JSON from response
        parseGamesFromResponse(agent.lastOutput)
        logger.debug("NFL Matchups view: Parsing complete. Found \(games.count) games", category: .ui)
        isLoading = false
    }
    
    private func parseGamesFromResponse(_ response: String) {
        let logger = LoggingService.shared
        logger.debug("NFL Matchups view: Starting to parse response", category: .ui)
        
        // Extract JSON from response (might be wrapped in markdown code blocks or plain text)
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.debug("NFL Matchups view: Response trimmed, length: \(jsonString.count) chars", category: .ui)
        
        // Remove reasoning tags if present (e.g., <reasoning>...</reasoning>)
        if jsonString.contains("<reasoning>") {
            logger.debug("NFL Matchups view: Detected reasoning tags, removing them", category: .ui)
            // Remove <reasoning>...</reasoning> blocks
            while let startRange = jsonString.range(of: "<reasoning>", options: .caseInsensitive),
                  let endRange = jsonString.range(of: "</reasoning>", options: .caseInsensitive, range: startRange.upperBound..<jsonString.endIndex) {
                jsonString.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            }
            // Also handle single-line reasoning tags
            jsonString = jsonString.replacingOccurrences(of: "<reasoning>.*?</reasoning>", with: "", options: [.regularExpression, .caseInsensitive])
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.debug("NFL Matchups view: After reasoning tag removal, length: \(jsonString.count) chars", category: .ui)
        }
        
        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```") {
            logger.debug("NFL Matchups view: Detected markdown code blocks, removing them", category: .ui)
            let lines = jsonString.components(separatedBy: .newlines)
            let filteredLines = lines.filter { !$0.hasPrefix("```") && !$0.hasPrefix("json") }
            jsonString = filteredLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            logger.debug("NFL Matchups view: After markdown removal, length: \(jsonString.count) chars", category: .ui)
        }
        
        // Try to find the start of JSON (first { character)
        if let firstBrace = jsonString.firstIndex(of: "{") {
            let beforeBrace = jsonString[..<firstBrace]
            if !beforeBrace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logger.debug("NFL Matchups view: Found text before JSON, removing prefix", category: .ui)
                jsonString = String(jsonString[firstBrace...])
                logger.debug("NFL Matchups view: After prefix removal, length: \(jsonString.count) chars", category: .ui)
            }
        }
        
        // Try direct parsing first
        logger.debug("NFL Matchups view: Attempting direct JSON parsing", category: .ui)
        if let jsonData = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            logger.debug("NFL Matchups view: JSON parsed successfully, checking for nfl_week_data key", category: .ui)
            
            // Check for new schema with nfl_week_data wrapper
            if let weekData = json["nfl_week_data"] as? [String: Any],
               let gamesArray = weekData["games"] as? [[String: Any]] {
                logger.debug("NFL Matchups view: Found nfl_week_data structure with \(gamesArray.count) games", category: .ui)
                games = parseGamesArray(gamesArray)
                return
            }
            
            // Fallback to old schema with games at root
            if let gamesArray = json["games"] as? [[String: Any]] {
                logger.debug("NFL Matchups view: Found games array at root with \(gamesArray.count) games", category: .ui)
                games = parseGamesArray(gamesArray)
                return
            }
            
            logger.warning("NFL Matchups view: JSON parsed but no games array found. Keys: \(json.keys.joined(separator: ", "))", category: .ui)
        } else {
            logger.debug("NFL Matchups view: Direct parsing failed, attempting to find JSON object in text", category: .ui)
        }
        
        // Try to find JSON object in the text (in case there's extra text around it)
        // First, try to find the specific JSON object starting with "nfl_week_data"
        if let jsonRange = findJSONObjectStartingWith(in: jsonString, prefix: "\"nfl_week_data\"") {
            logger.debug("NFL Matchups view: Found JSON object starting with nfl_week_data", category: .ui)
            let extractedJson = String(jsonString[jsonRange])
            if let jsonData = extractedJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Check for new schema
                if let weekData = json["nfl_week_data"] as? [String: Any],
                   let gamesArray = weekData["games"] as? [[String: Any]] {
                    logger.debug("NFL Matchups view: Found nfl_week_data in extracted JSON with \(gamesArray.count) games", category: .ui)
                    games = parseGamesArray(gamesArray)
                    return
                }
            }
        }
        
        // Fallback: try to find any JSON object
        if let jsonRange = findJSONObject(in: jsonString) {
            logger.debug("NFL Matchups view: Found JSON object range in text (fallback)", category: .ui)
            let extractedJson = String(jsonString[jsonRange])
            if let jsonData = extractedJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Check for new schema
                if let weekData = json["nfl_week_data"] as? [String: Any],
                   let gamesArray = weekData["games"] as? [[String: Any]] {
                    logger.debug("NFL Matchups view: Found nfl_week_data in extracted JSON with \(gamesArray.count) games", category: .ui)
                    games = parseGamesArray(gamesArray)
                    return
                }
                // Fallback to old schema
                if let gamesArray = json["games"] as? [[String: Any]] {
                    logger.debug("NFL Matchups view: Found games array in extracted JSON with \(gamesArray.count) games", category: .ui)
                    games = parseGamesArray(gamesArray)
                    return
                }
            }
        }
        
        logger.error("NFL Matchups view: Failed to parse matchups data. Response preview: \(String(response.prefix(500)))", category: .ui)
        errorMessage = "Failed to parse matchups data. The LLM response may not be in the expected JSON format. Please try again."
    }
    
    /// Finds a JSON object that contains a specific prefix string (e.g., "nfl_week_data")
    private func findJSONObjectStartingWith(in text: String, prefix: String) -> Range<String.Index>? {
        // First, find all potential JSON objects
        var candidates: [(range: Range<String.Index>, content: String)] = []
        var startIndex: String.Index?
        var depth = 0
        
        for (index, char) in text.enumerated() {
            let stringIndex = text.index(text.startIndex, offsetBy: index)
            if char == "{" {
                if startIndex == nil {
                    startIndex = stringIndex
                }
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0, let start = startIndex {
                    let range = start..<text.index(stringIndex, offsetBy: 1)
                    let content = String(text[range])
                    // Check if this JSON object contains our prefix
                    if content.contains(prefix) {
                        candidates.append((range: range, content: content))
                    }
                    startIndex = nil
                }
            }
        }
        
        // Return the first candidate that contains the prefix
        return candidates.first?.range
    }
    
    private func findJSONObject(in text: String) -> Range<String.Index>? {
        var startIndex: String.Index?
        var depth = 0
        
        for (index, char) in text.enumerated() {
            let stringIndex = text.index(text.startIndex, offsetBy: index)
            if char == "{" {
                if startIndex == nil {
                    startIndex = stringIndex
                }
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0, let start = startIndex {
                    return start..<text.index(stringIndex, offsetBy: 1)
                }
            }
        }
        return nil
    }
    
    private func parseGamesArray(_ gamesArray: [[String: Any]]) -> [NFLGame] {
        return gamesArray.compactMap { gameDict in
            guard let matchup = gameDict["matchup"] as? String,
                  let predictedWinner = gameDict["predicted_winner"] as? String,
                  let predictedScore = gameDict["predicted_score"] as? String,
                  let dateTimeSlot = gameDict["date_time_slot"] as? String,
                  let venueEnv = gameDict["venue_environment"] as? [String: Any],
                  let venueType = venueEnv["type"] as? String,
                  let weatherCondition = venueEnv["weather_condition"] as? String,
                  let teams = gameDict["teams"] as? [String: Any],
                  let awayTeam = teams["away"] as? [String: Any],
                  let homeTeam = teams["home"] as? [String: Any],
                  let awayName = awayTeam["name"] as? String,
                  let awayRecord = awayTeam["record_away"] as? String,
                  let awayRankings = awayTeam["rankings"] as? [String: Any],
                  let awayOffRank = awayRankings["offense"] as? Int,
                  let awayDefRank = awayRankings["defense"] as? Int,
                  let homeName = homeTeam["name"] as? String,
                  let homeRecord = homeTeam["record_home"] as? String,
                  let homeRankings = homeTeam["rankings"] as? [String: Any],
                  let homeOffRank = homeRankings["offense"] as? Int,
                  let homeDefRank = homeRankings["defense"] as? Int,
                  let keyFactors = gameDict["key_factors"] as? [String: Any],
                  let starGroup = keyFactors["star_group"] as? String,
                  let weakGroup = keyFactors["weak_group"] as? String else {
                return nil
            }
            
            // Handle both "injuries" and "injuries_summary" keys
            let injuries = (keyFactors["injuries_summary"] as? String) ?? (keyFactors["injuries"] as? String) ?? ""
            
            return NFLGame(
                id: UUID().uuidString,
                matchup: matchup,
                predictedWinner: predictedWinner,
                predictedScore: predictedScore,
                dateTimeSlot: dateTimeSlot,
                venueType: venueType,
                weatherCondition: weatherCondition,
                awayTeam: TeamInfo(
                    name: awayName,
                    record: awayRecord,
                    offenseRank: awayOffRank,
                    defenseRank: awayDefRank
                ),
                homeTeam: TeamInfo(
                    name: homeName,
                    record: homeRecord,
                    offenseRank: homeOffRank,
                    defenseRank: homeDefRank
                ),
                injuries: injuries,
                starGroup: starGroup,
                weakGroup: weakGroup
            )
        }
    }
}

// MARK: - Game Card Component

struct GameCard: View {
    let game: NFLGame
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Date/Time and Venue
            HStack {
                Text(game.dateTimeSlot)
                    .font(.caption)
                    .foregroundColor(SteelersTheme.steelersGold)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: game.venueType == "Dome" ? "house.fill" : "cloud.fill")
                        .font(.caption2)
                    Text(game.venueType)
                        .font(.caption2)
                    Text("•")
                        .font(.caption2)
                    Text(game.weatherCondition)
                        .font(.caption2)
                }
                .foregroundColor(SteelersTheme.textSecondary)
            }
            
            // Matchup
            Text(game.matchup)
                .font(.headline)
                .foregroundColor(SteelersTheme.textPrimary)
            
            // Prediction
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(SteelersTheme.steelersGold)
                    .font(.caption)
                Text("\(game.predictedWinner) wins \(game.predictedScore)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(SteelersTheme.steelersGold)
            }
            
            Divider()
                .background(SteelersTheme.cardBorder)
            
            // Teams Comparison
            VStack(spacing: 8) {
                TeamRow(team: game.awayTeam, isAway: true)
                TeamRow(team: game.homeTeam, isAway: false)
            }
            
            // Key Factors
            VStack(alignment: .leading, spacing: 8) {
                if !game.injuries.isEmpty {
                    KeyFactorRow(
                        icon: "cross.case.fill",
                        title: "Injuries",
                        content: game.injuries,
                        color: .orange
                    )
                }
                
                KeyFactorRow(
                    icon: "star.fill",
                    title: "Star Matchup",
                    content: game.starGroup,
                    color: SteelersTheme.steelersGold
                )
                
                KeyFactorRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Weakness",
                    content: game.weakGroup,
                    color: .red
                )
            }
        }
        .padding()
        .steelersCard()
    }
}

// MARK: - Team Row Component

struct TeamRow: View {
    let team: TeamInfo
    let isAway: Bool
    
    var body: some View {
        HStack {
            // Team Name and Record
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(team.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(SteelersTheme.textPrimary)
                    if isAway {
                        Text("(A)")
                            .font(.caption2)
                            .foregroundColor(SteelersTheme.textSecondary)
                    } else {
                        Text("(H)")
                            .font(.caption2)
                            .foregroundColor(SteelersTheme.textSecondary)
                    }
                }
                Text("Record: \(team.record)")
                    .font(.caption)
                    .foregroundColor(SteelersTheme.textSecondary)
            }
            
            Spacer()
            
            // Rankings
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("OFF")
                        .font(.caption2)
                        .foregroundColor(SteelersTheme.textSecondary)
                    Text("\(team.offenseRank)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(SteelersTheme.steelersGold)
                }
                
                VStack(spacing: 2) {
                    Text("DEF")
                        .font(.caption2)
                        .foregroundColor(SteelersTheme.textSecondary)
                    Text("\(team.defenseRank)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(SteelersTheme.steelersGold)
                }
            }
        }
    }
}

// MARK: - Key Factor Row Component

struct KeyFactorRow: View {
    let icon: String
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(SteelersTheme.textPrimary)
                Text(content)
                    .font(.caption)
                    .foregroundColor(SteelersTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Data Models

struct NFLGame: Identifiable {
    let id: String
    let matchup: String
    let predictedWinner: String
    let predictedScore: String
    let dateTimeSlot: String
    let venueType: String
    let weatherCondition: String
    let awayTeam: TeamInfo
    let homeTeam: TeamInfo
    let injuries: String
    let starGroup: String
    let weakGroup: String
}

struct TeamInfo {
    let name: String
    let record: String
    let offenseRank: Int
    let defenseRank: Int
}

#Preview("NFL Matchups View") {
    let llm = LLMClient(apiKey: "preview", baseURL: URL(string: "https://example.com")!, model: "preview")
    let agent = AgentController(
        llmClient: llm,
        calendarClient: CalendarClient(),
        messagesClient: MessagesClient(),
        favoritesStore: FavoriteContactsStore()
    )
    return NFLMatchupsView(agent: agent)
}

