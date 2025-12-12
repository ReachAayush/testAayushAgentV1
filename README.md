# Aayush Agent - Personal AI Assistant

A sophisticated iOS application that leverages Amazon Bedrock LLM to provide intelligent, personalized messaging and calendar management capabilities. Built with SwiftUI and following enterprise-grade architecture principles.

## 🏗️ Architecture Overview

This app follows a **modular, scalable architecture** designed for easy extension and maintenance.

> 📁 **File Structure**: See [`FILE_STRUCTURE.md`](./FILE_STRUCTURE.md) for the complete directory structure and file organization.

## 🎯 Key Features

### 1. **Hello Messages**
- Generate personalized greeting messages using LLM
- Timezone-aware greetings (morning, afternoon, evening)
- Support for multiple contacts with custom style hints
- Per-contact relationship context and tone preferences
- Favorite contacts integration for quick access

### 2. **Calendar Integration**
- View today's schedule from multiple calendars
- AI-powered schedule summaries
- Calendar selection and filtering
- Full calendar access with iOS 17+ support

### 3. **Transit Directions**
- Get directions to PATH train stations
- Location-based nearest station finder
- Google Maps integration for navigation
- Manage saved transit stops (add, edit, delete)
- Default stops included (Hoboken PATH, Christopher St PATH)

### 4. **Restaurant Reservations**
- Find high-rated vegetarian restaurants near you
- Location-based search with expanding radius (5km to 20km)
- Restaurant deduplication and filtering
- Integration with Google Maps for directions and reservations
- Displays restaurant details: name, cuisine, address, phone, vegetarian options

### 5. **Stock Recommendations**
- AI-powered stock investment insights
- Separate recommendations for stocks to buy and stocks to avoid
- Market analysis based on current conditions, news, and trends
- Structured data with ticker symbols and reasoning
- JSON-embedded results for easy parsing

### 6. **Favorite Contacts**
- Manage frequently messaged contacts
- Per-contact style customization
- Quick access to personalized actions
- Persistent storage with UserDefaults

### 7. **User Profile Management**
- Store user contact information (name, email, phone)
- Pre-fill forms for reservations and other services
- Profile completion validation

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+ (Xcode 26.1+ recommended)
- iOS 18.7+ (deployment target)
- Amazon Bedrock credentials (AWS Access Key, Secret Key, Region) OR OpenAI-compatible gateway API key
- Active Apple Developer account (for device testing)

### Configuration

1. **Bedrock API Setup**
   - Obtain your Bedrock API key
   - Configure your base URL (e.g., `https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1`)
   - Select your model ID (e.g., `openai.gpt-oss-20b-1:0`)

2. **Update Configuration**
   - Option A: Add credentials to `AppConfig.plist` (included in bundle)
   - Option B: Add credentials to `Info.plist` (not tracked in git)
   - Option C: Use runtime settings in the app (Settings → LLM Settings)
   - See [`CONFIGURATION.md`](./CONFIGURATION.md) for detailed instructions

3. **Permissions**
   - Calendar access (required for schedule features)
   - Messages access (required for text response feature)
   - Contacts access (optional, for contact selection)

### Building the App

```bash
# Open in Xcode
open AayushTestAppV1.xcodeproj

# Or use xcodebuild
xcodebuild -project AayushTestAppV1.xcodeproj -scheme AayushTestAppV1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 📱 Usage

### Home Screen
The home screen serves as the central hub with action cards for:
- **Hello**: Generate personalized greeting messages
- **Today's Schedule**: View calendar events for today
- **Transit Directions**: Get directions to PATH train stations
- **Restaurant Reservation**: Find vegetarian restaurants near you
- **Stock Recommendations**: Get AI-powered investment insights

### Settings
Access via toolbar icons:
- **Calendar Settings** (calendar icon): Select which calendars to use
- **Manage Favorites** (people icon): Add/edit favorite contacts
- **LLM Settings** (key icon): Configure AWS credentials or API keys (stored securely in Keychain)

## 🏛️ Architecture Principles

### 1. **Protocol-Oriented Design**
All actions conform to `AgentAction` protocol, enabling:
- Easy addition of new actions
- Consistent execution flow
- Type-safe action handling

### 2. **Separation of Concerns**
- **Services**: Pure data access (LLM, Calendar, Messages)
- **Controllers**: Business logic coordination
- **Views**: UI presentation only
- **Stores**: Observable state management

### 3. **Dependency Injection**
Services are injected into controllers and actions, enabling:
- Easy testing
- Flexible configuration
- Clear dependencies

### 4. **Async/Await**
Modern Swift concurrency throughout:
- Non-blocking UI
- Proper error handling
- Clean async flows

## 🔧 Adding New Actions

The app uses a registry-based pattern for actions, making it easy to add new features:

1. **Create Action Struct** (if using AgentAction protocol)
```swift
struct MyNewAction: AgentAction {
    let id = "my-new-action"
    let displayName = "My New Action"
    let summary = "What this action does"
    
