//
//  ConfigurationService.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import Foundation

/// Centralized configuration management service.
///
/// **Purpose**: Provides a single source of truth for application configuration,
/// consolidating configuration from multiple sources (Info.plist, AppConfig.plist,
/// UserDefaults, Keychain) with a clear priority order.
///
/// **Architecture**: Singleton service that handles configuration loading and validation.
/// Supports runtime configuration updates and provides type-safe access to config values.
///
/// **Priority Order** (highest to lowest):
/// 1. Keychain (via CredentialManager) - for sensitive credentials
/// 2. UserDefaults (@AppStorage) - for runtime user preferences
/// 3. Info.plist - for build-time configuration
/// 4. AppConfig.plist - for bundled configuration
/// 5. Hardcoded defaults - fallback values
final class ConfigurationService {
    /// Shared singleton instance.
    static let shared = ConfigurationService()
    
    /// Credential manager for secure storage.
    private let credentialManager = CredentialManager.shared
    
    /// Logger for configuration operations.
    private let logger = LoggingService.shared
    
    /// Private initializer to enforce singleton pattern.
    private init() {}
    
    // MARK: - Configuration Keys
    
    /// Configuration keys used throughout the app.
    enum Key: String {
        case bedrockApiKey = "BEDROCK_API_KEY"
        case bedrockBaseURL = "BEDROCK_BASE_URL"
        case bedrockModelID = "BEDROCK_MODEL_ID"
        case awsAccessKey = "AWS_ACCESS_KEY"
        case awsSecretKey = "AWS_SECRET_KEY"
        case awsRegion = "AWS_REGION"
        case spoonacularApiKey = "SPOONACULAR_API_KEY"
    }
    
    // MARK: - Public API
    
    /// Retrieves a configuration value with priority order.
    ///
    /// **Priority Order**:
    /// 1. Keychain (for sensitive keys: API keys, AWS credentials)
    /// 2. UserDefaults
    /// 3. Info.plist
    /// 4. AppConfig.plist
    /// 5. Default value
    ///
    /// - Parameters:
    ///   - key: The configuration key
    ///   - defaultValue: Fallback value if not found in any source
    /// - Returns: The configuration value, or default if not found
    func get(_ key: Key, default defaultValue: String = "") -> String {
        // TODO: OPERATIONAL METRICS - Track configuration access
        // Metrics to emit:
        // - config.access (counter) - configuration value accesses
        // - config.source (counter) - source used (keychain, userdefaults, infoplist, appconfig, default)
        // For now: logger.debug("Config access: key=\(key.rawValue)", category: .config)
        // 1. Check Keychain first (for sensitive credentials)
        if isSensitiveKey(key) {
            if let value = try? credentialManager.retrieve(forKey: key.rawValue), !value.isEmpty {
                logger.debug("Retrieved \(key.rawValue) from Keychain", category: .config)
                return value
            }
        }
        
        // 2. Check UserDefaults
        if let value = UserDefaults.standard.string(forKey: key.rawValue), !value.isEmpty {
            logger.debug("Retrieved \(key.rawValue) from UserDefaults", category: .config)
            return value
        }
        
        // 3. Check Info.plist
        if let value = Bundle.main.object(forInfoDictionaryKey: key.rawValue) as? String, !value.isEmpty {
            logger.debug("Retrieved \(key.rawValue) from Info.plist", category: .config)
            return value
        }
        
        // 4. Check AppConfig.plist
        if let value = loadFromAppConfig(key.rawValue), !value.isEmpty {
            logger.debug("Retrieved \(key.rawValue) from AppConfig.plist", category: .config)
            return value
        }
        
        // 5. Return default
        logger.debug("Using default value for \(key.rawValue)", category: .config)
        return defaultValue
    }
    
    /// Sets a configuration value (stores in appropriate location based on key type).
    ///
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The configuration key
    /// - Throws: Error if storage fails
    func set(_ value: String, forKey key: Key) throws {
        if isSensitiveKey(key) {
            // Store sensitive credentials in Keychain
            try credentialManager.store(value, forKey: key.rawValue)
            logger.info("Stored \(key.rawValue) in Keychain", category: .config)
        } else {
            // Store non-sensitive config in UserDefaults
            UserDefaults.standard.set(value, forKey: key.rawValue)
            logger.info("Stored \(key.rawValue) in UserDefaults", category: .config)
        }
    }
    
