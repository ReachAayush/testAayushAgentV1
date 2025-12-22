# Quick Wins - Implementation Guide

This guide provides step-by-step instructions for implementing the highest-impact improvements that can be done quickly.

## 🚀 Priority 1: Add Test Infrastructure (2-3 hours)

### Step 1: Create Test Target in Xcode

1. Open Xcode
2. File → New → Target
3. Select "Unit Testing Bundle"
4. Name it "AayushTestAppV1Tests"
5. Click Finish

### Step 2: Create Test Directory Structure

```bash
mkdir -p AayushTestAppV1Tests/{Mocks,Helpers,Services,Controllers,Features}
```

### Step 3: Create Mock Protocols

Create `AayushTestAppV1Tests/Mocks/MockLLMClient.swift`:

```swift
import Foundation
@testable import AayushTestAppV1

class MockLLMClient: LLMClientProtocol {
    var generateTextResult: Result<String, Error> = .success("Mock response")
    var generateTextCallCount = 0
    var lastSystemPrompt: String?
    var lastUserPrompt: String?
    
    func generateText(systemPrompt: String, userPrompt: String) async throws -> String {
        generateTextCallCount += 1
        lastSystemPrompt = systemPrompt
        lastUserPrompt = userPrompt
        return try generateTextResult.get()
    }
}
```

### Step 4: Create First Test

Create `AayushTestAppV1Tests/Services/LLMClientTests.swift`:

```swift
import XCTest
@testable import AayushTestAppV1

final class LLMClientTests: XCTestCase {
    var client: LLMClient!
    
    override func setUp() {
        super.setUp()
        // Create client with test credentials
        client = LLMClient(
            apiKey: "test-key",
            baseURL: URL(string: "https://test.example.com")!,
            model: "test-model"
        )
    }
    
    func testGenerateTextSuccess() async throws {
        // This will fail until we add network mocking
        // But it establishes the test structure
        let result = try await client.generateText(
            systemPrompt: "Test system",
            userPrompt: "Test user"
        )
        XCTAssertFalse(result.isEmpty)
    }
}
```

### Step 5: Run Tests

```bash
xcodebuild test -project AayushTestAppV1.xcodeproj \
  -scheme AayushTestAppV1 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## 🚀 Priority 2: Enhance AgentAction Protocol (1 hour)

### Step 1: Update Protocol

Edit `AayushTestAppV1/Core/AgentAction.swift`:

```swift
protocol AgentAction {
    var id: String { get }
    var displayName: String { get }
    var summary: String { get }
    
    // NEW: Enhanced metadata
    var category: ActionCategory { get }
    var requiredPermissions: [Permission] { get }
    var estimatedDuration: TimeInterval? { get }
    var requiresNetwork: Bool { get }
    
    // NEW: Validation
    func validate() throws
    
    // Existing
    func run() async throws -> AgentActionResult
}

enum ActionCategory {
    case messaging
    case calendar
    case location
    case finance
    case food
}

enum Permission {
    case calendar
    case location
    case contacts
    case messages
}
```

### Step 2: Update Existing Actions

Edit `AayushTestAppV1/Features/Actions/HelloMessageAction.swift`:

```swift
struct HelloMessageAction: AgentAction {
    // ... existing properties ...
    
    var category: ActionCategory { .messaging }
    var requiredPermissions: [Permission] { [.contacts] }
    var estimatedDuration: TimeInterval? { 3.0 }
    var requiresNetwork: Bool { true }
    
    func validate() throws {
        guard !recipientName.isEmpty else {
            throw AppError.invalidInput(field: "recipientName", reason: "Cannot be empty")
        }
    }
    
    // ... existing run() method ...
}
```

### Step 3: Update AgentController

Edit `AayushTestAppV1/Controllers/AgentController.swift`:

```swift
func run(action: AgentAction) async {
    // Add validation
    do {
        try action.validate()
    } catch {
        self.errorMessage = AppError.from(error).userMessage
        return
    }
    
    // Check permissions
    for permission in action.requiredPermissions {
        if !hasPermission(permission) {
            self.errorMessage = "Permission required: \(permission)"
            return
        }
    }
    
    // ... rest of existing code ...
}
```

---

## 🚀 Priority 3: Add Dependency Injection Container (2 hours)

### Step 1: Create Container

Create `AayushTestAppV1/Services/DependencyContainer.swift`:

```swift
import Foundation

/// Simple dependency injection container.
///
/// **Purpose**: Centralizes service registration and resolution,
/// making it easier to manage dependencies and enable testing.
final class DependencyContainer {
    static let shared = DependencyContainer()
    
    private var services: [String: Any] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// Registers a service instance.
    func register<T>(_ service: T, for type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        services[key] = service
    }
    
