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
        // FIX: Explicitly define the type of the 'continuation' parameter
        // as CheckedContinuation<Void, Error> to resolve the inference issue T.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            contactStore.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if !granted {
                    let err = NSError(
                        domain: "MessagesClient",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Contacts access denied by user"]
                    )
                    continuation.resume(throwing: err)
                } else {
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
        
        // Normalize phone number (remove non-digits)
        let normalized = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        var foundContact: CNContact?
        
        try contactStore.enumerateContacts(with: request) { contact, stop in
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
