//
//  LoggingService.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import Foundation
import os.log

/// Centralized logging service for the application.
///
/// **Purpose**: Provides structured logging with different log levels (debug, info, error)
/// using the unified logging system. Replaces scattered `print()` statements throughout
/// the codebase.
///
/// **Architecture**: Singleton service that wraps `os.log` for efficient, structured logging.
/// Logs are categorized by subsystem for easy filtering in Console.app.
///
/// **Usage**: Use this service instead of `print()` statements for all logging needs.
///
/// **Example**:
/// ```swift
/// LoggingService.shared.debug("Processing action", category: .action)
/// LoggingService.shared.error("Failed to fetch calendar", error: error, category: .calendar)
/// ```
final class LoggingService {
    /// Shared singleton instance.
    static let shared = LoggingService()
    
    /// Main logger instance for the app.
    private let logger: Logger
    
    /// Private initializer to enforce singleton pattern.
    private init() {
        // Use bundle identifier as subsystem
        let subsystem = Bundle.main.bundleIdentifier ?? "com.aayush.agent"
        logger = Logger(subsystem: subsystem, category: "App")
    }
    
    // MARK: - Public API
    
    /// Logs a debug message (only visible in debug builds).
    ///
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Optional category for filtering logs
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    func debug(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        logger.debug("[\(category.rawValue)] \(fileName):\(line) \(function) - \(message)")
        #endif
    }
    
    /// Logs an info message (visible in all builds).
    ///
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Optional category for filtering logs
    func info(_ message: String, category: LogCategory = .general) {
        logger.info("[\(category.rawValue)] \(message)")
    }
    
    /// Logs a warning message.
    ///
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Optional category for filtering logs
    func warning(_ message: String, category: LogCategory = .general) {
        logger.warning("[\(category.rawValue)] \(message)")
    }
    
    /// Logs an error message with optional underlying error.
    ///
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional underlying error to include
    ///   - category: Optional category for filtering logs
    func error(
        _ message: String,
        error: Error? = nil,
        category: LogCategory = .general
    ) {
        if let error = error {
            logger.error("[\(category.rawValue)] \(message) - Error: \(error.localizedDescription)")
        } else {
            logger.error("[\(category.rawValue)] \(message)")
        }
    }
    
    /// Logs an AppError with full context.
    ///
    /// - Parameters:
    ///   - error: The AppError to log
    ///   - category: Optional category for filtering logs
    func logError(_ error: AppError, category: LogCategory = .general) {
        var message = error.userMessage
        
        let underlyingError = error.underlyingError
        if let underlying = underlyingError {
            message += " (Underlying: \(underlying.localizedDescription))"
        }
        
        self.error(message, error: underlyingError, category: category)
    }
}

// MARK: - Log Categories

/// Categories for organizing logs by feature area.
///
/// **Purpose**: Allows filtering logs in Console.app by feature area for easier debugging.
enum LogCategory: String {
    case general = "General"
    case network = "Network"
    case authentication = "Auth"
    case calendar = "Calendar"
    case location = "Location"
    case llm = "LLM"
    case action = "Action"
    case ui = "UI"
    case config = "Config"
    case credential = "Credential"
}
