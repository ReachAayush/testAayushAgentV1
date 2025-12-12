# Developer Guide

This guide explains how to add new actions, how the Home screen is structured, and the action registry pattern.

## Architecture Overview

- `HomeView` displays a set of action cards in a scrollable list.
- Actions are defined in `HomeActionRegistry.swift` as `HomeActionItem`s, each with UI metadata and a SwiftUI view builder.
- Views are launched via `.fullScreenCover` using a type-erased `AnyHomeAction`.
- Services like `LLMClient`, `CalendarClient`, `MessagesClient`, and `LocationClient` are created in `ContentView`, injected into `HomeView`, and passed down to action views.
- The action registry pattern makes it easy to add new features without modifying `HomeView` or `AgentController`.

## Adding a New Action

### Step 1: Create the View

Create a new SwiftUI view for your feature (e.g., `MyNewActionView.swift` in `Features/Views/`):

```swift
import SwiftUI

struct MyNewActionView: View {
    @ObservedObject var agent: AgentController
    // Add other dependencies as needed
    // @ObservedObject var favorites: FavoriteContactsStore
    // let locationClient: LocationClient
    
    var body: some View {
        // Your view implementation
    }
}
```

### Step 2: Create the Action (Optional)

If your action needs to follow the `AgentAction` protocol, create an action struct in `Features/Actions/`:

```swift
import Foundation

struct MyNewAction: AgentAction {
    let id = "my-new-action"
    let displayName = "My New Action"
    let summary = "What this action does"
    
    // Dependencies
    let llm: LLMClient
    // Add other dependencies as needed
    
    func run() async throws -> AgentActionResult {
        // Implementation
        return .text("Result")
    }
}
```

### Step 3: Add to Action Registry

Add a new item to `ActionRegistry.all` in `HomeActionRegistry.swift`:

```swift
AnyHomeAction(item: HomeActionItem(
    id: "my-new-action",
    icon: "sparkles",  // SF Symbol name
    title: "My New Action",
    subtitle: "Does something cool",
    gradientColors: [SteelersTheme.steelersGold, SteelersTheme.goldAccent],
    buildView: { agent, favorites in
        AnyView(MyNewActionView(
            agent: agent
            // Pass other dependencies as needed
        ))
    }
))
```

**Important Notes:**
- The `id` should be unique and descriptive
- The `icon` should be a valid SF Symbol name
- The `gradientColors` should use `SteelersTheme` colors for consistency
- The `buildView` closure receives `agent` and `favorites` - add other dependencies as needed
- The order in `ActionRegistry.all` determines the display order on the home screen

### Step 4: Execute the Action (If Using AgentAction)

In your view, execute the action through `AgentController`:

```swift
Button("Run Action") {
    Task {
        let action = MyNewAction(llm: agent.llmClient)
        await agent.run(action: action)
    }
}
```

## Current Actions

The app currently includes these actions (in display order):

1. **Hello** (`hello`) - Generate personalized greeting messages
2. **Today's Schedule** (`todaySchedule`) - View calendar events for today
3. **Transit Directions** (`pathTrain`) - Get directions to PATH train stations
4. **Restaurant Reservation** (`restaurantReservation`) - Find vegetarian restaurants
5. **Stock Recommendations** (`stockRecommendation`) - Get AI-powered investment insights

## Available Services

Services are created in `ContentView` and available through `AgentController`:

- `agent.llmClient` - LLM API client
- `agent.calendarClient` - Calendar access
- `agent.messagesClient` - Message operations
- `LocationClient()` - Location services (create new instance as needed)

## Available Stores

Stores are created in `ContentView` and can be passed to views:

- `favorites` - `FavoriteContactsStore` for favorite contacts
- `TransitStopsStore()` - Transit stops (create new instance as needed)
- `UserProfileStore()` - User profile (create new instance as needed)

## Design Guidelines

- Use `SteelersTheme` colors for consistency
- Follow the card-based UI pattern used in `ActionCard`
- Use full-screen covers for action views
- Use sheets for settings/configuration views
- Maintain the Steelers black and gold color scheme
