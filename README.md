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

### 2. **Calendar Integration**
- View today's schedule from multiple calendars
- AI-powered schedule summaries
- Calendar selection and filtering
- Full calendar access with iOS 17+ support

### 3. **Transit Directions**
- Get directions to PATH train stations
- Location-based nearest station finder
- Google Maps integration for navigation

### 4. **Favorite Contacts**
- Manage frequently messaged contacts
- Per-contact style customization
- Quick access to personalized actions

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

### Settings
Access via toolbar icons:
- **Calendar Settings** (calendar icon): Select which calendars to use
- **Manage Favorites** (people icon): Add/edit favorite contacts
- **LLM Settings** (key icon): Configure AWS credentials or API keys

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

To add a new action:

1. **Create Action Struct**
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

2. **Add to HomeView**
```swift
enum ActionType {
    case goodMorning
    case todaySchedule
    case summarizeDay
    case respondToText
    case myNewAction  // Add here
}
```

3. **Create View** (if needed)
```swift
struct MyNewActionView: View {
    @ObservedObject var agent: AgentController
    // Implementation
}
```

4. **Update AgentController** (if special handling needed)
```swift
func run(action: AgentAction) async {
    // Add custom handling if needed
}
```

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
- ⚠️ Credentials stored in plaintext (AppConfig.plist, UserDefaults)
- ⚠️ No keychain storage for sensitive credentials

### Recommended Improvements
See [`TECH_DEBT.md`](./TECH_DEBT.md) for detailed security improvements:
1. Migrate credentials to iOS Keychain
2. Implement credential encryption
3. Add credential rotation mechanism
4. Remove hardcoded credentials from source

## 🧪 Testing

### Unit Tests
```bash
# Run tests
xcodebuild test -project AayushTestAppV1.xcodeproj -scheme AayushTestAppV1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Manual Testing Checklist
- [ ] Good morning message generation
- [ ] Calendar access and event fetching
- [ ] Day summary generation
- [ ] Text response generation (NEW)
- [ ] Favorite contact management
- [ ] Tone profile training
- [ ] Message sending via Messages app

## 🐛 Known Issues

See [`TECH_DEBT.md`](./TECH_DEBT.md) for comprehensive technical debt tracking.

**Current Known Issues**:
1. **Credential Security**: Credentials stored in plaintext (see Security section)
2. **Deprecated Code**: Some deprecated components still in codebase
3. **Error Handling**: Inconsistent error handling patterns
4. **Test Coverage**: No unit or integration tests

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

- **SwiftUI**: Native iOS UI framework
- **EventKit**: Calendar access
- **MessageUI**: Message composition
- **Combine**: Reactive state management
- **Foundation**: Core Swift functionality

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

