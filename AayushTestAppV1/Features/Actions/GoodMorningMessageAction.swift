import Foundation

/// Action that generates a personalized good morning message.
///
/// **Purpose**: Creates warm, personalized morning messages using LLM with support for:
/// - Contact-specific style hints (relationship context, tone preferences)
/// - Tone profile integration (user's messaging style)
/// - Custom context (additional guidance)
///
/// **Architecture**: Follows the `AgentAction` protocol. Business logic is in the action,
/// while UI coordination happens in `AgentController` and `GoodMorningView`.
///
/// **Usage**: Typically created in `GoodMorningView` with user-selected contact and
/// style hints, then executed via `AgentController.run(action:)`.
struct GoodMorningMessageAction: AgentAction {
    // MARK: - AgentAction Conformance
    let id = "good-morning"
    let displayName = "Generate Good Morning Text"
    let summary = "Creates a sweet good-morning message using the LLM."

    // MARK: - Dependencies
    let recipientName: String
    let styleHint: String?
    let llm: LLMClient

    // MARK: - AgentAction Implementation
    
    /// Generates the good morning message.
    ///
    /// - Returns: `AgentActionResult.text` containing the generated message
    /// - Throws: Errors from LLM API or network issues
    ///
    /// **Note**: The actual message generation happens in `LLMClient.generateGoodMorningMessagePayload`.
    /// This action just coordinates the call and returns the result.
    func run() async throws -> AgentActionResult {
        let result = try await llm.generateGoodMorningMessagePayload(
            to: recipientName,
            styleHint: styleHint
        )
        // We return only the text; AgentController will capture debug via type inspection
        return .text(result.message)
    }
}
