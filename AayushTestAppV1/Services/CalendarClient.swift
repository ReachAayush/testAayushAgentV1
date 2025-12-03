import EventKit

/// Service for accessing and managing calendar events.
///
/// **Purpose**: Provides a clean interface for calendar operations, handling permissions
/// and abstracting away EventKit complexity from the rest of the app.
///
/// **Architecture**: Follows the service layer pattern - pure data access with no business
/// logic. Used by actions like `TodayScheduleSummaryAction` and `SummarizeDayAction`.
///
/// **Permissions**: Requires calendar access permission. Handles both iOS 17+ (full access)
/// and legacy (read-only) permission models.
final class CalendarClient {
    /// EventKit store instance for calendar access.
    private let eventStore = EKEventStore()
    
    // MARK: - Public API
    
    /// Returns all event calendars available on the device (after access is granted).
    ///
    /// - Returns: Array of `EKCalendar` objects representing available calendars
    /// - Note: Requires calendar access to be granted first via `requestAccessIfNeeded()`
    func fetchEventCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }
    
    /// Requests calendar access if needed.
    ///
    /// **iOS Version Handling**:
    /// - iOS 17+: Uses `requestFullAccessToEvents` (required for full calendar access)
    /// - iOS 16 and below: Uses legacy `requestAccess(to:)` API
    ///
    /// - Throws: Error if access is denied or request fails
    /// - Note: This method is idempotent - safe to call multiple times
    func requestAccessIfNeeded() async throws {
        try await withCheckedThrowingContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    self.handleAccess(granted: granted, error: error, continuation: continuation)
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    self.handleAccess(granted: granted, error: error, continuation: continuation)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Handles the result of a calendar access request.
    ///
    /// - Parameters:
    ///   - granted: Whether access was granted
    ///   - error: Any error that occurred during the request
    ///   - continuation: Continuation to resume with result
    private func handleAccess(
        granted: Bool,
        error: Error?,
        continuation: CheckedContinuation<Void, Error>
    ) {
        if let error = error {
            continuation.resume(throwing: error)
        } else if !granted {
            let err = NSError(
                domain: "CalendarClient",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Calendar access denied by user"]
            )
            continuation.resume(throwing: err)
        } else {
            continuation.resume()
        }
    }
    
    /// Fetches today's schedule summary from specified calendars.
    ///
    /// - Parameter calendars: Calendars to query (empty = all calendars)
    /// - Returns: Formatted string with today's events
    /// - Throws: Error if calendar access is not available
    private func fetchTodayScheduleSummary(using calendars: [EKCalendar]) throws -> String {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return "Could not compute end of day."
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: calendars
        )

        let events = eventStore
            .events(matching: predicate)
            .sorted(by: { $0.startDate < $1.startDate })

        guard !events.isEmpty else {
            return "You have no events scheduled today."
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        var lines: [String] = ["Here’s your schedule for today:"]
        for event in events {
            let start = formatter.string(from: event.startDate)
            let title = event.title ?? "Untitled event"
            lines.append("- \(start): \(title)")
        }

        return lines.joined(separator: "\n")
    }
    
    /// Fetches today's schedule from all available calendars.
    ///
    /// - Returns: Formatted string with today's events
    /// - Throws: Error if calendar access is not available
    func fetchTodayScheduleSummary() throws -> String {
        let calendars = eventStore.calendars(for: .event)
        return try fetchTodayScheduleSummary(using: calendars)
    }
    
    /// Fetches today's schedule from specified calendars only.
    ///
    /// - Parameter allowedCalendarIDs: Set of calendar identifiers to include
    /// - Returns: Formatted string with today's events from allowed calendars
    /// - Throws: Error if calendar access is not available
    ///
    /// **Use Case**: Allows users to filter which calendars appear in summaries,
    /// useful when users have many calendars but only want to see work or personal events.
    func fetchTodayScheduleSummary(allowedCalendarIDs: Set<String>) throws -> String {
        let all = eventStore.calendars(for: .event)
        let filtered = all.filter { allowedCalendarIDs.contains($0.calendarIdentifier) }
        return try fetchTodayScheduleSummary(using: filtered)
    }
}
