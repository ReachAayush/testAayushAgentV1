import SwiftUI
import EventKit

struct CalendarSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let calendarClient: CalendarClient
    @State private var calendars: [EKCalendar] = []

    // Persist selected IDs in AppStorage as a comma-separated list for simplicity
    @AppStorage("SelectedCalendarIDs") private var selectedIDsRaw: String = ""

    private func isSelected(_ id: String) -> Bool {
        let set = Set(selectedIDsRaw.split(separator: ",").map(String.init))
        return set.contains(id)
    }

    private func setSelected(_ id: String, _ isOn: Bool) {
        var set = Set(selectedIDsRaw.split(separator: ",").map(String.init))
        if isOn { set.insert(id) } else { set.remove(id) }
        selectedIDsRaw = set.joined(separator: ",")
    }

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
                    ForEach(calendars, id: \.calendarIdentifier) { cal in
                        HStack(spacing: 16) {
                            // Calendar color indicator
                            if let color = cal.cgColor {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(color))
                                    .frame(width: 4, height: 40)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(cal.title)
                                    .font(.headline)
                                    .foregroundColor(SteelersTheme.textPrimary)
                                Text(cal.source.title)
                                    .font(.caption)
                                    .foregroundColor(SteelersTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { isSelected(cal.calendarIdentifier) },
                                set: { isOn in setSelected(cal.calendarIdentifier, isOn) }
                            ))
                            .tint(SteelersTheme.steelersGold)
                            .labelsHidden()
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(SteelersTheme.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Calendars")
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
            }
            .task {
                // Ensure access granted before listing
                try? await calendarClient.requestAccessIfNeeded()
                calendars = calendarClient.fetchEventCalendars()
            }
        }
    }
}
