import SwiftUI

/// Main home screen serving as the navigation hub for all app features.
///
/// **Purpose**: Provides a central location for accessing all app actions:
/// - Hello messages (timezone-aware greetings)
/// - Calendar schedule viewing
/// - Settings (calendar, favorites)
///
/// **Architecture**: Uses full-screen covers for action views and sheets for settings.
/// Follows Instagram-style card-based UI with Steelers theme.
///
/// **Extensibility**: New actions can be added by:
/// 1. Adding a case to `ActionType` enum
/// 2. Creating an `ActionCard` in the UI
/// 3. Adding a case to the `fullScreenCover` switch
/// 4. Creating the corresponding view
struct HomeView: View {
    // MARK: - Observed Objects
    @ObservedObject var agent: AgentController
    @ObservedObject var favorites: FavoriteContactsStore
    
    // MARK: - State
    @State private var showingCalendarSelection = false
    @State private var showingManageFavorites = false
    @State private var showingLLMSettings = false
    
    @State private var selectedAction: AnyHomeAction? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with Steelers branding
                        VStack(spacing: 8) {
                            Text("🏈")
                                .font(.system(size: 60))
                            Text("Aayush Agent")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("Your Personal Assistant")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // Action Cards (Instagram-style)
                        VStack(spacing: 16) {
                            // Actions are driven by the registry for easy extensibility
                            ForEach(ActionRegistry.all) { item in
                                ActionCard(
                                    icon: item.icon,
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    gradientColors: item.gradientColors
                                ) {
                                    selectedAction = item
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingCalendarSelection = true
                        } label: {
                            Image(systemName: "calendar.badge.gear")
                                .foregroundColor(SteelersTheme.steelersGold)
                                .font(.title3)
                        }
                        Button {
                            showingManageFavorites = true
                        } label: {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(SteelersTheme.steelersGold)
                                .font(.title3)
                        }
                        Button {
                            showingLLMSettings = true
                        } label: {
                            Image(systemName: "key.fill")
                                .foregroundColor(SteelersTheme.steelersGold)
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCalendarSelection) {
                CalendarSelectionView(calendarClient: agent.calendarClient)
            }
            .sheet(isPresented: $showingManageFavorites) {
                FavoritesManagementView(store: favorites)
            }
            .sheet(isPresented: $showingLLMSettings) {
                LLMSettingsScreen()
            }
            .fullScreenCover(item: $selectedAction) { action in
                action.buildView(agent, favorites)
            }
        }
    }
}

// MARK: - Action Card Component

/// Reusable card component for displaying action options.
///
/// **Design**: Instagram-style card with gradient icon background, title, subtitle,
/// and chevron indicator. Uses Steelers theme colors.
///
/// **Purpose**: Provides consistent, tappable UI for all actions. Makes it easy to
/// add new actions without duplicating UI code.
struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                // Icon with gradient background
                ZStack {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 60, height: 60)
                    .cornerRadius(16)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(SteelersTheme.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(SteelersTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(SteelersTheme.steelersGold)
                    .font(.title3)
            }
            .padding(20)
            .steelersCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    // Minimal stubs for preview
    let llm = LLMClient(apiKey: "preview", baseURL: URL(string: "https://example.com")!, model: "preview")
    let agent = AgentController(
        llmClient: llm,
        calendarClient: CalendarClient(),
        messagesClient: MessagesClient(),
        favoritesStore: FavoriteContactsStore()
    )
    return HomeView(agent: agent, favorites: FavoriteContactsStore())
}
