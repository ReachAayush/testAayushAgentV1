import SwiftUI
import UIKit

struct HelloView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var agent: AgentController
    @ObservedObject var favorites: FavoriteContactsStore
    
    @AppStorage("SelectedFavoriteContactID") private var selectedFavoriteID: String = ""
    @State private var contactContext: String = ""
    @State private var showingContactPicker = false
    
    private var selectedFavorite: FavoriteContact? {
        guard let id = UUID(uuidString: selectedFavoriteID) else { return nil }
        return favorites.contacts.first { $0.id == id }
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
                            Image(systemName: "hand.wave.fill")
                                .font(.system(size: 50))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("Hello Message")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SteelersTheme.textPrimary)
                            Text("Send a personalized greeting")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Contact Selection Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Recipient")
                                .font(.headline)
                                .foregroundColor(SteelersTheme.textPrimary)
                            
                            if let favorite = selectedFavorite {
                                // Selected contact display
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
                                        if let tz = favorite.timezoneIdentifier {
                                            Text("Timezone: \(tz)")
                                                .font(.caption)
                                                .foregroundColor(SteelersTheme.steelersGold.opacity(0.8))
                                        }
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
                        .padding(.horizontal, 20)
                        
                        // Generate Button
                        if selectedFavorite != nil {
                            Button {
                                Task {
                                    guard let fav = selectedFavorite else { return }
                                    
                                    if !contactContext.hasNonEmptyContent,
                                       let styleHint = fav.styleHint?.nonEmptyTrimmed {
                                        contactContext = styleHint
                                    }
                                    
                                    let combinedHint = StyleHintHelper.combineWithPrefixes([
                                        (contactContext as String?, nil)
                                    ])
                                    
                                    let action = HelloMessageAction(
                                        recipientName: fav.name,
                                        styleHint: (combinedHint ?? "").isEmpty ? nil : combinedHint,
                                        timezoneIdentifier: fav.timezoneIdentifier,
                                        llm: agent.llmClient
                                    )
                                    await agent.run(action: action)
                                    agent.currentStyleHint = contactContext
                                }
                            } label: {
                                HStack {
                                    if agent.isBusy {
                                        ProgressView()
                                            .tint(SteelersTheme.textOnGold)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(agent.isBusy ? "Generating..." : "Generate Message")
                                        .fontWeight(.semibold)
                                }
                            }
                            .steelersButton()
                            .padding(.horizontal, 20)
                            .disabled(agent.isBusy)
                        }
                        
                        // Message Display Card
                        if !agent.lastOutput.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Your Message")
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
                if selectedFavoriteID.isEmpty {
                    if let savannah = favorites.contacts.first(where: { $0.name == "Savannah Milford" }) {
                        selectedFavoriteID = savannah.id.uuidString
                        contactContext = savannah.styleHint ?? ""
                        agent.currentStyleHint = savannah.styleHint
                    }
                } else {
                    if let fav = selectedFavorite {
                        contactContext = fav.styleHint ?? ""
                        agent.currentStyleHint = fav.styleHint
                    }
                }
            }
            .onChange(of: selectedFavoriteID) { _, newValue in
                if let contactID = UUID(uuidString: newValue),
                   let fav = favorites.contacts.first(where: { $0.id == contactID }) {
                    agent.currentStyleHint = fav.styleHint
                    contactContext = fav.styleHint ?? ""
                } else {
                    agent.currentStyleHint = nil
                    contactContext = ""
                }
            }
        }
    }
    
    private func sendCurrentOutputAsMessage() {
        guard !agent.lastOutput.isEmpty else { return }
        guard let fav = selectedFavorite else { return }
        
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
            to: fav.phone,
            body: agent.lastOutput
        )
    }
}

// Contact Picker Sheet
struct ContactPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var favorites: FavoriteContactsStore
    @Binding var selectedID: String
    @Binding var contactContext: String
    @ObservedObject var agent: AgentController
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                List {
                    ForEach(favorites.contacts) { contact in
                        Button {
                            selectedID = contact.id.uuidString
                            contactContext = contact.styleHint ?? ""
                            agent.currentStyleHint = contact.styleHint
                            dismiss()
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(SteelersTheme.steelersGold.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    Text(String(contact.name.prefix(1)))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(SteelersTheme.steelersGold)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.name)
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Text(contact.phone)
                                        .font(.subheadline)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                if selectedID == contact.id.uuidString {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(SteelersTheme.steelersGold)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(SteelersTheme.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SteelersTheme.steelersGold)
                }
            }
        }
    }
}

#Preview("HelloView Preview") {
    let llm = LLMClient(apiKey: "preview", baseURL: URL(string: "https://example.com")!, model: "preview")
    let agent = AgentController(
        llmClient: llm,
        calendarClient: CalendarClient(),
        messagesClient: MessagesClient(),
        favoritesStore: FavoriteContactsStore()
    )
    return HelloView(agent: agent, favorites: FavoriteContactsStore())
}