    /// Resolves a service instance.
    func resolve<T>(_ type: T.Type) -> T {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        guard let service = services[key] as? T else {
            fatalError("Service \(key) not registered. Make sure to register it in ContentView.init()")
        }
        return service
    }
    
    /// Clears all registered services (useful for testing).
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
    }
}
```

### Step 2: Update ContentView

Edit `AayushTestAppV1/App/ContentView.swift`:

```swift
init() {
    let container = DependencyContainer.shared
    let config = ConfigurationService.shared
    
    // Register shared services
    container.register(config, for: ConfigurationService.self)
    container.register(LoggingService.shared, for: LoggingService.self)
    
    // Create and register LLM client
    let llm = LLMClient(
        apiKey: config.bedrockApiKey,
        baseURL: URL(string: config.bedrockBaseURL)!,
        model: config.bedrockModelID,
        awsAccessKey: config.awsAccessKey.isEmpty ? nil : config.awsAccessKey,
        awsSecretKey: config.awsSecretKey.isEmpty ? nil : config.awsSecretKey,
        awsRegion: config.awsRegion.isEmpty ? nil : config.awsRegion
    )
    container.register(llm, for: LLMClient.self)
    
    // Create and register other services
    let calendar = CalendarClient()
    container.register(calendar, for: CalendarClient.self)
    
    let messages = MessagesClient()
    container.register(messages, for: MessagesClient.self)
    
    let location = LocationClient()
    container.register(location, for: LocationClient.self)
    
    // Create stores
    let favorites = FavoriteContactsStore()
    container.register(favorites, for: FavoriteContactsStore.self)
    
    // Create controller with resolved dependencies
    _favorites = StateObject(wrappedValue: favorites)
    _agent = StateObject(
        wrappedValue: AgentController(
            llmClient: container.resolve(LLMClient.self),
            calendarClient: container.resolve(CalendarClient.self),
            messagesClient: container.resolve(MessagesClient.self),
            favoritesStore: favorites
        )
    )
}
```

### Step 3: Use in Actions

Update actions to accept container or resolved services:

```swift
struct HelloMessageAction: AgentAction {
    let llm: LLMClient
    
    init(llm: LLMClient? = nil) {
        self.llm = llm ?? DependencyContainer.shared.resolve(LLMClient.self)
    }
}
```

---

## 🚀 Priority 4: Add SwiftLint (30 minutes)

### Step 1: Install SwiftLint

```bash
# Using Homebrew
brew install swiftlint

# Or using Mint
mint install realm/SwiftLint
```

### Step 2: Create Configuration

Create `.swiftlint.yml` in project root:

```yaml
disabled_rules:
  - trailing_whitespace

opt_in_rules:
  - empty_count
  - force_unwrapping
  - implicitly_unwrapped_optional

line_length: 120
function_body_length: 50
file_length: 500

excluded:
  - Pods
  - .build
```

### Step 3: Add Build Phase

1. In Xcode: Project → Target → Build Phases
2. Click "+" → New Run Script Phase
3. Add script:
```bash
if which swiftlint > /dev/null; then
    swiftlint
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

### Step 4: Run SwiftLint

```bash
swiftlint
```

---

## 🚀 Priority 5: Create Contributor Guide (1 hour)

Create `CONTRIBUTING.md`:

```markdown
# Contributing to Aayush Agent

Thank you for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork
3. Open `AayushTestAppV1.xcodeproj` in Xcode
4. Run the app to verify setup

## Adding a New Action

See [UI/DEVELOPING.md](./AayushTestAppV1/UI/DEVELOPING.md) for detailed instructions.

Quick steps:
1. Create action struct conforming to `AgentAction`
2. Create view in `Features/Views/`
3. Add to `HomeActionRegistry`
4. Write tests
5. Update documentation

## Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint (configured in project)
- Maximum line length: 120
- Maximum function length: 50 lines
- Maximum file length: 500 lines

## Testing

- All new features must include tests
- Aim for 80%+ code coverage
- Run tests before submitting PR

## Pull Request Process

1. Create feature branch from `main`
2. Make changes
3. Write/update tests
4. Update documentation
5. Submit PR with description
6. Address review feedback

## Questions?

Open an issue or contact maintainers.
```

---

## ✅ Checklist

- [ ] Test target created
- [ ] First test written and passing
- [ ] AgentAction protocol enhanced
- [ ] Existing actions updated
- [ ] DependencyContainer created
- [ ] ContentView updated to use container
- [ ] SwiftLint installed and configured
- [ ] CONTRIBUTING.md created
- [ ] All tests passing
- [ ] Code builds without warnings

---

## 🎯 Next Steps

After completing quick wins:

1. **Complete error handling migration** (1 week)
2. **Split large service files** (2 weeks)
3. **Add comprehensive test coverage** (2-3 weeks)
4. **Implement action middleware** (1 week)

See [CODE_REVIEW_2025.md](./CODE_REVIEW_2025.md) for full roadmap.



