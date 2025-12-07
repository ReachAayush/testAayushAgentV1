import Foundation

/// Action that generates a personalized hello message with time-of-day awareness.
///
/// **Purpose**: Creates warm, personalized greeting messages using LLM with support for:
/// - Contact-specific style hints (relationship context, tone preferences)
/// - Timezone-aware greetings (morning, afternoon, evening based on recipient's timezone)
/// - Custom context (additional guidance)
///
/// **Architecture**: Follows the `AgentAction` protocol. Business logic is in the action,
/// while UI coordination happens in `AgentController` and `HelloView`.
///
/// **Usage**: Typically created in `HelloView` with user-selected contact and
/// style hints, then executed via `AgentController.run(action:)`.
struct HelloMessageAction: AgentAction {
    // MARK: - AgentAction Conformance
    let id = "hello"
    let displayName = "Generate Hello Message"
    let summary = "Creates a personalized hello message using the LLM with time-of-day awareness."

    // MARK: - Dependencies
    let recipientName: String
    let styleHint: String?
    let timezoneIdentifier: String?
    let llm: LLMClient

    // MARK: - AgentAction Implementation
    
    /// Generates the hello message.
    ///
    /// - Returns: `AgentActionResult.text` containing the generated message
    /// - Throws: Errors from LLM API or network issues
    ///
    /// **Note**: The actual message generation happens in `LLMClient.generateHelloMessagePayload`.
    /// This action just coordinates the call and returns the result.
    func run() async throws -> AgentActionResult {
        // TODO: OPERATIONAL METRICS - Track hello action usage
        // Metrics to emit:
        // - action.hello.initiated (counter) - hello action executions
        // - action.hello.recipient (counter) - recipient name (anonymized/hashed)
        // - action.hello.has_timezone (counter) - actions with timezone specified
        // - action.hello.has_style_hint (counter) - actions with style hints
        // For now: logger.debug("Hello action: recipient=\(recipientName), hasTimezone=\(timezoneIdentifier != nil), hasStyleHint=\(styleHint != nil)", category: .action)
        let logger = LoggingService.shared
        logger.debug("Hello action: recipient=\(recipientName), hasTimezone=\(timezoneIdentifier != nil), hasStyleHint=\(styleHint != nil)", category: .action)
        
        let result = try await llm.generateHelloMessagePayload(
            to: recipientName,
            styleHint: styleHint,
            timezoneIdentifier: timezoneIdentifier
        )
        // We return only the text; AgentController will capture debug via type inspection
        return .text(result.message)
    }
}
