//
//  LLMSettingsView.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

/// Settings screen for configuring LLM credentials at runtime.
///
/// **Purpose**: Provides UI for configuring AWS credentials and API keys. Values are
/// stored securely in Keychain (via CredentialManager) for sensitive credentials, and
/// in UserDefaults for non-sensitive configuration.
///
/// **Security**: Sensitive credentials (API keys, AWS keys) are stored in Keychain
/// with encryption. Non-sensitive values (URLs, model IDs) are stored in UserDefaults.
struct LLMSettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    
    // Configuration service and credential manager
    private let configService = ConfigurationService.shared
    private let credentialManager = CredentialManager.shared
    private let logger = LoggingService.shared
    
    // State for form fields (loaded from Keychain/Config on appear)
    @State private var apiKey: String = ""
    @State private var baseURL: String = "https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1"
    @State private var modelID: String = "openai.gpt-oss-20b-1:0"
    @State private var awsAccessKey: String = ""
    @State private var awsSecretKey: String = ""
    @State private var awsRegion: String = "us-west-2"
    
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Authentication Method") {
                    Text("Choose one:")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Section("AWS Credentials (SigV4) - Recommended for Bedrock") {
                    SecureField("AWS Access Key", text: $awsAccessKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: awsAccessKey) { _, newValue in
                            saveCredential(newValue, forKey: .awsAccessKey)
                        }
                    SecureField("AWS Secret Key", text: $awsSecretKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: awsSecretKey) { _, newValue in
                            saveCredential(newValue, forKey: .awsSecretKey)
                        }
                    TextField("AWS Region (e.g., us-west-2)", text: $awsRegion)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: awsRegion) { _, newValue in
                            saveConfig(newValue, forKey: .awsRegion)
                        }
                }
                
                Section("Bearer Token (for OpenAI-compatible gateways)") {
                    SecureField("Bearer token", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, newValue in
                            saveCredential(newValue, forKey: .bedrockApiKey)
                        }
                }
                
                Section("Endpoint Configuration") {
                    TextField("Base URL", text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: baseURL) { _, newValue in
                            saveConfig(newValue, forKey: .bedrockBaseURL)
                        }
                    TextField("Model ID", text: $modelID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: modelID) { _, newValue in
                            saveConfig(newValue, forKey: .bedrockModelID)
                        }
                }
                
                Section(footer: Text("Tip: For standard AWS Bedrock endpoints, use AWS Credentials (SigV4). For OpenAI-compatible gateways, use Bearer Token. AWS Credentials take precedence if both are provided. Credentials are stored securely in Keychain.").font(.footnote)) {
                    EmptyView()
                }
            }
            .navigationTitle("LLM Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadConfiguration()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads configuration from Keychain and ConfigurationService.
    private func loadConfiguration() {
        apiKey = configService.bedrockApiKey
        baseURL = configService.bedrockBaseURL
        modelID = configService.bedrockModelID
        awsAccessKey = configService.awsAccessKey
        awsSecretKey = configService.awsSecretKey
        awsRegion = configService.awsRegion
        
        logger.debug("Loaded configuration for LLM settings", category: .config)
    }
    
    /// Saves a sensitive credential to Keychain.
    private func saveCredential(_ value: String, forKey key: ConfigurationService.Key) {
        do {
            try configService.set(value, forKey: key)
            logger.info("Saved \(key.rawValue) to Keychain", category: .credential)
        } catch {
            errorMessage = "Failed to save \(key.rawValue): \(error.localizedDescription)"
            showingError = true
            logger.error("Failed to save credential", error: error, category: .credential)
        }
    }
    
    /// Saves a non-sensitive configuration value.
    private func saveConfig(_ value: String, forKey key: ConfigurationService.Key) {
        do {
            try configService.set(value, forKey: key)
            logger.debug("Saved \(key.rawValue) to configuration", category: .config)
        } catch {
            errorMessage = "Failed to save \(key.rawValue): \(error.localizedDescription)"
            showingError = true
            logger.error("Failed to save configuration", error: error, category: .config)
        }
    }
}

#Preview {
    LLMSettingsScreen()
}
