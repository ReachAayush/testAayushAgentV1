import SwiftUI
import UIKit

/// Root content view that initializes and wires up all dependencies.
///
/// **Purpose**: Serves as the dependency injection point for the app. Creates and configures:
/// - `LLMClient` with Bedrock credentials
/// - `CalendarClient` for calendar access
/// - `MessagesClient` for message operations
/// - `FavoriteContactsStore` for contact management
/// - `AgentController` to coordinate everything
///
/// **Architecture**: Follows dependency injection pattern. All services are created here
/// and passed down to child views. This makes testing easier and dependencies explicit.
///
/// **Security Note**: API keys are currently hardcoded. In production, these should be:
/// - Stored in `Info.plist` or secure keychain
/// - Loaded from environment variables
/// - Rotated regularly
struct ContentView: View {
    // MARK: - State Objects
    @StateObject private var agent: AgentController
    @StateObject private var favorites: FavoriteContactsStore
    @StateObject private var toneStore = ToneProfileStore()
    
    // MARK: - Initialization
    
    /// Initializes the view and all dependencies.
    ///
    /// **Dependency Graph**:
    /// - `LLMClient` → `AgentController`
    /// - `CalendarClient` → `AgentController`
    /// - `MessagesClient` → `AgentController`
    /// - `FavoriteContactsStore` → `AgentController` + `HomeView`
    init() {
        // MARK: - Bedrock Configuration
        // TODO: Move these into Info.plist or a config file later.
        // SECURITY: API keys should not be hardcoded in production.
        let bedrockApiKey = "<Redacted>"
        let bedrockBaseURL = URL(string: "https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1")!
        let bedrockModelId = "openai.gpt-oss-20b-1:0" // or whichever you've enabled
        
        let llm = LLMClient(
            apiKey: bedrockApiKey,
            baseURL: bedrockBaseURL,
            model: bedrockModelId
        )
        
        let calendar = CalendarClient()
        let messages = MessagesClient()
        let favorites = FavoriteContactsStore()
        _favorites = StateObject(wrappedValue: favorites)
        _agent = StateObject(
            wrappedValue: AgentController(
                llmClient: llm,
                calendarClient: calendar,
                messagesClient: messages,
                favoritesStore: favorites
            )
        )
    }
    
    var body: some View {
        HomeView(
            agent: agent,
            favorites: favorites,
            toneStore: toneStore
        )
    }
}

