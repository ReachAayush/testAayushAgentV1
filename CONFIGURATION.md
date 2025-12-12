# Configuration Management

## Current State

✅ **Configuration is now centralized and secure** using `ConfigurationService` and `CredentialManager`.

## Implementation

### ConfigurationService

The app uses a centralized `ConfigurationService` that provides unified access to configuration values with a clear priority order:

1. **Keychain** (via `CredentialManager`) - Highest priority for sensitive credentials
2. **UserDefaults** - Runtime overrides
3. **Info.plist** - Build-time configuration
4. **AppConfig.plist** - Default configuration file
5. **Hardcoded defaults** - Fallback values

### CredentialManager

Sensitive credentials (API keys, AWS keys) are stored securely in iOS Keychain:
- Automatic encryption by iOS
- Secure storage that persists across app launches
- Accessible only to the app
- No plaintext storage

### Configuration Sources

#### 1. Keychain (Sensitive Credentials)
Stored via `CredentialManager` and accessed through `ConfigurationService`:
- `BEDROCK_API_KEY` - LLM API key
- `AWS_ACCESS_KEY` - AWS access key for SigV4 signing
- `AWS_SECRET_KEY` - AWS secret key for SigV4 signing

#### 2. UserDefaults (Runtime Overrides)
Can be set via the LLM Settings UI:
- `BEDROCK_API_KEY`
- `BEDROCK_BASE_URL`
- `BEDROCK_MODEL_ID`
- `AWS_ACCESS_KEY`
- `AWS_SECRET_KEY`
- `AWS_REGION`

#### 3. Info.plist (Build-Time Configuration)
Add keys to your `Info.plist`:
```xml
<key>BEDROCK_API_KEY</key>
<string>YOUR_API_KEY</string>
<key>BEDROCK_BASE_URL</key>
<string>https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1</string>
<key>BEDROCK_MODEL_ID</key>
<string>openai.gpt-oss-20b-1:0</string>
<key>AWS_ACCESS_KEY</key>
<string>YOUR_ACCESS_KEY</string>
<key>AWS_SECRET_KEY</key>
<string>YOUR_SECRET_KEY</string>
<key>AWS_REGION</key>
<string>us-west-2</string>
```

#### 4. AppConfig.plist (Default Configuration)
Non-sensitive defaults can be stored in `AppConfig.plist`:
```xml
<key>BEDROCK_BASE_URL</key>
<string>https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1</string>
<key>BEDROCK_MODEL_ID</key>
<string>openai.gpt-oss-20b-1:0</string>
<key>AWS_REGION</key>
<string>us-west-2</string>
```

### Usage

#### In Code
```swift
let config = ConfigurationService.shared

// Access configuration (automatically uses priority order)
let apiKey = config.bedrockApiKey
let baseURL = config.bedrockBaseURL
let modelId = config.bedrockModelID

// Set configuration (sensitive values go to Keychain)
try? config.set("new-api-key", forKey: .bedrockApiKey)

// Validate required configuration
let missing = config.validateRequiredConfiguration()
if !missing.isEmpty {
    // Handle missing configuration
}
```

#### In LLM Settings UI
Users can configure credentials via Settings → LLM Settings:
- Values are stored in Keychain (for sensitive) or UserDefaults (for non-sensitive)
- Changes trigger automatic LLM client rebuild
- Configuration is validated before saving

### Configuration Keys

All configuration keys are defined in `ConfigurationService.ConfigurationKey`:
- `.bedrockApiKey` - LLM API key (Keychain)
- `.bedrockBaseURL` - LLM endpoint URL
- `.bedrockModelID` - Model identifier
- `.awsAccessKey` - AWS access key (Keychain)
- `.awsSecretKey` - AWS secret key (Keychain)
- `.awsRegion` - AWS region

### Authentication Methods

The app supports two authentication methods:

1. **AWS SigV4** (when AWS credentials are provided)
   - Uses `AWSSigV4Signer` to sign requests
   - Requires `AWS_ACCESS_KEY`, `AWS_SECRET_KEY`, and `AWS_REGION`

2. **Bearer Token** (when only API key is provided)
   - Uses simple Bearer token authentication
   - Requires only `BEDROCK_API_KEY`

## Related Files
- `Services/ConfigurationService.swift` - Centralized configuration management
- `Services/CredentialManager.swift` - Keychain-based credential storage
- `App/ContentView.swift` - Uses ConfigurationService for initialization
- `UI/LLMSettingsView.swift` - UI for configuring credentials
- `README.md` - Security considerations section

