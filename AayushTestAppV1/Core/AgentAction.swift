//
//  AgentAction.swift
//  AayushTestAppV1
//
//

import Foundation

/// Protocol defining the contract for all agent actions.
///
/// **Purpose**: Provides a uniform interface for executing different types of actions
/// (message generation, calendar operations, text responses, etc.).
///
/// **Architecture**: Protocol-oriented design allows easy extension with new action types
/// without modifying existing code. All actions are executed through `AgentController.run(action:)`.
///
/// **Usage**: Create structs conforming to this protocol for each new feature:
/// ```swift
/// struct MyNewAction: AgentAction {
///     let id = "my-action"
///     let displayName = "My Action"
///     let summary = "Does something useful"
///     func run() async throws -> AgentActionResult { ... }
/// }
/// ```
protocol AgentAction {
    /// Unique identifier for the action (e.g., "hello", "today-schedule").
    var id: String { get }
    
    /// Human-readable name displayed in UI.
    var displayName: String { get }
    
    /// Brief description of what the action does.
    var summary: String { get }
    
    /// Executes the action and returns a result.
    ///
    /// - Returns: `AgentActionResult` containing the action's output
    /// - Throws: Any errors encountered during execution
    ///
    /// **Note**: This method should be pure - it should not have side effects beyond
    /// returning a result. Side effects (like sending messages) should be handled
    /// by the UI layer.
    func run() async throws -> AgentActionResult
}

/// Result type for agent actions.
///
/// **Purpose**: Provides a type-safe way to return action results. Currently supports
/// text output, but can be extended for other types (images, structured data, etc.).
///
/// **Future Extensions**: Consider adding cases like:
/// - `.structured(Data)` for JSON/structured responses
/// - `.media(URL)` for generated images or files
/// - `.composite([AgentActionResult])` for multi-part results
enum AgentActionResult {
    /// Text-based result (most common case).
    case text(String)
}
