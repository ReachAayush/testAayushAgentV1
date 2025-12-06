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
    
    @AppStorage("BEDROCK_API_KEY") private var overrideApiKey: String = ""
    @AppStorage("BEDROCK_BASE_URL") private var overrideBaseURL: String = ""
    @AppStorage("BEDROCK_MODEL_ID") private var overrideModelID: String = ""
    @AppStorage("AWS_ACCESS_KEY") private var overrideAwsAccessKey: String = ""
    @AppStorage("AWS_SECRET_KEY") private var overrideAwsSecretKey: String = ""
    @AppStorage("AWS_REGION") private var overrideAwsRegion: String = ""
    
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
        // Prefer Info.plist, support AppConfig.plist fallback, and allow UserDefaults overrides.
        var appConfig: [String: Any] = [:]
        var appConfigLoaded = false
        if let url = Bundle.main.url(forResource: "AppConfig", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any] {
            appConfig = dict
            appConfigLoaded = true
        } else {
            print("[Config] AppConfig.plist not found in bundle. Ensure it's added to the app target's Copy Bundle Resources.")
        }

        let infoApiKey = Bundle.main.object(forInfoDictionaryKey: "BEDROCK_API_KEY") as? String
        let infoBaseURLString = Bundle.main.object(forInfoDictionaryKey: "BEDROCK_BASE_URL") as? String
        let infoModelId = Bundle.main.object(forInfoDictionaryKey: "BEDROCK_MODEL_ID") as? String
        let infoAwsAccessKey = Bundle.main.object(forInfoDictionaryKey: "AWS_ACCESS_KEY") as? String
        let infoAwsSecretKey = Bundle.main.object(forInfoDictionaryKey: "AWS_SECRET_KEY") as? String
        let infoAwsRegion = Bundle.main.object(forInfoDictionaryKey: "AWS_REGION") as? String

        let defaults = UserDefaults.standard
        let defaultsApiKey = defaults.string(forKey: "BEDROCK_API_KEY")
        let defaultsBaseURLString = defaults.string(forKey: "BEDROCK_BASE_URL")
        let defaultsModelId = defaults.string(forKey: "BEDROCK_MODEL_ID")
        let defaultsAwsAccessKey = defaults.string(forKey: "AWS_ACCESS_KEY")
        let defaultsAwsSecretKey = defaults.string(forKey: "AWS_SECRET_KEY")
        let defaultsAwsRegion = defaults.string(forKey: "AWS_REGION")

        func firstNonEmpty(_ values: [String?], default def: String = "") -> String {
            for v in values { if let s = v, !s.isEmpty { return s } }
            return def
        }

        let bedrockApiKey = firstNonEmpty([
            infoApiKey,
            appConfig["BEDROCK_API_KEY"] as? String,
            defaultsApiKey
        ])

        let bedrockBaseURLString = firstNonEmpty([
            infoBaseURLString,
            appConfig["BEDROCK_BASE_URL"] as? String,
            defaultsBaseURLString
        ], default: "https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1")

        let bedrockModelId = firstNonEmpty([
            infoModelId,
            appConfig["BEDROCK_MODEL_ID"] as? String,
            defaultsModelId
        ], default: "openai.gpt-oss-20b-1:0")

        let awsAccessKey = firstNonEmpty([
            infoAwsAccessKey,
            appConfig["AWS_ACCESS_KEY"] as? String,
            defaultsAwsAccessKey
        ])
        
        let awsSecretKey = firstNonEmpty([
            infoAwsSecretKey,
            appConfig["AWS_SECRET_KEY"] as? String,
            defaultsAwsSecretKey
        ])
        
        let awsRegion = firstNonEmpty([
            infoAwsRegion,
            appConfig["AWS_REGION"] as? String,
            defaultsAwsRegion
        ], default: "us-west-2")

        let bedrockBaseURL = URL(string: bedrockBaseURLString)!

        if bedrockApiKey.isEmpty && (awsAccessKey.isEmpty || awsSecretKey.isEmpty) {
            print("[Config] Neither BEDROCK_API_KEY nor AWS credentials are set. The Hello action will not function until configured.")
            if appConfigLoaded {
                print("[Config] AppConfig.plist is bundled but credentials are empty. Fill AWS credentials or API key in Info.plist, AppConfig.plist, or UserDefaults.")
            }
        }

        let llm = LLMClient(
            apiKey: bedrockApiKey,
            baseURL: bedrockBaseURL,
            model: bedrockModelId,
            awsAccessKey: awsAccessKey.isEmpty ? nil : awsAccessKey,
            awsSecretKey: awsSecretKey.isEmpty ? nil : awsSecretKey,
            awsRegion: awsRegion.isEmpty ? nil : awsRegion
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
            favorites: favorites
        )
        .onAppear { rebuildLLMFromSettings() }
        .onChange(of: overrideApiKey) { _, _ in rebuildLLMFromSettings() }
        .onChange(of: overrideBaseURL) { _, _ in rebuildLLMFromSettings() }
        .onChange(of: overrideModelID) { _, _ in rebuildLLMFromSettings() }
        .onChange(of: overrideAwsAccessKey) { _, _ in rebuildLLMFromSettings() }
        .onChange(of: overrideAwsSecretKey) { _, _ in rebuildLLMFromSettings() }
        .onChange(of: overrideAwsRegion) { _, _ in rebuildLLMFromSettings() }
    }
    
    private func rebuildLLMFromSettings() {
        // Recompute configuration using the same priority: Info.plist → AppConfig.plist → UserDefaults (@AppStorage)
        var appConfig: [String: Any] = [:]
        if let url = Bundle.main.url(forResource: "AppConfig", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any] {
            appConfig = dict
        }
        let infoApiKey = Bundle.main.object(forInfoDictionaryKey: "BEDROCK_API_KEY") as? String
        let infoBaseURLString = Bundle.main.object(forInfoDictionaryKey: "BEDROCK_BASE_URL") as? String
        let infoModelId = Bundle.main.object(forInfoDictionaryKey: "BEDROCK_MODEL_ID") as? String
        let infoAwsAccessKey = Bundle.main.object(forInfoDictionaryKey: "AWS_ACCESS_KEY") as? String
        let infoAwsSecretKey = Bundle.main.object(forInfoDictionaryKey: "AWS_SECRET_KEY") as? String
        let infoAwsRegion = Bundle.main.object(forInfoDictionaryKey: "AWS_REGION") as? String
        
        func firstNonEmpty(_ values: [String?], default def: String = "") -> String {
            for v in values { if let s = v, !s.isEmpty { return s } }
            return def
        }
        let apiKey = firstNonEmpty([
            infoApiKey,
            appConfig["BEDROCK_API_KEY"] as? String,
            overrideApiKey
        ])
        let baseURLString = firstNonEmpty([
            infoBaseURLString,
            appConfig["BEDROCK_BASE_URL"] as? String,
            overrideBaseURL
        ], default: "https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1")
        let modelId = firstNonEmpty([
            infoModelId,
            appConfig["BEDROCK_MODEL_ID"] as? String,
            overrideModelID
        ], default: "openai.gpt-oss-20b-1:0")
        let awsAccessKey = firstNonEmpty([
            infoAwsAccessKey,
            appConfig["AWS_ACCESS_KEY"] as? String,
            overrideAwsAccessKey
        ])
        let awsSecretKey = firstNonEmpty([
            infoAwsSecretKey,
            appConfig["AWS_SECRET_KEY"] as? String,
            overrideAwsSecretKey
        ])
        let awsRegion = firstNonEmpty([
            infoAwsRegion,
            appConfig["AWS_REGION"] as? String,
            overrideAwsRegion
        ], default: "us-west-2")
        
        if let url = URL(string: baseURLString) {
            agent.llmClient = LLMClient(
                apiKey: apiKey,
                baseURL: url,
                model: modelId,
                awsAccessKey: awsAccessKey.isEmpty ? nil : awsAccessKey,
                awsSecretKey: awsSecretKey.isEmpty ? nil : awsSecretKey,
                awsRegion: awsRegion.isEmpty ? nil : awsRegion
            )
        } else {
            print("[Config] Invalid BEDROCK_BASE_URL: \(baseURLString)")
        }
    }
}
