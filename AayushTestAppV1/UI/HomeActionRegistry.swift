//
//  HomeActionRegistry.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

/// Strongly-typed registry item for Home actions.
///
/// Purpose: Centralizes UI metadata and view-building logic so adding a new
/// action is as simple as adding a new item in `ActionRegistry.all`.
///
/// Usage:
/// - Provide an `id`, `icon`, `title`, `subtitle`, and `gradientColors` for the card
/// - Provide a `buildView` closure that returns the full-screen content
struct HomeActionItem: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let buildView: (_ agent: AgentController, _ favorites: FavoriteContactsStore) -> AnyView

    static func == (lhs: HomeActionItem, rhs: HomeActionItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Type-erased wrapper for use as @State optional item in fullScreenCover
struct AnyHomeAction: Identifiable, Hashable {
    let item: HomeActionItem
    var id: String { item.id }
    var icon: String { item.icon }
    var title: String { item.title }
    var subtitle: String { item.subtitle }
    var gradientColors: [Color] { item.gradientColors }
    func buildView(_ agent: AgentController, _ favorites: FavoriteContactsStore) -> some View {
        item.buildView(agent, favorites)
    }
}

/// Global registry of actions displayed on the Home screen.
///
/// Add new items here to surface new features in the app. The order in this array
/// is the order they appear in the UI.
enum ActionRegistry {
    static let all: [AnyHomeAction] = [
        AnyHomeAction(item: HomeActionItem(
            id: "hello",
            icon: "hand.wave.fill",
            title: "Hello",
            subtitle: "Send a personalized greeting",
            gradientColors: [SteelersTheme.steelersGold, SteelersTheme.goldAccent],
            buildView: { agent, favorites in
                AnyView(HelloView(agent: agent, favorites: favorites))
            }
        )),
        AnyHomeAction(item: HomeActionItem(
            id: "todaySchedule",
            icon: "calendar",
            title: "Today's Schedule",
            subtitle: "View your calendar for today",
            gradientColors: [SteelersTheme.darkGray, SteelersTheme.steelersBlack],
            buildView: { agent, _ in
                AnyView(ScheduleView(agent: agent))
            }
        )),
        AnyHomeAction(item: HomeActionItem(
            id: "pathTrain",
            icon: "tram.fill",
            title: "Transit Directions",
            subtitle: "Get directions from your location",
            gradientColors: [SteelersTheme.steelersGold.opacity(0.8), SteelersTheme.darkGray],
            buildView: { _, _ in
                AnyView(PATHTrainView())
            }
        )),
        AnyHomeAction(item: HomeActionItem(
            id: "restaurantReservation",
            icon: "fork.knife",
            title: "Restaurant Reservation",
            subtitle: "Find & book a vegetarian restaurant",
            gradientColors: [Color.green.opacity(0.8), SteelersTheme.steelersGold],
            buildView: { agent, _ in
                AnyView(RestaurantReservationView(agent: agent, locationClient: LocationClient()))
            }
        ))
    ]
}

#if DEBUG
import SwiftUI

#Preview("Home with Registry") {
    let llm = LLMClient(apiKey: "preview", baseURL: URL(string: "https://example.com")!, model: "preview")
    let agent = AgentController(
        llmClient: llm,
        calendarClient: CalendarClient(),
        messagesClient: MessagesClient(),
        favoritesStore: FavoriteContactsStore()
    )
    return HomeView(agent: agent, favorites: FavoriteContactsStore())
}
#endif

