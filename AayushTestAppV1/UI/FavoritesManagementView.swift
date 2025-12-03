import SwiftUI

struct FavoritesManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FavoriteContactsStore

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
        }
    }
}

