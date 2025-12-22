//
//  AppError.swift
//  AayushTestAppV1
//
//

import Foundation

/// Centralized error type for the application.
///
/// **Purpose**: Provides structured, categorized error types that can be easily
/// handled, logged, and displayed to users. Replaces ad-hoc NSError usage throughout
/// the codebase.
///
/// **Architecture**: Enum-based error system that categorizes errors by domain
/// (network, permissions, validation, etc.) while preserving underlying error details.
///
/// **Usage**: Services should throw `AppError` instances instead of generic NSErrors.
/// Controllers can then handle errors consistently and provide user-friendly messages.
enum AppError: LocalizedError {
    // MARK: - Network Errors
    
    /// Network request failed (connection, timeout, etc.)
    case networkError(underlying: Error)
    
    /// HTTP error with specific status code
    case httpError(statusCode: Int, message: String?)
    
    /// Invalid or malformed response from server
    case invalidResponse(underlying: Error?)
    
    /// Operation timed out
    case timeout
    
    // MARK: - Authentication Errors
    
    /// Missing or invalid credentials
    case authenticationFailed(reason: String)
    
    /// Credential storage/retrieval failed
    case credentialError(underlying: Error)
    
    // MARK: - Permission Errors
    
    /// Calendar access denied or not available
    case calendarAccessDenied
    
    /// Location access denied or not available
    case locationAccessDenied
    
    /// Contacts access denied or not available
    case contactsAccessDenied
    
    /// Messages access denied or not available
    case messagesAccessDenied
    
    // MARK: - Validation Errors
    
    /// Invalid input data
    case invalidInput(field: String, reason: String)
    
    /// Missing required configuration
    case missingConfiguration(key: String)
    
    /// Invalid configuration value
    case invalidConfiguration(key: String, value: String?)
    
    // MARK: - Service Errors
    
    /// LLM service error
    case llmError(message: String, underlying: Error?)
    
    /// Calendar service error
    case calendarError(message: String, underlying: Error?)
    
    /// Location service error
    case locationError(message: String, underlying: Error?)
    
    // MARK: - Action Errors
    
    /// Action execution failed
    case actionFailed(action: String, reason: String, underlying: Error?)
    
    // MARK: - Unknown Errors
    
    /// Unexpected or unhandled error
    case unknown(underlying: Error?)
    
    // MARK: - Error Description
    
    var errorDescription: String? {
        switch self {
        // Network
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP error: \(statusCode)"
        case .invalidResponse(let underlying):
            return "Invalid response: \(underlying?.localizedDescription ?? "Unknown error")"
        case .timeout:
            return "Operation timed out"
            
        // Authentication
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .credentialError(let underlying):
            return "Credential error: \(underlying.localizedDescription)"
            
        // Permissions
        case .calendarAccessDenied:
            return "Calendar access denied. Please enable calendar access in Settings."
        case .locationAccessDenied:
            return "Location access denied. Please enable location services in Settings."
        case .contactsAccessDenied:
            return "Contacts access denied. Please enable contacts access in Settings."
        case .messagesAccessDenied:
            return "Messages access denied. This device cannot send messages."
            
        // Validation
        case .invalidInput(let field, let reason):
            return "Invalid \(field): \(reason)"
        case .missingConfiguration(let key):
            return "Missing required configuration: \(key)"
        case .invalidConfiguration(let key, let value):
            return "Invalid configuration for \(key): \(value ?? "nil")"
            
        // Services
        case .llmError(let message, _):
            return "LLM error: \(message)"
        case .calendarError(let message, _):
            return "Calendar error: \(message)"
        case .locationError(let message, _):
            return "Location error: \(message)"
            
        // Actions
        case .actionFailed(let action, let reason, _):
            return "\(action) failed: \(reason)"
            
        // Unknown
        case .unknown(let underlying):
            return underlying?.localizedDescription ?? "An unexpected error occurred"
        }
    }
    
    /// User-friendly error message suitable for display in UI.
    var userMessage: String {
        switch self {
        case .networkError:
            return "Unable to connect. Please check your internet connection and try again."
        case .httpError(let statusCode, _):
            if statusCode == 401 {
                return "Authentication failed. Please check your credentials in Settings."
            } else if statusCode >= 500 {
                return "Server error. Please try again later."
            } else {
                return "Request failed. Please try again."
            }
        case .timeout:
            return "The request took too long. Please try again."
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials in Settings."
        case .calendarAccessDenied:
            return "Calendar access is required. Please enable it in Settings → Privacy & Security → Calendars."
        case .locationAccessDenied:
            return "Location access is required. Please enable it in Settings → Privacy & Security → Location Services."
        case .contactsAccessDenied:
            return "Contacts access is required. Please enable it in Settings → Privacy & Security → Contacts."
        case .missingConfiguration(let key):
            return "Missing configuration: \(key). Please configure this in Settings."
        default:
            return errorDescription ?? "An error occurred. Please try again."
        }
    }
    
    /// Underlying error if available (for logging/debugging).
    var underlyingError: Error? {
        switch self {
        case .networkError(let error):
            return error
        case .invalidResponse(let error):
            return error
        case .credentialError(let error):
            return error
        case .llmError(_, let error):
            return error
        case .calendarError(_, let error):
            return error
        case .locationError(_, let error):
            return error
        case .actionFailed(_, _, let error):
            return error
        case .unknown(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - Error Conversion Helpers

extension AppError {
    /// Creates an `AppError` from any `Error`.
    ///
    /// Useful for converting existing errors to `AppError` in catch blocks.
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Try to extract useful information from NSError
        if let nsError = error as NSError? {
            let domain = nsError.domain
            
            // Map common error domains
            if domain == NSURLErrorDomain {
                return .networkError(underlying: error)
            } else if domain == "LLMClient" {
                return .llmError(message: nsError.localizedDescription, underlying: error)
            } else if domain == "CalendarClient" {
                return .calendarError(message: nsError.localizedDescription, underlying: error)
            } else if domain == "LocationClient" {
                return .locationError(message: nsError.localizedDescription, underlying: error)
            }
        }
        
        return .unknown(underlying: error)
    }
}

