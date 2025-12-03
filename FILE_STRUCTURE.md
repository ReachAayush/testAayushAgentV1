# File Structure

> **📌 Single Source of Truth**: This document is the authoritative reference for the project's file structure. Other documentation files reference this document to avoid duplication and maintenance overhead.

This document shows the current physical file structure of the project.

## Current Structure

```
AayushTestAppV1/
├── App/
│   ├── AayushTestAppV1App.swift      # App entry point
│   └── ContentView.swift              # Root view with dependency injection
│
├── Core/
│   └── AgentAction.swift              # Protocol defining agent actions
│
├── Services/
│   ├── LLMClient.swift                # Amazon Bedrock LLM integration
│   ├── CalendarClient.swift           # EventKit calendar access
│   └── MessagesClient.swift           # Message operations and contact lookup
│
├── Controllers/
│   ├── AgentController.swift          # Main agent orchestration
│   └── MessagingController.swift      # Message composition UI
│
├── Features/
│   ├── Actions/
│   │   ├── GoodMorningMessageAction.swift
│   │   ├── SummarizeDayAction.swift
│   │   ├── TodayScheduleSummaryAction.swift
│   │   └── RespondToTextAction.swift
│   │
│   └── Views/
│       ├── GoodMorningView.swift
│       ├── ScheduleView.swift
│       ├── SummaryView.swift
│       └── RespondToTextView.swift
│
├── UI/
│   ├── HomeView.swift                 # Main navigation hub
│   ├── SteelersTheme.swift            # Design system
│   ├── CalendarSelectionView.swift
│   ├── FavoritesManagementView.swift
│   └── ToneTrainerView.swift
│
├── Stores/
│   ├── FavoriteContactsStore.swift    # Favorite contacts state
│   └── ToneProfileStore.swift         # Tone profile state
│
└── Assets.xcassets/                   # App icons and colors
    ├── AccentColor.colorset/
    ├── AppIcon.appiconset/
    └── Contents.json
```

## Viewing in Xcode

Since this project uses Xcode's **File System Synchronized Groups** (Xcode 15+), the file structure should automatically appear in Xcode's navigator. If you don't see the organized structure:

1. **Clean Build Folder**: Product → Clean Build Folder (⇧⌘K)
2. **Close and Reopen**: Close Xcode and reopen the project
3. **Refresh**: Right-click the project in navigator → "Refresh File System"

The files are organized physically on disk, and Xcode should reflect this automatically.

## Adding New Files

When adding new files:

- **Core protocols/types** → `Core/`
- **Service integrations** → `Services/`
- **Business logic coordinators** → `Controllers/`
- **Feature actions** → `Features/Actions/`
- **Feature views** → `Features/Views/`
- **Shared UI components** → `UI/`
- **State management** → `Stores/`
- **App entry point** → `App/`

## Benefits of This Structure

1. **Clear Organization**: Easy to find files by purpose
2. **Scalability**: Easy to add new features without clutter
3. **Maintainability**: Related files are grouped together
4. **Team Collaboration**: Clear structure for multiple developers
5. **Onboarding**: New developers can understand the codebase quickly

