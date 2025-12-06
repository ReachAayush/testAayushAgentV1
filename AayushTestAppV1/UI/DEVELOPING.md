# Developer Guide

This guide explains how to add new actions, how the Home screen is structured, and what you need for multi-device distribution.

## Architecture Overview

- `HomeView` displays a set of action cards.
- Actions are defined in `HomeActionRegistry.swift` as `HomeActionItem`s, each with UI metadata and a SwiftUI view builder.
- Views are launched via `.fullScreenCover` using a type-erased `AnyHomeAction`.
- Services like `LLMClient`, `CalendarClient`, and `MessagesClient` are created in `ContentView`, injected into `HomeView`, and passed down to action views.

## Adding a New Action

1. Create a new SwiftUI view for your feature (e.g., `MyNewActionView.swift`).
2. Add a new item in `ActionRegistry.all`:

```swift
AnyHomeAction(item: HomeActionItem(
    id: "my-new-action",
    icon: "sparkles",
    title: "My New Action",
    subtitle: "Does something cool",
    gradientColors: [SteelersTheme.steelersGold, SteelersTheme.goldAccent],
    buildView: { agent, favorites in
        AnyView(MyNewActionView(/* inject dependencies here */))
    }
))
