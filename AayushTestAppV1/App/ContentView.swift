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
    
    // Runtime overrides (stored in UserDefaults, synced to Keychain by LLMSettingsView)
    @AppStorage("BEDROCK_API_KEY") private var overrideApiKey: String = ""
    @AppStorage("BEDROCK_BASE_URL") private var overrideBaseURL: String = ""
    @AppStorage("BEDROCK_MODEL_ID") private var overrideModelID: String = ""
    @AppStorage("AWS_ACCESS_KEY") private var overrideAwsAccessKey: String = ""
    @AppStorage("AWS_SECRET_KEY") private var overrideAwsSecretKey: String = ""
    @AppStorage("AWS_REGION") private var overrideAwsRegion: String = ""
    
    // Configuration service
    private let configService = ConfigurationService.shared
    private let logger = LoggingService.shared
    
    // MARK: - Initialization
    
    /// Initializes the view and all dependencies.
    ///
    /// **Dependency Graph**:
    /// - `LLMClient` → `AgentController`
    /// - `CalendarClient` → `AgentController`
    /// - `MessagesClient` → `AgentController`
    /// - `FavoriteContactsStore` → `AgentController` + `HomeView`
    ///
    /// **Configuration**: Uses `ConfigurationService` to load credentials from multiple
    /// sources (Keychain, UserDefaults, Info.plist, AppConfig.plist) with proper priority.
    init() {
        // TODO: OPERATIONAL METRICS - Track app initialization
        // Metrics to emit:
        // - app.init.started (counter) - app initialization attempts
        // - app.init.config_load.duration (histogram) - config loading latency
        // For now: logger.debug("App initialization started", category: .general)
        let config = ConfigurationService.shared
        let logger = LoggingService.shared
        let initStartTime = Date()
        logger.debug("App initialization started", category: .general)
        
        // Load configuration using centralized service
        let bedrockApiKey = config.bedrockApiKey
        let bedrockBaseURLString = config.bedrockBaseURL
        let bedrockModelId = config.bedrockModelID
        let awsAccessKey = config.awsAccessKey
        let awsSecretKey = config.awsSecretKey
        let awsRegion = config.awsRegion

        // Validate configuration
        let missing = config.validateRequiredConfiguration()
        if !missing.isEmpty {
            logger.warning("Missing required configuration: \(missing.map { $0.rawValue }.joined(separator: ", "))", category: .config)
        }

        // Create base URL
        guard let bedrockBaseURL = URL(string: bedrockBaseURLString) else {
            logger.error("Invalid BEDROCK_BASE_URL: \(bedrockBaseURLString)", category: .config)
            // Use default URL as fallback
            let defaultURL = URL(string: "https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1")!
            let llm = LLMClient(
                apiKey: bedrockApiKey,
                baseURL: defaultURL,
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
            return
        }

        // Create LLM client with configuration
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
        
        // TODO: OPERATIONAL METRICS - Track app initialization completion
        // Metrics to emit:
        // - app.init.completed (counter) - successful initializations
        // - app.init.duration (histogram) - initialization latency in milliseconds
        // - app.init.config_status (gauge) - config validation status (0=valid, 1=invalid)
        // For now: logger.debug("App initialization completed: duration=\(duration)ms, configValid=\(missing.isEmpty)", category: .general)
        let initDuration = Date().timeIntervalSince(initStartTime) * 1000 // milliseconds
        logger.debug("App initialization completed: duration=\(String(format: "%.2f", initDuration))ms, configValid=\(missing.isEmpty)", category: .general)
        logger.info("ContentView initialized with configuration", category: .config)
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
    
    /// Rebuilds LLM client when configuration changes.
    ///
    /// **Note**: This method is called when @AppStorage values change. The actual
    /// credential storage happens in `LLMSettingsView`, which syncs to Keychain.
    /// This method reads from ConfigurationService which includes Keychain values.
    private func rebuildLLMFromSettings() {
        // TODO: OPERATIONAL METRICS - Track LLM client reconfiguration
        // Metrics to emit:
        // - config.llm.rebuild.initiated (counter) - LLM client rebuilds
        // - config.llm.rebuild.duration (histogram) - rebuild latency
        // For now: logger.debug("Rebuilding LLM client from updated settings", category: .config)
        let rebuildStartTime = Date()
        logger.debug("Rebuilding LLM client from updated settings", category: .config)
        
        // Sync UserDefaults overrides to ConfigurationService (they'll be stored in Keychain by LLMSettingsView)
        // For now, we read from ConfigurationService which has the correct priority
        let config = ConfigurationService.shared
        
        // Update UserDefaults if values changed (LLMSettingsView will sync to Keychain)
        if !overrideApiKey.isEmpty {
            try? config.set(overrideApiKey, forKey: .bedrockApiKey)
        }
        if !overrideBaseURL.isEmpty {
            try? config.set(overrideBaseURL, forKey: .bedrockBaseURL)
        }
        if !overrideModelID.isEmpty {
            try? config.set(overrideModelID, forKey: .bedrockModelID)
        }
        if !overrideAwsAccessKey.isEmpty {
            try? config.set(overrideAwsAccessKey, forKey: .awsAccessKey)
        }
        if !overrideAwsSecretKey.isEmpty {
            try? config.set(overrideAwsSecretKey, forKey: .awsSecretKey)
        }
        if !overrideAwsRegion.isEmpty {
            try? config.set(overrideAwsRegion, forKey: .awsRegion)
        }
        
        // Read from ConfigurationService (includes Keychain priority)
        let apiKey = config.bedrockApiKey
        let baseURLString = config.bedrockBaseURL
        let modelId = config.bedrockModelID
        let awsAccessKey = config.awsAccessKey
        let awsSecretKey = config.awsSecretKey
        let awsRegion = config.awsRegion
        
        guard let url = URL(string: baseURLString) else {
            logger.error("Invalid BEDROCK_BASE_URL: \(baseURLString)", category: .config)
            return
        }
        
        agent.llmClient = LLMClient(
            apiKey: apiKey,
            baseURL: url,
            model: modelId,
            awsAccessKey: awsAccessKey.isEmpty ? nil : awsAccessKey,
            awsSecretKey: awsSecretKey.isEmpty ? nil : awsSecretKey,
            awsRegion: awsRegion.isEmpty ? nil : awsRegion
        )
        
        // TODO: OPERATIONAL METRICS - Track LLM client rebuild completion
        // Metrics to emit:
        // - config.llm.rebuild.completed (counter) - successful rebuilds
        // - config.llm.rebuild.duration (histogram) - rebuild latency in milliseconds
        // For now: logger.debug("LLM client rebuild completed: duration=\(duration)ms", category: .config)
        let rebuildDuration = Date().timeIntervalSince(rebuildStartTime) * 1000 // milliseconds
        logger.debug("LLM client rebuild completed: duration=\(String(format: "%.2f", rebuildDuration))ms", category: .config)
        logger.info("LLM client rebuilt successfully", category: .config)
    }
}
