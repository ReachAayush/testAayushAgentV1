import SwiftUI
import UIKit

/// View for generating responses to recently received text messages.
///
/// **Purpose**: Provides a user-friendly interface for:
/// 1. Selecting a contact (or entering phone number)
/// 2. Inputting the recent message received
/// 3. Optionally providing conversation history
/// 4. Generating and sending an appropriate response
///
/// **Architecture**: Follows the same pattern as `GoodMorningView` - a feature-specific
/// view that coordinates with `AgentController` to execute actions.
struct RespondToTextView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var agent: AgentController
    @ObservedObject var favorites: FavoriteContactsStore
    @ObservedObject var toneStore: ToneProfileStore
    
    @AppStorage("SelectedFavoriteContactID") private var selectedFavoriteID: String = ""
    @State private var recentMessage: String = ""
    @State private var conversationHistory: String = ""
    @State private var contactContext: String = ""
    @State private var showingContactPicker = false
    @State private var customPhoneNumber: String = ""
    @State private var customName: String = ""
    @State private var useCustomContact = false
    
    private var selectedFavorite: FavoriteContact? {
        guard !useCustomContact, let id = UUID(uuidString: selectedFavoriteID) else { return nil }
        return favorites.contacts.first { $0.id == id }
    }
    
    private var senderName: String {
        if useCustomContact {
            return customName.isEmpty ? "Unknown" : customName
        }
        return selectedFavorite?.name ?? "Unknown"
    }
    
    private var senderPhone: String {
        if useCustomContact {
            return customPhoneNumber
        }
        return selectedFavorite?.phone ?? ""
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 50))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("Respond to Text")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SteelersTheme.textPrimary)
                            Text("Generate a response to a recent message")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Contact Selection Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Message From")
                                .font(.headline)
                                .foregroundColor(SteelersTheme.textPrimary)
                            
                            // Toggle between favorite and custom contact
                            Picker("Contact Type", selection: $useCustomContact) {
                                Text("Favorite Contact").tag(false)
                                Text("Custom Contact").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .padding(.bottom, 8)
                            
                            if useCustomContact {
                                // Custom contact input
                                VStack(spacing: 12) {
                                    TextField("Name", text: $customName)
                                        .textFieldStyle(.plain)
                                        .padding()
                                        .background(SteelersTheme.darkGray)
                                        .cornerRadius(12)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    
                                    TextField("Phone Number", text: $customPhoneNumber)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.phonePad)
                                        .padding()
                                        .background(SteelersTheme.darkGray)
                                        .cornerRadius(12)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                }
                            } else {
                                // Favorite contact selection
                                if let favorite = selectedFavorite {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(SteelersTheme.steelersGold.opacity(0.2))
                                                .frame(width: 50, height: 50)
                                            Text(String(favorite.name.prefix(1)))
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(SteelersTheme.steelersGold)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(favorite.name)
                                                .font(.headline)
                                                .foregroundColor(SteelersTheme.textPrimary)
                                            Text(favorite.phone)
                                                .font(.subheadline)
                                                .foregroundColor(SteelersTheme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            showingContactPicker = true
                                        } label: {
                                            Text("Change")
                                                .font(.subheadline)
                                                .foregroundColor(SteelersTheme.steelersGold)
                                        }
                                    }
                                    .padding()
                                    .steelersCard()
                                } else {
                                    Button {
                                        showingContactPicker = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "person.circle.fill")
                                                .font(.title2)
                                            Text("Choose a Contact")
                                                .font(.headline)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                        .foregroundColor(SteelersTheme.steelersGold)
                                        .padding()
                                        .steelersCard()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Recent Message Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Message")
                                .font(.headline)
                                .foregroundColor(SteelersTheme.textPrimary)
                            
                            TextEditor(text: $recentMessage)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(SteelersTheme.darkGray)
                                .cornerRadius(12)
                                .foregroundColor(SteelersTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(.horizontal, 20)
                        
                        // Optional Conversation History
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Conversation History (Optional)")
                                .font(.headline)
                                .foregroundColor(SteelersTheme.textPrimary)
                            
                            Text("Add previous messages for better context")
                                .font(.caption)
                                .foregroundColor(SteelersTheme.textSecondary)
                            
                            TextEditor(text: $conversationHistory)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(SteelersTheme.darkGray)
                                .cornerRadius(12)
                                .foregroundColor(SteelersTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(.horizontal, 20)
                        
                        // Generate Response Button
                        if recentMessage.hasNonEmptyContent {
                            Button {
                                Task {
                                    let historyLines = conversationHistory
                                        .trimmed
                                        .components(separatedBy: .newlines)
                                        .compactMap { $0.trimmed.nonEmptyTrimmed }
                                    
                                    // Get style hint from favorite contact if available
                                    let styleHint: String?
                                    if !useCustomContact, let fav = selectedFavorite {
                                        styleHint = StyleHintHelper.combineWithPrefixes([
                                            (fav.styleHint, nil),
                                            (contactContext as String?, nil),
                                            (toneStore.toneSummary as String?, "Tone profile: ")
                                        ])
                                    } else {
                                        styleHint = StyleHintHelper.combineWithPrefixes([
                                            (contactContext as String?, nil),
                                            (toneStore.toneSummary as String?, "Tone profile: ")
                                        ])
                                    }
                                    
                                    let action = RespondToTextAction(
                                        llm: agent.llmClient,
                                        messagesClient: agent.messagesClient,
                                        senderName: senderName,
                                        senderPhone: senderPhone,
                                        recentMessage: recentMessage.trimmed,
                                        conversationHistory: historyLines.isEmpty ? nil : historyLines,
                                        styleHint: styleHint,
                                        toneProfile: toneStore.toneSummary.nonEmptyTrimmed
                                    )
                                    await agent.run(action: action)
                                }
                            } label: {
                                HStack {
                                    if agent.isBusy {
                                        ProgressView()
                                            .tint(SteelersTheme.textOnGold)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(agent.isBusy ? "Generating..." : "Generate Response")
                                        .fontWeight(.semibold)
                                }
                            }
                            .steelersButton()
                            .padding(.horizontal, 20)
                            .disabled(agent.isBusy)
                        }
                        
                        // Response Display Card
                        if !agent.lastOutput.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Your Response")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Spacer()
                                }
                                
                                Text(agent.lastOutput)
                                    .font(.body)
                                    .foregroundColor(SteelersTheme.textPrimary)
                                    .textSelection(.enabled)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SteelersTheme.darkGray)
                                    .cornerRadius(12)
                                
                                // Send Button
                                if !senderPhone.isEmpty {
                                    Button {
                                        sendCurrentOutputAsMessage()
                                    } label: {
                                        HStack {
                                            Image(systemName: "message.fill")
                                            Text("Send as iMessage")
                                        }
                                    }
                                    .steelersButton()
                                }
                            }
                            .padding()
                            .steelersCard()
                            .padding(.horizontal, 20)
                        }
                        
                        // Error Display
                        if let error = agent.errorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("Error")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(SteelersTheme.textSecondary)
                            }
                            .padding()
                            .steelersCard()
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(SteelersTheme.steelersGold)
                    }
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerView(
                    favorites: favorites,
                    selectedID: $selectedFavoriteID,
                    contactContext: $contactContext,
                    agent: agent
                )
            }
            .onAppear {
                if selectedFavoriteID.isEmpty && !useCustomContact {
                    if let first = favorites.contacts.first {
                        selectedFavoriteID = first.id.uuidString
                        contactContext = first.styleHint ?? ""
                    }
                } else if !useCustomContact, let fav = selectedFavorite {
                    contactContext = fav.styleHint ?? ""
                }
            }
            .onChange(of: selectedFavoriteID) { _, newValue in
                if !useCustomContact, let contactID = UUID(uuidString: newValue),
                   let fav = favorites.contacts.first(where: { $0.id == contactID }) {
                    contactContext = fav.styleHint ?? ""
                } else {
                    contactContext = ""
                }
            }
        }
    }
    
    private func sendCurrentOutputAsMessage() {
        guard !agent.lastOutput.isEmpty, !senderPhone.isEmpty else { return }
        
        // Get the key window's root view controller and find the topmost presented VC
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return
        }
        
        // Find the topmost presented view controller (which would be our fullScreenCover)
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        MessagingController.shared.presentMessageComposer(
            from: topVC,
            to: senderPhone,
            body: agent.lastOutput
        )
    }
}