    /// Validates that required configuration is present.
    ///
    /// - Returns: Array of missing required keys, empty if all present
    func validateRequiredConfiguration() -> [Key] {
        // TODO: OPERATIONAL METRICS - Track configuration validation
        // Metrics to emit:
        // - config.validation.initiated (counter) - validation attempts
        // - config.validation.missing_keys (histogram) - number of missing keys
        // - config.validation.status (gauge) - validation status (0=valid, 1=invalid)
        // For now: logger.debug("Config validation initiated", category: .config)
        logger.debug("Config validation initiated", category: .config)
        
        var missing: [Key] = []
        
        // Check if we have either AWS credentials OR API key
        let hasAwsCredentials = !get(.awsAccessKey).isEmpty && !get(.awsSecretKey).isEmpty
        let hasApiKey = !get(.bedrockApiKey).isEmpty
        
        if !hasAwsCredentials && !hasApiKey {
            missing.append(.bedrockApiKey)
            missing.append(.awsAccessKey)
            missing.append(.awsSecretKey)
        }
        
        // Check base URL
        if get(.bedrockBaseURL).isEmpty {
            missing.append(.bedrockBaseURL)
        }
        
        // Check model ID
        if get(.bedrockModelID).isEmpty {
            missing.append(.bedrockModelID)
        }
        
        if !missing.isEmpty {
            // TODO: OPERATIONAL METRICS - Track configuration validation failures
            // Metrics to emit:
            // - config.validation.failure (counter) - validation failures
            // - config.validation.missing_keys.count (histogram) - number of missing keys
            // For now: logger.debug("Config validation failed: missingKeys=\(missing.count)", category: .config)
            logger.debug("Config validation failed: missingKeys=\(missing.count)", category: .config)
            logger.warning("Missing required configuration: \(missing.map { $0.rawValue }.joined(separator: ", "))", category: .config)
        } else {
            // TODO: OPERATIONAL METRICS - Track configuration validation success
            // Metrics to emit:
            // - config.validation.success (counter) - validation successes
            // For now: logger.debug("Config validation succeeded", category: .config)
            logger.debug("Config validation succeeded", category: .config)
        }
        
        return missing
    }
    
    // MARK: - Convenience Methods
    
    /// Gets Bedrock API key (from Keychain or fallback sources).
    var bedrockApiKey: String {
        return get(.bedrockApiKey)
    }
    
    /// Gets Bedrock base URL with default fallback.
    var bedrockBaseURL: String {
        return get(.bedrockBaseURL, default: "https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1")
    }
    
    /// Gets Bedrock model ID with default fallback.
    var bedrockModelID: String {
        return get(.bedrockModelID, default: "openai.gpt-oss-20b-1:0")
    }
    
    /// Gets AWS access key (from Keychain or fallback sources).
    var awsAccessKey: String {
        return get(.awsAccessKey)
    }
    
    /// Gets AWS secret key (from Keychain or fallback sources).
    var awsSecretKey: String {
        return get(.awsSecretKey)
    }
    
    /// Gets AWS region with default fallback.
    var awsRegion: String {
        return get(.awsRegion, default: "us-west-2")
    }
    
    /// Gets Spoonacular API key (from Keychain or fallback sources).
    var spoonacularApiKey: String {
        return get(.spoonacularApiKey)
    }
    
    // MARK: - Private Helpers
    
    /// Checks if a key should be stored in Keychain (sensitive credentials).
    private func isSensitiveKey(_ key: Key) -> Bool {
        switch key {
        case .bedrockApiKey, .awsAccessKey, .awsSecretKey, .spoonacularApiKey:
            return true
        default:
            return false
        }
    }
    
    /// Loads a value from AppConfig.plist if available.
    private func loadFromAppConfig(_ key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "AppConfig", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let value = dict[key] as? String else {
            return nil
        }
        return value
    }
}
