import SwiftUI

/// Main home screen serving as the navigation hub for all app features.
///
/// **Purpose**: Provides a central location for accessing all app actions:
/// - Good Morning messages
/// - Calendar schedule viewing
/// - Day summaries
/// - Text response generation
/// - Settings (calendar, favorites, tone training)
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
    @ObservedObject var toneStore: ToneProfileStore
    
    // MARK: - State
    @State private var showingCalendarSelection = false
    @State private var showingManageFavorites = false
    @State private var showingToneTrainer = false
    
    @State private var selectedAction: ActionType? = nil
    
    /// Enumeration of available actions in the app.
    /// 
    /// **Purpose**: Type-safe action identification for navigation.
    /// **Extensibility**: Add new cases here and corresponding views in the switch statement.
    enum ActionType {
        case goodMorning
        case todaySchedule
        case summarizeDay
        case respondToText
        // Future actions can be added here:
        // case scheduleMessage
        // case analyzeConversation
        // case generateEmail
    }
    
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
                            // Good Morning Message Card
                            ActionCard(
                                icon: "sunrise.fill",
                                title: "Good Morning",
                                subtitle: "Send a personalized morning message",
                                gradientColors: [SteelersTheme.steelersGold, SteelersTheme.goldAccent]
                            ) {
                                selectedAction = .goodMorning
                            }
                            
                            // Today's Schedule Card
                            ActionCard(
                                icon: "calendar",
                                title: "Today's Schedule",
                                subtitle: "View your calendar for today",
                                gradientColors: [SteelersTheme.darkGray, SteelersTheme.steelersBlack]
                            ) {
                                selectedAction = .todaySchedule
                            }
                            
                            // Summarize Day Card
                            ActionCard(
                                icon: "doc.text.fill",
                                title: "Summarize Day",
                                subtitle: "Get an AI summary of your day",
                                gradientColors: [SteelersTheme.steelersGold.opacity(0.8), SteelersTheme.darkGray]
                            ) {
                                selectedAction = .summarizeDay
                            }
                            
                            // Respond to Text Card (NEW)
                            ActionCard(
                                icon: "message.fill",
                                title: "Respond to Text",
                                subtitle: "Generate a response to a recent message",
                                gradientColors: [SteelersTheme.steelersGold, SteelersTheme.goldAccent.opacity(0.7)]
                            ) {
                                selectedAction = .respondToText
                            }
                            
                            // Future Action Placeholders (commented out for now)
                            // Uncomment and implement when ready:
                            /*
                            ActionCard(
                                icon: "clock.fill",
                                title: "Schedule Message",
                                subtitle: "Schedule a message for later",
                                gradientColors: [SteelersTheme.darkGray, SteelersTheme.steelersBlack]
                            ) {
                                selectedAction = .scheduleMessage
                            }
                            
                            ActionCard(
                                icon: "chart.bar.fill",
                                title: "Analyze Conversation",
                                subtitle: "Get insights from message history",
                                gradientColors: [SteelersTheme.steelersGold.opacity(0.6), SteelersTheme.darkGray]
                            ) {
                                selectedAction = .analyzeConversation
                            }
                            */
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
                            showingToneTrainer = true
                        } label: {
                            Image(systemName: "tuningfork")
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
            .sheet(isPresented: $showingToneTrainer) {
                ToneTrainerView(store: toneStore, favorites: favorites, llm: agent.llmClient)
            }
            .fullScreenCover(item: $selectedAction) { action in
                switch action {
                case .goodMorning:
                    GoodMorningView(
                        agent: agent,
                        favorites: favorites,
                        toneStore: toneStore
                    )
                case .todaySchedule:
                    ScheduleView(agent: agent)
                case .summarizeDay:
                    SummaryView(agent: agent)
                case .respondToText:
                    RespondToTextView(
                        agent: agent,
                        favorites: favorites,
                        toneStore: toneStore
                    )
                // Future actions:
                // case .scheduleMessage:
                //     ScheduleMessageView(agent: agent, favorites: favorites)
                // case .analyzeConversation:
                //     AnalyzeConversationView(agent: agent, favorites: favorites)
                }
            }
        }
    }
}

// Make ActionType Identifiable for fullScreenCover
extension HomeView.ActionType: Identifiable {
    var id: Self { self }
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

