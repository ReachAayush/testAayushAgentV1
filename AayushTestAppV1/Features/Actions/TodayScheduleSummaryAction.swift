import Foundation

/// Action that fetches and formats today's calendar schedule.
///
/// **Purpose**: Provides a simple, formatted view of today's events without AI processing.
/// Useful for:
/// - Quick schedule reference
/// - When you just need the raw calendar data
///
/// **Architecture**: Follows the `AgentAction` protocol. Pure data access - no AI processing.
struct TodayScheduleSummaryAction: AgentAction {
    // MARK: - AgentAction Conformance
    let id = "today-schedule"
    let displayName = "Get Today's Schedule"
    let summary = "Reads your calendar and summarizes today."

    // MARK: - Dependencies
    let calendar: CalendarClient
    /// Calendar identifiers to include. `nil` means all calendars.
    let allowedCalendarIDs: Set<String>?

    // MARK: - AgentAction Implementation
    
    /// Fetches and formats today's schedule.
    ///
    /// - Returns: `AgentActionResult.text` containing formatted schedule
    /// - Throws: Errors from calendar access
    ///
    /// **Note**: Returns plain formatted text (e.g., "9:00 AM: Meeting with team").
    func run() async throws -> AgentActionResult {
        try await calendar.requestAccessIfNeeded()
        let text: String
        if let allowed = allowedCalendarIDs, !allowed.isEmpty {
            text = try calendar.fetchTodayScheduleSummary(allowedCalendarIDs: allowed)
        } else {
            text = try calendar.fetchTodayScheduleSummary()
        }
        return .text(text)
    }
}
