import SwiftUI

struct ToneTrainerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ToneProfileStore
    @ObservedObject var favorites: FavoriteContactsStore
    let llm: LLMClient

    @State private var rawInput: String = ""
    @State private var isBusy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Paste messages you've sent (one per line or separated by ---)")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                            
                            TextEditor(text: $rawInput)
                                .frame(minHeight: 160)
                                .font(.body)
                                .foregroundColor(SteelersTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .background(SteelersTheme.darkGray)
                                .cornerRadius(12)
                                .padding(.top, 8)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Training Samples")
                            .foregroundColor(SteelersTheme.textPrimary)
                    }

                    if !store.toneSummary.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(store.toneSummary)
                                    .font(.body)
                                    .foregroundColor(SteelersTheme.textPrimary)
                                    .textSelection(.enabled)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SteelersTheme.darkGray)
                                    .cornerRadius(12)
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.clear)
                        } header: {
                            Text("Current Tone Profile")
                                .foregroundColor(SteelersTheme.textPrimary)
                        }
                    }

                    if let err = error {
                        Section {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .foregroundColor(.red)
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Tone Trainer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .foregroundColor(SteelersTheme.steelersGold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await generateTone() }
                    } label: {
                        if isBusy {
                            ProgressView()
                                .tint(SteelersTheme.steelersGold)
                        } else {
                            Text("Generate")
                                .foregroundColor(SteelersTheme.steelersGold)
                        }
                    }
                    .disabled(isBusy || !rawInput.hasNonEmptyContent)
                }
            }
        }
    }

    private func generateTone() async {
        isBusy = true; error = nil
        defer { isBusy = false }
        let samples = rawInput
            .components(separatedBy: "\n")
            .compactMap { $0.trimmed.nonEmptyTrimmed }
        do {
            let result = try await llm.generateToneSummaryPayload(from: samples)
            store.setSamples(samples)
            store.setToneSummary(result.tone)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
