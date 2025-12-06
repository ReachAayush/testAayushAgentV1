import SwiftUI

struct FavoritesManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FavoriteContactsStore
    @State private var editingContact: FavoriteContact?
    @State private var editingTimezone: String = ""
    @State private var showingTimezoneEditor = false

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
                
                List {
                    Section {
                        ForEach(store.contacts) { contact in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 16) {
                                    // Avatar
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
                                }
                                
                                // Timezone Display/Edit
                                HStack {
                                    Text("Timezone:")
                                        .font(.caption)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                    Spacer()
                                    if let tz = contact.timezoneIdentifier, !tz.isEmpty {
                                        Text(tz)
                                            .font(.caption)
                                            .foregroundColor(SteelersTheme.steelersGold)
                                    } else {
                                        Text("Not set")
                                            .font(.caption)
                                            .foregroundColor(SteelersTheme.textSecondary.opacity(0.6))
                                    }
                                    Button {
                                        editingContact = contact
                                        editingTimezone = contact.timezoneIdentifier ?? ""
                                        showingTimezoneEditor = true
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(SteelersTheme.steelersGold)
                                    }
                                }
                                .padding(.top, 4)
                                
                                if let hint = contact.styleHint, !hint.isEmpty {
                                    Divider()
                                        .background(SteelersTheme.steelersGold.opacity(0.3))
                                    
                                    Text("Style Profile")
                                        .font(.caption)
                                        .foregroundColor(SteelersTheme.steelersGold)
                                        .textCase(.uppercase)
                                    
                                    Text(hint)
                                        .font(.caption)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(SteelersTheme.cardBackground)
                        }
                    } header: {
                        Text("Favorite Contacts")
                            .foregroundColor(SteelersTheme.textPrimary)
                    } footer: {
                        Text("Set timezones to enable time-of-day aware greetings (e.g., America/New_York, Europe/London)")
                            .font(.caption)
                            .foregroundColor(SteelersTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundColor(SteelersTheme.steelersGold)
                    }
                }
            }
            .sheet(isPresented: $showingTimezoneEditor) {
                if let contact = editingContact {
                    TimezoneEditorView(
                        contact: contact,
                        timezone: $editingTimezone,
                        store: store
                    )
                }
            }
        }
    }
}

struct TimezoneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let contact: FavoriteContact
    @Binding var timezone: String
    @ObservedObject var store: FavoriteContactsStore
    
    // Common timezones for quick selection
    let commonTimezones = [
        ("America/New_York", "Eastern Time"),
        ("America/Chicago", "Central Time"),
        ("America/Denver", "Mountain Time"),
        ("America/Los_Angeles", "Pacific Time"),
        ("Europe/London", "London"),
        ("Europe/Paris", "Paris"),
        ("Asia/Tokyo", "Tokyo"),
        ("Asia/Shanghai", "Shanghai"),
        ("Australia/Sydney", "Sydney"),
        ("America/Toronto", "Toronto"),
        ("America/Vancouver", "Vancouver"),
        ("Europe/Berlin", "Berlin"),
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Timezone Identifier", text: $timezone)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .foregroundColor(SteelersTheme.textPrimary)
                            .placeholder(when: timezone.isEmpty) {
                                Text("e.g., America/New_York")
                                    .foregroundColor(SteelersTheme.textSecondary.opacity(0.6))
                            }
                    } header: {
                        Text("Timezone")
                            .foregroundColor(SteelersTheme.textPrimary)
                    } footer: {
                        Text("Enter a timezone identifier (IANA format). Leave empty to disable timezone-aware greetings.")
                            .font(.caption)
                            .foregroundColor(SteelersTheme.textSecondary)
                    }
                    
                    Section {
                        ForEach(commonTimezones, id: \.0) { tzID, displayName in
                            Button {
                                timezone = tzID
                            } label: {
                                HStack {
                                    Text(displayName)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Spacer()
                                    if timezone == tzID {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(SteelersTheme.steelersGold)
                                    }
                                    Text(tzID)
                                        .font(.caption)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                }
                            }
                        }
                    } header: {
                        Text("Quick Select")
                            .foregroundColor(SteelersTheme.textPrimary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Timezone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SteelersTheme.steelersGold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let index = store.contacts.firstIndex(where: { $0.id == contact.id }) {
                            store.contacts[index].timezoneIdentifier = timezone.isEmpty ? nil : timezone
                        }
                        dismiss()
                    }
                    .foregroundColor(SteelersTheme.steelersGold)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
