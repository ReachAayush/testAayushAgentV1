import SwiftUI

/// Settings screen for configuring LLM credentials at runtime.
///
/// Values are stored in UserDefaults via @AppStorage so they override
/// missing Info.plist or AppConfig.plist values.
struct LLMSettingsScreen: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("BEDROCK_API_KEY") private var apiKey: String = ""
    @AppStorage("BEDROCK_BASE_URL") private var baseURL: String = "https://bedrock-runtime.us-west-2.amazonaws.com/openai/v1"
    @AppStorage("BEDROCK_MODEL_ID") private var modelID: String = "openai.gpt-oss-20b-1:0"
    
    // AWS credentials for SigV4 signing
    @AppStorage("AWS_ACCESS_KEY") private var awsAccessKey: String = ""
    @AppStorage("AWS_SECRET_KEY") private var awsSecretKey: String = ""
    @AppStorage("AWS_REGION") private var awsRegion: String = "us-west-2"

    var body: some View {
        NavigationStack {
            Form {
                Section("Authentication Method") {
                    Text("Choose one:")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Section("AWS Credentials (SigV4) - Recommended for Bedrock") {
                    SecureField("AWS Access Key", text: $awsAccessKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("AWS Secret Key", text: $awsSecretKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("AWS Region (e.g., us-west-2)", text: $awsRegion)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section("Bearer Token (for OpenAI-compatible gateways)") {
                    SecureField("Bearer token", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section("Endpoint Configuration") {
                    TextField("Base URL", text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Model ID", text: $modelID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section(footer: Text("Tip: For standard AWS Bedrock endpoints, use AWS Credentials (SigV4). For OpenAI-compatible gateways, use Bearer Token. AWS Credentials take precedence if both are provided.").font(.footnote)) {
                    EmptyView()
                }
            }
            .navigationTitle("LLM Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LLMSettingsScreen()
}
