//
//  MessagesClient.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import Foundation
import Contacts

/// Service for managing message-related operations.
///
/// **Note**: iOS privacy restrictions prevent direct access to the Messages database.
/// This client provides utilities for working with message context that users provide.
///
/// **Architecture**: Follows the same pattern as `CalendarClient` - a service layer
/// that handles data access and permissions.
final class MessagesClient {
    private let contactStore = CNContactStore()
    
    /// Requests contacts access if needed.
    /// - Throws: Error if access is denied
    func requestContactsAccessIfNeeded() async throws {
        // TODO: OPERATIONAL METRICS - Track contacts permission requests
        // Metrics to emit:
        // - contacts.permission.request (counter) - permission request attempts
        // For now: logger.debug("Contacts permission request initiated", category: .general)
        let logger = LoggingService.shared
        logger.debug("Contacts permission request initiated", category: .general)
        
        // FIX: Explicitly define the type of the 'continuation' parameter
        // as CheckedContinuation<Void, Error> to resolve the inference issue T.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            contactStore.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    // TODO: OPERATIONAL METRICS - Track contacts permission errors
                    // Metrics to emit:
                    // - contacts.permission.error (counter) - permission request errors
                    // For now: logger.debug("Contacts permission request error: errorType=\(type(of: error))", category: .general)
                    logger.debug("Contacts permission request error: errorType=\(type(of: error))", category: .general)
                    continuation.resume(throwing: error)
                } else if !granted {
                    // TODO: OPERATIONAL METRICS - Track contacts permission denials
                    // Metrics to emit:
                    // - contacts.permission.denied (counter) - permission denials
                    // For now: logger.debug("Contacts permission denied by user", category: .general)
                    logger.debug("Contacts permission denied by user", category: .general)
                    let err = NSError(
                        domain: "MessagesClient",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Contacts access denied by user"]
                    )
                    continuation.resume(throwing: err)
                } else {
                    // TODO: OPERATIONAL METRICS - Track contacts permission grants
                    // Metrics to emit:
                    // - contacts.permission.granted (counter) - permission grants
                    // For now: logger.debug("Contacts permission granted", category: .general)
                    logger.debug("Contacts permission granted", category: .general)
                    continuation.resume()
                }
            }
        }
    }
    
    /// Searches for a contact by phone number.
    /// - Parameter phoneNumber: The phone number to search for (normalized)
    /// - Returns: The contact's name if found, nil otherwise
    func findContactName(by phoneNumber: String) async throws -> String? {
        try await requestContactsAccessIfNeeded()
        
        // TODO: OPERATIONAL METRICS - Track contact lookup initiation
        // Metrics to emit:
        // - contacts.lookup.initiated (counter) - contact lookup attempts
        // For now: logger.debug("Contact lookup initiated: phoneNumber=\(phoneNumber.prefix(4))****", category: .general)
        let logger = LoggingService.shared
        let lookupStartTime = Date()
        logger.debug("Contact lookup initiated: phoneNumber=\(phoneNumber.prefix(4))****", category: .general)
        
        // Normalize phone number (remove non-digits)
        let normalized = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        var foundContact: CNContact?
        var contactsScanned = 0
        
        try contactStore.enumerateContacts(with: request) { contact, stop in
            contactsScanned += 1
            for phone in contact.phoneNumbers {
                let contactNumber = phone.value.stringValue
                    .components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                
                if contactNumber == normalized || contactNumber.hasSuffix(normalized) || normalized.hasSuffix(contactNumber) {
                    foundContact = contact
                    stop.pointee = true
                    return
                }
            }
        }
        
        // TODO: OPERATIONAL METRICS - Track contact lookup results
        // Metrics to emit:
        // - contacts.lookup.duration (histogram) - lookup latency in milliseconds
        // - contacts.lookup.contacts_scanned (histogram) - number of contacts scanned
        // - contacts.lookup.success (counter) - successful lookups
        // - contacts.lookup.not_found (counter) - lookups that didn't find a match
        // For now: logger.debug("Contact lookup completed: duration=\(duration)ms, contactsScanned=\(contactsScanned), found=\(foundContact != nil)", category: .general)
        let lookupDuration = Date().timeIntervalSince(lookupStartTime) * 1000 // milliseconds
        logger.debug("Contact lookup completed: duration=\(String(format: "%.2f", lookupDuration))ms, contactsScanned=\(contactsScanned), found=\(foundContact != nil)", category: .general)
        
        guard let contact = foundContact else { return nil }
        
        let fullName = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return fullName.isEmpty ? nil : fullName
    }
    
    /// Formats a message thread for LLM context.
    /// - Parameters:
    ///   - recentMessage: The most recent message received
    ///   - senderName: Name of the message sender
    ///   - conversationHistory: Optional previous messages for context
    /// - Returns: Formatted string ready for LLM prompt
    func formatMessageContext(
        recentMessage: String,
        senderName: String,
        conversationHistory: [String]? = nil
    ) -> String {
        var context = "RECENT MESSAGE FROM \(senderName.uppercased()):\n\(recentMessage)\n"
        
        if let history = conversationHistory, !history.isEmpty {
            context += "\nCONVERSATION HISTORY:\n"
            for (index, msg) in history.enumerated() {
                context += "\(index + 1). \(msg)\n"
            }
        }
        
        return context
    }
}
