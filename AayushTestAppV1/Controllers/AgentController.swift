//
//  AgentController.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import Combine
import Foundation

/// Main controller for orchestrating agent actions.
///
/// **Purpose**: Coordinates between UI, services, and actions. Handles:
/// - Action execution and result processing
/// - State management (loading, errors, outputs)
/// - Debug logging for development
/// - Style hint management across actions
///
/// **Architecture**: Follows the coordinator pattern - this class doesn't contain
/// business logic itself, but coordinates between services and actions.
@MainActor
final class AgentController: ObservableObject {
    // MARK: - Published State
    @Published var lastOutput: String = ""
    @Published var isBusy: Bool = false
    @Published var errorMessage: String?
    @Published var debugLog: String = ""
    @Published var currentStyleHint: String? = nil
    @Published var contactContextToPreload: String? = nil
    
    // MARK: - Service Dependencies
    /// Mutable to allow runtime reconfiguration of credentials (e.g., when editing LLM settings).
    var llmClient: LLMClient
    let calendarClient: CalendarClient
    let messagesClient: MessagesClient
    let favoritesStore: FavoriteContactsStore
    
    // MARK: - Initialization
    
    init(
        llmClient: LLMClient,
        calendarClient: CalendarClient,
        messagesClient: MessagesClient,
        favoritesStore: FavoriteContactsStore
    ) {
        self.llmClient = llmClient
        self.calendarClient = calendarClient
        self.messagesClient = messagesClient
        self.favoritesStore = favoritesStore
    }
    
    // MARK: - Action Execution
    /// Executes an agent action and updates published state with results.
    ///
    /// **Flow**:
    /// 1. Sets loading state
    /// 2. Executes action-specific logic (or generic `action.run()`)
    /// 3. Updates `lastOutput` with result
    /// 4. Generates debug log
    /// 5. Handles errors
    ///
    /// **Note**: Some actions (HelloMessageAction) have
    /// special handling to capture debug information and style hints.
    func run(action: AgentAction) async {
        startWork()
        defer { endWork() }
        do {
            // Special handling for HelloMessageAction
            if let hello = action as? HelloMessageAction {
                // Find the currently selected favorite contact and pre-load its styleHint
                let selectedFavoriteID = UserDefaults.standard.string(forKey: "SelectedFavoriteContactID") ?? ""
                if let contactID = UUID(uuidString: selectedFavoriteID),
                   let selectedContact = favoritesStore.contacts.first(where: { $0.id == contactID }) {
                    // Pre-load the contact's styleHint into the Contact Context UI box
                    self.contactContextToPreload = selectedContact.styleHint
                }
                
                let hintToUse: String? = {
                    hello.styleHint?.nonEmptyTrimmed ?? currentStyleHint?.nonEmptyTrimmed
                }()
                let result = try await hello.llm.generateHelloMessagePayload(
                    to: hello.recipientName,
                    styleHint: hintToUse,
                    timezoneIdentifier: hello.timezoneIdentifier
                )
                self.lastOutput = result.message
                var debugLines: [String] = []
                let timestamp = ISO8601DateFormatter().string(from: Date())
                debugLines.append("Action: HelloMessageAction")
                debugLines.append("Time: \(timestamp)")
                debugLines.append("Recipient: \(hello.recipientName)")
                if let tz = hello.timezoneIdentifier { debugLines.append("Timezone: \(tz)") }
                if let hint = hintToUse, !hint.isEmpty { debugLines.append("Style hint: \(hint)") }
                if let dbg = result.debug, !dbg.isEmpty { debugLines.append("LLM Debug: \(dbg)") }
                debugLines.append("")
                debugLines.append("Prompt Sent:")
                debugLines.append(result.prompt)
                self.debugLog = debugLines.joined(separator: "\n")
                return
            }
            
            // Default path for other actions
            let result = try await action.run()
            switch result {
            case .text(let text):
                self.lastOutput = text
            }

            var debugLines: [String] = []
            debugLines.append("Action: \(type(of: action))")
            let timestamp = ISO8601DateFormatter().string(from: Date())
            debugLines.append("Time: \(timestamp)")
            if let sched = action as? TodayScheduleSummaryAction {
                if let allowed = sched.allowedCalendarIDs, !allowed.isEmpty {
                    debugLines.append("Calendars: \(allowed.joined(separator: ", "))")
                } else {
                    debugLines.append("Calendars: All")
                }
            }
            self.debugLog = debugLines.joined(separator: "\n")
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Private Helpers
    
    /// Sets the controller to busy state and clears any previous errors.
    private func startWork() {
        isBusy = true
        errorMessage = nil
    }
    
    /// Clears the busy state.
    private func endWork() {
        isBusy = false
    }
}

