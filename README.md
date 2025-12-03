# Aayush Agent - Personal AI Assistant

A sophisticated iOS application that leverages Amazon Bedrock LLM to provide intelligent, personalized messaging and calendar management capabilities. Built with SwiftUI and following enterprise-grade architecture principles.

## 🏗️ Architecture Overview

This app follows a **modular, scalable architecture** designed for easy extension and maintenance.

> 📁 **File Structure**: See [`FILE_STRUCTURE.md`](./FILE_STRUCTURE.md) for the complete directory structure and file organization.

## 🎯 Key Features

### 1. **Good Morning Messages**
- Generate personalized morning messages using LLM
- Support for multiple contacts with custom style hints
- Tone profile integration for consistent messaging style

### 2. **Calendar Integration**
- View today's schedule from multiple calendars
- AI-powered day summaries
- Calendar selection and filtering

### 3. **Text Response Assistant** (NEW)
- Analyze recently received messages
- Generate contextually appropriate responses
- Support for multiple conversation threads

### 4. **Tone Training**
- Train the AI on your messaging style
- Generate tone profiles from sample messages
- Apply tone profiles across all actions

### 5. **Favorite Contacts**
- Manage frequently messaged contacts
- Per-contact style customization
- Quick access to personalized actions

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ (with fallback to iOS 16.0+)
- Amazon Bedrock API key and endpoint
- Active Apple Developer account (for device testing)

### Configuration

1. **Bedrock API Setup**
   - Obtain your Bedrock API key
   - Configure your base URL (e.g., `https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1`)
   - Select your model ID (e.g., `openai.gpt-oss-20b-1:0`)

2. **Update Configuration**
   - Edit `ContentView.swift` to add your Bedrock credentials
   - ⚠️ **TODO**: See [`CONFIGURATION.md`](./CONFIGURATION.md) for recommended improvements

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
- **Good Morning**: Generate and send morning messages
- **Today's Schedule**: View calendar events
- **Summarize Day**: Get AI summary of your day
- **Respond to Text**: Generate responses to recent messages (NEW)

### Settings
Access via toolbar icons:
- **Calendar Settings**: Select which calendars to use
- **Manage Favorites**: Add/edit favorite contacts
- **Tone Trainer**: Train AI on your messaging style

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
- API keys are hardcoded in `ContentView.swift` (⚠️ **NOT PRODUCTION READY**)

### Recommended Improvements
1. Move API keys to `Info.plist` or secure keychain
2. Use environment variables for different builds
3. Implement API key rotation
4. Add request signing/authentication
5. Encrypt sensitive user data

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

1. **API Key Security**: Keys are hardcoded (see Security section)
2. **Error Handling**: Some edge cases may need better UX
3. **Offline Support**: No offline caching of generated messages
4. **Message History**: Text response feature requires Messages app access

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
- [ ] Refactor API key management
- [ ] Add comprehensive error handling
- [ ] Implement proper logging
- [ ] Add analytics
- [ ] Performance optimization for large calendars
- [ ] Accessibility improvements

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

