import SwiftUI

struct SummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var agent: AgentController
    
    @AppStorage("SelectedCalendarIDs") private var selectedCalendarIDsRaw: String = ""
    @State private var showingCalendarSelection = false
    
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 50))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("Day Summary")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SteelersTheme.textPrimary)
                            Text("Get an AI-powered summary of your day")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Calendar Selection Card
                        Button {
                            showingCalendarSelection = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.gear")
                                    .font(.title2)
                                    .foregroundColor(SteelersTheme.steelersGold)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Calendar Settings")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Text(selectedCalendarIDsRaw.isEmpty ? "All calendars" : "\(selectedCalendarIDsRaw.split(separator: ",").count) selected")
                                        .font(.subheadline)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(SteelersTheme.steelersGold)
                            }
                            .padding()
                            .steelersCard()
                        }
                        .padding(.horizontal, 20)
                        
                        // Generate Summary Button
                        Button {
                            Task {
                                let allowed: Set<String> = Set(selectedCalendarIDsRaw.split(separator: ",").map(String.init))
                                let action = SummarizeDayAction(
                                    calendar: agent.calendarClient,
                                    llm: agent.llmClient,
                                    allowedCalendarIDs: allowed.isEmpty ? nil : allowed,
                                    styleHint: nil
                                )
                                await agent.run(action: action)
                            }
                        } label: {
                            HStack {
                                if agent.isBusy {
                                    ProgressView()
                                        .tint(SteelersTheme.textOnGold)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(agent.isBusy ? "Generating Summary..." : "Generate Summary")
                                    .fontWeight(.semibold)
                            }
                        }
                        .steelersButton()
                        .padding(.horizontal, 20)
                        .disabled(agent.isBusy)
                        
                        // Summary Display Card
                        if !agent.lastOutput.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(SteelersTheme.steelersGold)
                                    Text("Your Day Summary")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Spacer()
                                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                }
                                
                                Divider()
                                    .background(SteelersTheme.steelersGold.opacity(0.3))
                                
                                Text(agent.lastOutput)
                                    .font(.body)
                                    .foregroundColor(SteelersTheme.textPrimary)
                                    .textSelection(.enabled)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SteelersTheme.darkGray)
                                    .cornerRadius(12)
                            }
                            .padding()
                            .steelersCard()
                            .padding(.horizontal, 20)
                        }
                        
                        // Error Display
                        if let error = agent.errorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("Error")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(SteelersTheme.textSecondary)
                            }
                            .padding()
                            .steelersCard()
                            .padding(.horizontal, 20)
                        }
                        
                        // Empty State
                        if agent.lastOutput.isEmpty && !agent.isBusy && agent.errorMessage == nil {
                            VStack(spacing: 16) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(SteelersTheme.steelersGold.opacity(0.5))
                                Text("No summary yet")
                                    .font(.headline)
                                    .foregroundColor(SteelersTheme.textSecondary)
                                Text("Tap the button above to generate an AI summary of your day")
                                    .font(.subheadline)
                                    .foregroundColor(SteelersTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(SteelersTheme.steelersGold)
                    }
                }
            }
            .sheet(isPresented: $showingCalendarSelection) {
                CalendarSelectionView(calendarClient: agent.calendarClient)
            }
        }
    }
}

