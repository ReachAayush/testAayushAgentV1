# Architecture Documentation

## Overview

This document describes the architecture of the Aayush Agent iOS app, following enterprise-grade software engineering principles.

## Design Principles

### 1. **Separation of Concerns**
- **Services**: Pure data access (LLM, Calendar, Messages)
- **Controllers**: Business logic coordination
- **Views**: UI presentation only
- **Stores**: Observable state management
- **Actions**: Feature-specific business logic

### 2. **Protocol-Oriented Design**
- All actions conform to `AgentAction` protocol
- Enables easy extension without modifying existing code
- Type-safe action handling

### 3. **Dependency Injection**
- Services injected into controllers and actions
- Makes testing easier
- Clear dependency graph
- No global state (except singleton services where appropriate)

### 4. **Async/Await**
- Modern Swift concurrency throughout
- Non-blocking UI
- Proper error propagation
- Clean async flows

## Layer Architecture

```
┌─────────────────────────────────────────┐
│           UI Layer (SwiftUI)            │
│  HomeView, HelloView, ScheduleView,     │
│  RestaurantReservationView, etc.        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│        Controller Layer                 │
│      AgentController                    │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Action Layer                    │
│  HelloMessageAction,                    │
│  RestaurantReservationAction,           │
│  StockRecommendationAction, etc.         │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│        Service Layer                    │
│  LLMClient, CalendarClient,             │
│  LocationClient, RestaurantDiscovery,   │
│  ConfigurationService, etc.             │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│        Store Layer                      │
│  FavoriteContactsStore,                 │
│  TransitStopsStore, UserProfileStore   │
└─────────────────────────────────────────┘
```

## File Organization

> 📁 **Complete File Structure**: See [`FILE_STRUCTURE.md`](./FILE_STRUCTURE.md) for the detailed directory structure and file organization. This document serves as the single source of truth for file structure.

## Data Flow

### Example: Generating a Hello Message

1. **User Interaction** (`HelloView`)
   - User selects contact from favorites
   - User taps "Generate Message"
   - View creates `HelloMessageAction`

2. **Action Execution** (`AgentController`)
   - `run(action:)` is called
   - Controller sets loading state
   - Action's `run()` method is invoked

3. **Service Call** (`HelloMessageAction`)
   - Action calls `llm.generateText()` or `llm.generateHelloMessagePayload()`
   - LLM client formats request with authentication
   - Makes HTTP request to Bedrock API (with SigV4 or Bearer token)

4. **Response Handling** (`LLMClient`)
   - Parses JSON response
   - Sanitizes message text
   - Returns result to action

5. **Result Propagation** (`AgentController`)
   - Action returns `AgentActionResult.text`
   - Controller updates `lastOutput`
   - UI automatically updates via `@Published`

## Error Handling

### Strategy
- **Services**: Throw descriptive errors
- **Actions**: Propagate errors or handle gracefully
- **Controllers**: Catch errors and update `errorMessage`
- **Views**: Display errors to user

### Error Types
- Network errors (API failures)
- Permission errors (calendar/messages access)
- Validation errors (missing required fields)
- Parsing errors (malformed JSON)

## State Management

### Observable Objects
- `AgentController`: Action execution state and coordination
- `FavoriteContactsStore`: Favorite contacts list with persistence
- `TransitStopsStore`: Saved transit stops with persistence
- `UserProfileStore`: User profile information (name, email, phone)

### Published Properties
- `@Published` for reactive UI updates
- `@StateObject` for owned state (created in parent view)
- `@ObservedObject` for passed state (injected from parent)
- `@AppStorage` for simple UserDefaults-backed state

## Testing Strategy

### Unit Tests (Recommended)
- Test services in isolation
- Mock dependencies
- Test action logic
- Test error handling

### Integration Tests (Recommended)
- Test action execution flow
- Test service interactions
- Test state updates

### UI Tests (Recommended)
- Test user flows
- Test navigation
- Test error states

## Security Considerations

### Current State
- ✅ AWS SigV4 signing implemented for Bedrock authentication
- ✅ Runtime credential configuration via settings UI
- ✅ Support for both AWS credentials (SigV4) and Bearer tokens
- ✅ **Credentials stored securely in iOS Keychain** (via `CredentialManager`)
- ✅ Centralized configuration management (via `ConfigurationService`)
- ✅ Priority-based configuration loading (Keychain → UserDefaults → Info.plist → AppConfig.plist)

### Implementation
- `CredentialManager`: Handles all Keychain operations with proper encryption
- `ConfigurationService`: Provides unified access with automatic Keychain priority
- Sensitive credentials never stored in plaintext
- Non-sensitive configuration can use Info.plist or AppConfig.plist

