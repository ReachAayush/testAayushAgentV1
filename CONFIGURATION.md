# Configuration Management

## Current State

⚠️ **API keys are currently hardcoded** in `ContentView.swift`. This is **NOT production-ready**.

## Current Implementation

```swift
// In ContentView.swift
let bedrockApiKey = "<redacted>"
let bedrockBaseURL = URL(string: "https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1")!
let bedrockModelId = "openai.gpt-oss-20b-1:0"
```

## Recommended Improvements

### Option 1: Info.plist (Simple)
Move configuration to `Info.plist`:

```xml
<key>BedrockAPIKey</key>
<string>YOUR_API_KEY</string>
<key>BedrockBaseURL</key>
<string>https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1</string>
<key>BedrockModelId</key>
<string>openai.gpt-oss-20b-1:0</string>
```

Then read in code:
```swift
guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "BedrockAPIKey") as? String else {
    fatalError("BedrockAPIKey not found in Info.plist")
}
```

### Option 2: Keychain (Secure)
Store sensitive keys in iOS Keychain for better security.

### Option 3: Configuration Service (Recommended)
Create a `ConfigurationService` that:
- Loads from `Info.plist` for non-sensitive config
- Uses Keychain for API keys
- Supports different configurations for Debug/Release builds
- Provides type-safe access to configuration values

## Future Implementation

Consider creating:
- `Services/ConfigurationService.swift` - Centralized config management
- `Config.plist` - Non-sensitive configuration
- Keychain integration for API keys
- Environment-based configuration (Debug/Release/Staging)

## Related Files
- `AayushTestAppV1/App/ContentView.swift` - Current hardcoded configuration
- `README.md` - Security considerations section

