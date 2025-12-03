import Foundation

/// Action that generates an appropriate response to a recently received text message.
///
/// **Purpose**: Helps users craft contextually appropriate responses to incoming messages
/// by analyzing the message content and generating a reply that matches the user's tone.
///
/// **Usage**: Typically invoked from `RespondToTextView` where users:
/// 1. Select a contact (or enter phone number)
/// 2. Input the recent message they received
/// 3. Optionally provide conversation history
/// 4. Generate a response
///
/// **Architecture**: Follows the `AgentAction` protocol pattern, keeping business logic
/// separate from UI concerns.
struct RespondToTextAction: AgentAction {
    let id = "respond-to-text"
    let displayName = "Respond to Text"
    let summary = "Generates a contextually appropriate response to a received message."
    
    // MARK: - Dependencies
    let llm: LLMClient
    let messagesClient: MessagesClient
    
    // MARK: - Input Parameters
    let senderName: String
    let senderPhone: String
    let recentMessage: String
    let conversationHistory: [String]?
    let styleHint: String?
    let toneProfile: String?
    
    // MARK: - AgentAction Implementation
    
    func run() async throws -> AgentActionResult {
        // Format the message context for the LLM
        let context = messagesClient.formatMessageContext(
            recentMessage: recentMessage,
            senderName: senderName,
            conversationHistory: conversationHistory
        )
        
        // Build the combined style hint
        let combinedHint = StyleHintHelper.combineWithPrefixes([
            (styleHint, nil),
            (toneProfile, "Tone profile: ")
        ])
        
        // Generate response using LLM
        let response = try await llm.generateTextResponsePayload(
            messageContext: context,
            senderName: senderName,
            styleHint: combinedHint
        )
        
        return .text(response.message)
    }
}

