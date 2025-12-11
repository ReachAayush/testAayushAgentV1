//
//  CredentialManager.swift
//  AayushTestAppV1
//
//

import Foundation
import Security

/// Secure credential storage manager using iOS Keychain.
///
/// **Purpose**: Provides secure storage for sensitive credentials (API keys, AWS keys)
/// using the iOS Keychain, which encrypts data at rest and provides better security
/// than UserDefaults or plist files.
///
/// **Architecture**: Singleton service that abstracts Keychain operations. All credential
/// access should go through this manager to ensure consistent security practices.
///
/// **Security**: Uses `kSecClassGenericPassword` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
/// for maximum security. Credentials are encrypted by the system and only accessible when
/// the device is unlocked.
final class CredentialManager {
    /// Shared singleton instance.
    static let shared = CredentialManager()
    
    /// Service identifier for Keychain items (acts as a namespace).
    private let service = "com.aayush.agent.credentials"
    
    /// Private initializer to enforce singleton pattern.
    private init() {}
    
    // MARK: - Public API
    
    /// Stores a credential securely in the Keychain.
    ///
    /// - Parameters:
    ///   - value: The credential value to store
    ///   - key: The key identifier for the credential
    /// - Throws: `CredentialError` if storage fails
    ///
    /// **Example**:
    /// ```swift
    /// try CredentialManager.shared.store("my-api-key", forKey: "BEDROCK_API_KEY")
    /// ```
    func store(_ value: String, forKey key: String) throws {
        // TODO: OPERATIONAL METRICS - Track credential storage operations
        // Metrics to emit:
        // - credential.store.initiated (counter) - credential storage attempts
        // - credential.store.key (counter) - storage by key type
        // For now: logger.debug("Credential store initiated: key=\(key)", category: .credential)
        let logger = LoggingService.shared
        logger.debug("Credential store initiated: key=\(key)", category: .credential)
        guard let data = value.data(using: .utf8) else {
            throw CredentialError.invalidData
        }
        
        // Delete existing item if present
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            // TODO: OPERATIONAL METRICS - Track credential storage failures
            // Metrics to emit:
            // - credential.store.failure (counter) - storage failures
            // - credential.store.error.status (counter) - Keychain error status codes
            // For now: logger.debug("Credential store failed: key=\(key), status=\(status)", category: .credential)
            logger.debug("Credential store failed: key=\(key), status=\(status)", category: .credential)
            throw CredentialError.storageFailed(status: status)
        }
        
        // TODO: OPERATIONAL METRICS - Track credential storage success
        // Metrics to emit:
        // - credential.store.success (counter) - successful storage operations
        // For now: logger.debug("Credential store succeeded: key=\(key)", category: .credential)
        logger.debug("Credential store succeeded: key=\(key)", category: .credential)
    }
    
    /// Retrieves a credential from the Keychain.
    ///
    /// - Parameter key: The key identifier for the credential
    /// - Returns: The stored credential value, or `nil` if not found
    /// - Throws: `CredentialError` if retrieval fails
    ///
    /// **Example**:
    /// ```swift
    /// let apiKey = try CredentialManager.shared.retrieve(forKey: "BEDROCK_API_KEY")
    /// ```
    func retrieve(forKey key: String) throws -> String? {
        // TODO: OPERATIONAL METRICS - Track credential retrieval operations
        // Metrics to emit:
        // - credential.retrieve.initiated (counter) - credential retrieval attempts
        // - credential.retrieve.key (counter) - retrieval by key type
        // For now: logger.debug("Credential retrieve initiated: key=\(key)", category: .credential)
        let logger = LoggingService.shared
        logger.debug("Credential retrieve initiated: key=\(key)", category: .credential)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                // TODO: OPERATIONAL METRICS - Track credential retrieval data errors
                // Metrics to emit:
                // - credential.retrieve.error.invalid_data (counter) - invalid data errors
                // For now: logger.debug("Credential retrieve failed: key=\(key), error=invalid_data", category: .credential)
                logger.debug("Credential retrieve failed: key=\(key), error=invalid_data", category: .credential)
                throw CredentialError.invalidData
            }
            // TODO: OPERATIONAL METRICS - Track credential retrieval success
            // Metrics to emit:
            // - credential.retrieve.success (counter) - successful retrievals
            // For now: logger.debug("Credential retrieve succeeded: key=\(key)", category: .credential)
            logger.debug("Credential retrieve succeeded: key=\(key)", category: .credential)
            return value
            
        case errSecItemNotFound:
            // TODO: OPERATIONAL METRICS - Track credential not found
            // Metrics to emit:
            // - credential.retrieve.not_found (counter) - credentials not found
            // For now: logger.debug("Credential not found: key=\(key)", category: .credential)
            logger.debug("Credential not found: key=\(key)", category: .credential)
            return nil
            
        default:
            // TODO: OPERATIONAL METRICS - Track credential retrieval failures
            // Metrics to emit:
            // - credential.retrieve.failure (counter) - retrieval failures
            // - credential.retrieve.error.status (counter) - Keychain error status codes
            // For now: logger.debug("Credential retrieve failed: key=\(key), status=\(status)", category: .credential)
            logger.debug("Credential retrieve failed: key=\(key), status=\(status)", category: .credential)
            throw CredentialError.retrievalFailed(status: status)
        }
    }
    
    /// Deletes a credential from the Keychain.
    ///
    /// - Parameter key: The key identifier for the credential to delete
    /// - Returns: `true` if the item was deleted, `false` if it didn't exist
    ///
    /// **Note**: This method is idempotent - safe to call even if the item doesn't exist.
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Checks if a credential exists in the Keychain.
    ///
    /// - Parameter key: The key identifier to check
    /// - Returns: `true` if the credential exists, `false` otherwise
    func exists(forKey key: String) -> Bool {
        do {
            return try retrieve(forKey: key) != nil
        } catch {
            return false
        }
    }
    
    /// Deletes all stored credentials (useful for logout/reset).
    ///
    /// **Warning**: This will remove all credentials stored by this manager.
    func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Credential Errors

/// Errors that can occur during credential operations.
enum CredentialError: LocalizedError {
    case invalidData
    case storageFailed(status: OSStatus)
    case retrievalFailed(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid credential data format"
        case .storageFailed(let status):
            return "Failed to store credential in Keychain (status: \(status))"
        case .retrievalFailed(let status):
            return "Failed to retrieve credential from Keychain (status: \(status))"
        }
    }
}
