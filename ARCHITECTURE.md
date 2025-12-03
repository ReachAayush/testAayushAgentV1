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
│  HomeView, GoodMorningView, etc.        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│        Controller Layer                 │
│      AgentController                    │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Action Layer                    │
│  GoodMorningMessageAction, etc.         │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│        Service Layer                    │
│  LLMClient, CalendarClient, etc.        │
└─────────────────────────────────────────┘
```

## File Organization

> 📁 **Complete File Structure**: See [`FILE_STRUCTURE.md`](./FILE_STRUCTURE.md) for the detailed directory structure and file organization. This document serves as the single source of truth for file structure.

## Data Flow

### Example: Generating a Good Morning Message

1. **User Interaction** (`GoodMorningView`)
   - User selects contact
   - User taps "Generate Message"
   - View creates `GoodMorningMessageAction`

2. **Action Execution** (`AgentController`)
   - `run(action:)` is called
   - Controller sets loading state
   - Action's `run()` method is invoked

3. **Service Call** (`GoodMorningMessageAction`)
   - Action calls `llm.generateGoodMorningMessagePayload()`
   - LLM client formats request
   - Makes HTTP request to Bedrock API

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
- `AgentController`: Action execution state
- `FavoriteContactsStore`: Contact list
- `ToneProfileStore`: Tone profile and samples

### Published Properties
- `@Published` for reactive UI updates
- `@StateObject` for owned state
- `@ObservedObject` for passed state

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
- ⚠️ API keys hardcoded in `ContentView.swift`
- ⚠️ No encryption for sensitive data
- ⚠️ No request signing

### Recommended Improvements
1. Move API keys to secure keychain
2. Use environment variables for different builds
3. Implement API key rotation
4. Add request signing/authentication
5. Encrypt sensitive user data at rest

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

1. **Create Action Struct**
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

2. **Add to HomeView**
- Add case to `ActionType` enum
- Add `ActionCard` in UI
- Add case to `fullScreenCover` switch
- Create corresponding view

3. **Update AgentController** (if needed)
- Add special handling if required
- Otherwise, default path handles it

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

### External
- **SwiftUI**: Native iOS UI framework
- **EventKit**: Calendar access
- **MessageUI**: Message composition
- **Contacts**: Contact lookup
- **Combine**: Reactive state management
- **Foundation**: Core Swift functionality

### Internal
- No external package dependencies
- All code is self-contained

## Future Enhancements

### Architecture Improvements
- [ ] Dependency injection container
- [ ] Router for navigation
- [ ] Analytics service
- [ ] Logging service
- [ ] Configuration service

### Feature Additions
- [ ] Scheduled messages
- [ ] Message history analysis
- [ ] Multi-language support
- [ ] Voice message generation
- [ ] Integration with other messaging apps

---

**Last Updated**: 2024
**Maintained By**: Development Team

