import SwiftUI

/// TransitStopsManagementView
///
/// Management UI for adding, editing, and deleting saved transit destinations.
/// Used by the Google Maps transit flow (see PATHTrainView).
///
/// Design:
/// - Steelers-themed list UI
/// - Uses `TransitStopsStore` for persistence via UserDefaults
/// - Presents `StopEditorView` as a sheet for editing
struct TransitStopsManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TransitStopsStore
    @State private var editingStop: TransitStop?
    @State private var showingStopEditor = false
    @State private var editingName: String = ""
    @State private var editingDescription: String = ""

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
                        ForEach(store.stops) { stop in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 16) {
                                    // Icon
                                    ZStack {
                                        Circle()
                                            .fill(SteelersTheme.steelersGold.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(SteelersTheme.steelersGold)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stop.name)
                                            .font(.headline)
                                            .foregroundColor(SteelersTheme.textPrimary)
                                        if let desc = stop.description {
                                            Text(desc)
                                                .font(.subheadline)
                                                .foregroundColor(SteelersTheme.textSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Menu {
                                        Button {
                                            editingStop = stop
                                            editingName = stop.name
                                            editingDescription = stop.description ?? ""
                                            showingStopEditor = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            store.deleteStop(stop)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundColor(SteelersTheme.steelersGold)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(SteelersTheme.cardBackground)
                        }
                    } header: {
                        Text("Transit Stops")
                            .foregroundColor(SteelersTheme.textPrimary)
                    } footer: {
                        Text("Add stops by name. Google Maps will find the location when you get directions.")
                            .font(.caption)
                            .foregroundColor(SteelersTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Manage Stops")
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
                        editingStop = nil
                        editingName = ""
                        editingDescription = ""
                        showingStopEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(SteelersTheme.steelersGold)
                    }
                }
            }
            .sheet(isPresented: $showingStopEditor) {
                StopEditorView(
                    stop: editingStop,
                    name: $editingName,
                    description: $editingDescription,
                    store: store
                )
            }
        }
    }
}

/// StopEditorView
///
/// Simple form for creating or editing a `TransitStop`. The editor writes changes
/// back to `TransitStopsStore` and dismisses itself on save.
///
/// Note: Coordinates are not stored or resolved here — Google Maps resolves the
/// destination by name/address when opening directions.
struct StopEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let stop: TransitStop?
    @Binding var name: String
    @Binding var description: String
    @ObservedObject var store: TransitStopsStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Location Name", text: $name)
                            .foregroundColor(SteelersTheme.textPrimary)
                            .autocapitalization(.words)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Location")
                            .foregroundColor(SteelersTheme.textPrimary)
                    } footer: {
                        Text("Enter the location name or address (e.g., 'Hoboken PATH Station' or 'Port Authority Bus Terminal, New York')")
                            .font(.caption)
                            .foregroundColor(SteelersTheme.textSecondary)
                    }
                    
                    Section {
                        TextField("Description (optional)", text: $description)
                            .foregroundColor(SteelersTheme.textPrimary)
                    } header: {
                        Text("Description")
                            .foregroundColor(SteelersTheme.textPrimary)
                    } footer: {
                        Text("Add a note to help identify this stop (e.g., 'Home station' or 'Work')")
                            .font(.caption)
                            .foregroundColor(SteelersTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(stop == nil ? "Add Stop" : "Edit Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SteelersTheme.steelersGold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveStop()
                    }
                    .foregroundColor(SteelersTheme.steelersGold)
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveStop() {
        let newStop = TransitStop(
            id: stop?.id ?? UUID(),
            name: name,
            description: description.isEmpty ? nil : description
        )
        
        if stop == nil {
            store.addStop(newStop)
        } else {
            store.updateStop(newStop)
        }
        
        dismiss()
    }
}