    // Dependencies
    let llm: LLMClient
    
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
    id: "my-new-action",
    icon: "sparkles",
    title: "My New Action",
    subtitle: "Does something cool",
    gradientColors: [SteelersTheme.steelersGold, SteelersTheme.goldAccent],
    buildView: { agent, favorites in
        AnyView(MyNewActionView(agent: agent))
    }
))
```

The action will automatically appear on the home screen in the order it's added to the registry. See [`UI/DEVELOPING.md`](./AayushTestAppV1/UI/DEVELOPING.md) for more details.

## 🎨 Design System

The app uses a **Pittsburgh Steelers** themed design system:
- **Primary Colors**: Steelers Black (#000000) and Gold (#FFB612)
- **Typography**: System fonts with custom weights
- **Components**: Reusable card and button styles
- **Accessibility**: High contrast, readable text

## 🔐 Security Considerations

### Current State
- ✅ AWS SigV4 signing implemented for Bedrock authentication
- ✅ Runtime credential configuration via settings UI
- ✅ **Credentials stored securely in iOS Keychain** (via `CredentialManager`)
- ✅ Centralized configuration management (via `ConfigurationService`)
- ✅ Support for both AWS credentials (SigV4) and Bearer token authentication
- ✅ Priority-based configuration loading (Keychain → UserDefaults → Info.plist → AppConfig.plist)

### Implementation Details
- `CredentialManager` handles all Keychain operations with proper encryption
- `ConfigurationService` provides unified access to configuration with automatic Keychain priority
- Sensitive credentials (API keys, AWS keys) are never stored in plaintext
- Non-sensitive configuration can still use Info.plist or AppConfig.plist

### Future Enhancements
See [`TECH_DEBT.md`](./TECH_DEBT.md) for remaining improvements:
1. Credential rotation mechanism
2. Biometric authentication for credential access (optional)

## 🧪 Testing

### Unit Tests
```bash
# Run tests
xcodebuild test -project AayushTestAppV1.xcodeproj -scheme AayushTestAppV1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Manual Testing Checklist
- [ ] Hello message generation with favorite contacts
- [ ] Calendar access and event fetching
- [ ] Today's schedule viewing
- [ ] Transit directions to PATH stations
- [ ] Restaurant search and filtering
- [ ] Stock recommendation generation
- [ ] Favorite contact management
- [ ] Transit stops management
- [ ] LLM settings configuration (Keychain storage)
- [ ] Calendar selection

## 🐛 Known Issues

See [`TECH_DEBT.md`](./TECH_DEBT.md) for comprehensive technical debt tracking.

**Current Known Issues**:
1. **Test Coverage**: No unit or integration tests (high priority)
2. **Error Handling**: Some services still need migration to `AppError` pattern
3. **Logging**: Some services still use print statements instead of `LoggingService`
4. **Performance**: No caching for LLM responses or calendar events

## 🚧 Future Enhancements

### Planned Features
- [ ] Message history analysis
- [ ] Scheduled message sending
- [ ] Multi-language support
- [ ] Voice message generation
- [ ] Integration with other messaging apps
- [ ] Analytics and usage tracking
- [ ] Cloud sync for contacts and preferences

### Technical Debt
See [`TECH_DEBT.md`](./TECH_DEBT.md) for a comprehensive inventory of technical debt items, prioritized by impact and effort.

## 📚 Dependencies

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
- All code is self-contained with no external package dependencies
- Uses Swift's built-in frameworks only

## 👥 Contributing

This is a personal project, but contributions are welcome! Please:
1. Follow the existing code style
2. Add comments for complex logic
3. Update README for new features
4. Test thoroughly before submitting

## 📄 License

Private project - All rights reserved

## 🙏 Acknowledgments

- Amazon Bedrock for LLM capabilities
- Pittsburgh Steelers for design inspiration
- SwiftUI team for the amazing framework

---

**Built with ❤️ using SwiftUI and Amazon Bedrock**

