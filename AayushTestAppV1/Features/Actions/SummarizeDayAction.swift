import Foundation

/// Action that generates an AI-powered summary of the user's day from calendar events.
///
/// **Purpose**: Combines calendar data with LLM to create a friendly, encouraging summary
/// of the day's schedule. Useful for:
/// - Quick day overview
/// - Motivation and encouragement
/// - Planning and reflection
///
/// **Architecture**: Follows the `AgentAction` protocol. Coordinates between `CalendarClient`
/// (data) and `LLMClient` (generation).
///
/// **Flow**:
/// 1. Request calendar access
/// 2. Fetch today's events (filtered by allowed calendars if specified)
/// 3. Format events as text
/// 4. Generate summary using LLM
/// 5. Return formatted summary
struct SummarizeDayAction: AgentAction {
    // MARK: - AgentAction Conformance
    let id = "summarize-day"
    let displayName = "Summarize My Day"
    let summary = "Summarizes today using your calendars."

    // MARK: - Dependencies
    let calendar: CalendarClient
    let llm: LLMClient
    let allowedCalendarIDs: Set<String>?
    let styleHint: String?

    // MARK: - AgentAction Implementation
    
    /// Generates the day summary.
    ///
    /// - Returns: `AgentActionResult.text` containing the AI-generated summary
    /// - Throws: Errors from calendar access, LLM API, or network issues
    ///
    /// **Note**: Handles calendar filtering internally. If `allowedCalendarIDs` is nil or empty,
    /// uses all available calendars.
    func run() async throws -> AgentActionResult {
        try await calendar.requestAccessIfNeeded()
        let eventsText: String
        if let allowed = allowedCalendarIDs, !allowed.isEmpty {
            eventsText = try calendar.fetchTodayScheduleSummary(allowedCalendarIDs: allowed)
        } else {
            eventsText = try calendar.fetchTodayScheduleSummary()
        }
        let payload = try await llm.generateDaySummaryPayload(from: eventsText, styleHint: styleHint)
        return .text(payload.message)
    }
}