### Future Enhancements
See [`TECH_DEBT.md`](./TECH_DEBT.md) for remaining improvements:
1. Credential rotation mechanism
2. Biometric authentication for credential access (optional)

## Performance Considerations

### Current Optimizations
- Async/await for non-blocking operations
- Lazy loading of views
- Efficient state updates

### Future Optimizations
- Cache LLM responses
- Batch calendar requests
- Lazy load contact data
- Image caching (if images added)

## Extensibility

### Adding a New Action

The app uses a registry-based pattern for actions. See [`UI/DEVELOPING.md`](./AayushTestAppV1/UI/DEVELOPING.md) for detailed instructions.

1. **Create Action Struct** (if using AgentAction protocol)
```swift
struct MyNewAction: AgentAction {
    let id = "my-action"
    let displayName = "My Action"
    let summary = "Description"
    
    let dependencies: SomeService
    
    func run() async throws -> AgentActionResult {
        // Implementation
        return .text("Result")
    }
}
```

2. **Create View**
```swift
struct MyNewActionView: View {
    @ObservedObject var agent: AgentController
    // Implementation
}
```

3. **Add to Action Registry** (`HomeActionRegistry.swift`)
```swift
AnyHomeAction(item: HomeActionItem(
    id: "my-action",
    icon: "sparkles",
    title: "My Action",
    subtitle: "Description",
    gradientColors: [SteelersTheme.steelersGold, SteelersTheme.goldAccent],
    buildView: { agent, favorites in
        AnyView(MyNewActionView(agent: agent))
    }
))
```

The action will automatically appear on the home screen. No changes needed to `HomeView` or `AgentController` unless special handling is required.

### Adding a New Service

1. **Create Service Class**
```swift
final class MyService {
    func doSomething() async throws -> Result {
        // Implementation
    }
}
```

2. **Inject into Dependencies**
- Add to `AgentController` init
- Pass to actions that need it
- Initialize in `ContentView`

## Dependencies

### iOS Frameworks
- **SwiftUI**: Native iOS UI framework
- **EventKit**: Calendar access
- **MessageUI**: Message composition
- **MapKit**: Restaurant search and location services
- **CoreLocation**: Location services for transit and restaurant features
- **Contacts**: Contact lookup and management
- **Combine**: Reactive state management
- **Foundation**: Core Swift functionality
- **CryptoKit**: AWS SigV4 signing (built-in framework)

### External Services
- **Amazon Bedrock**: LLM API (via OpenAI-compatible endpoint)
- **Google Maps**: Transit directions and restaurant navigation
- **Apple Maps**: Restaurant discovery and search

### Internal Services
- **LLMClient**: Bedrock API integration with SigV4/Bearer authentication
- **CalendarClient**: EventKit calendar access
- **MessagesClient**: Message operations and contact lookup
- **LocationClient**: CoreLocation wrapper for location services
- **RestaurantDiscoveryService**: MapKit-based restaurant search
- **RestaurantFilter**: Restaurant filtering logic (vegetarian, etc.)
- **RestaurantDeduplicator**: Deduplication of restaurant results
- **RestaurantGrouper**: Grouping restaurants by location
- **RestaurantMapper**: Mapping MapKit results to app models
- **ReservationService**: Restaurant reservation management
- **ConfigurationService**: Centralized configuration management
- **CredentialManager**: Keychain-based credential storage
- **LoggingService**: Structured logging with categories

### Internal
- No external package dependencies
- All code is self-contained
- Uses Swift's built-in frameworks only

## Future Enhancements

### Architecture Improvements
- [ ] Dependency injection container
- [ ] Router for navigation
- [ ] Analytics service (metrics aggregation)
- [x] Logging service ✅ **COMPLETED**
- [x] Configuration service ✅ **COMPLETED**

### Feature Additions
- [ ] Scheduled messages
- [ ] Message history analysis
- [ ] Multi-language support
- [ ] Voice message generation
- [ ] Integration with other messaging apps
- [ ] Restaurant reservation booking (currently shows in Google Maps)
- [ ] Stock price tracking and alerts

---

## Technical Debt

For a comprehensive inventory of technical debt items, prioritized by impact and effort, see [`TECH_DEBT.md`](./TECH_DEBT.md).

**Key Areas**:
- Credential management security
- Deprecated code removal
- Error handling improvements
- Test coverage
- Logging and observability

---

**Last Updated**: January 2025  
**Maintained By**: Development Team  
**Review Frequency**: Quarterly

