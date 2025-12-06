import SwiftUI
import CoreLocation
import UIKit

/// PATHTrainView — Preferred Transit Experience (Google Maps)
///
/// This view powers the transit directions feature using Google Maps URLs.
/// It replaces the legacy Apple Maps-based Transit (Maps) action.
///
/// Key points:
/// - Uses LocationClient to obtain the user's current location (async/await).
/// - Opens Google Maps app if installed, otherwise falls back to web.
/// - Destination is selected from user-managed `TransitStopsStore`.
struct PATHTrainView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationClient = LocationClient()
    @StateObject private var stopsStore = TransitStopsStore()
    
    @State private var isGettingLocation = false
    @State private var errorMessage: String?
    @State private var currentLocation: CLLocation?
    @State private var selectedStop: TransitStop?
    @State private var showingStopPicker = false
    @State private var showingManageStops = false
    
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
                            Image(systemName: "tram.fill")
                                .font(.system(size: 50))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("Transit Directions")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SteelersTheme.textPrimary)
                            Text("Find the next transit from your location")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Current Location Status
                        if let location = currentLocation {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(SteelersTheme.steelersGold)
                                    Text("Current Location")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                }
                                
                                Text("Using your current location as starting point")
                                    .font(.body)
                                    .foregroundColor(SteelersTheme.textSecondary)
                            }
                            .padding()
                            .steelersCard()
                            .padding(.horizontal, 20)
                        }
                        
                        // Destination Selection Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Destination")
                                .font(.headline)
                                .foregroundColor(SteelersTheme.textPrimary)
                            
                            if let stop = selectedStop {
                                // Selected stop display
                                HStack {
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
                                    
                                    Button {
                                        showingStopPicker = true
                                    } label: {
                                        Text("Change")
                                            .font(.subheadline)
                                            .foregroundColor(SteelersTheme.steelersGold)
                                    }
                                }
                                .padding()
                                .steelersCard()
                            } else {
                                Button {
                                    showingStopPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                        Text("Choose Destination")
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(SteelersTheme.steelersGold)
                                    .padding()
                                    .steelersCard()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Get Directions Button
                        if selectedStop != nil {
                            Button {
                                Task {
                                    await getDirections()
                                }
                            } label: {
                                HStack {
                                    if isGettingLocation {
                                        ProgressView()
                                            .tint(SteelersTheme.textOnGold)
                                    } else {
                                        Image(systemName: "magnifyingglass")
                                    }
                                    Text(isGettingLocation ? "Getting Location..." : "Get Directions to \(selectedStop?.name ?? "Destination")")
                                        .fontWeight(.semibold)
                                }
                            }
                            .steelersButton()
                            .padding(.horizontal, 20)
                            .disabled(isGettingLocation)
                        }
                        
                        // Manage Stops Button
                        Button {
                            showingManageStops = true
                        } label: {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Manage Stops")
                            }
                            .font(.subheadline)
                            .foregroundColor(SteelersTheme.steelersGold)
                        }
                        .padding(.horizontal, 20)
                        
                        // Error Display
                        if let error = errorMessage {
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
            .sheet(isPresented: $showingStopPicker) {
                StopPickerView(
                    stops: stopsStore.stops,
                    selectedStop: $selectedStop
                )
            }
            .sheet(isPresented: $showingManageStops) {
                TransitStopsManagementView(store: stopsStore)
            }
            .onAppear {
                // Auto-select first stop if none selected
                if selectedStop == nil, let firstStop = stopsStore.stops.first {
                    selectedStop = firstStop
                }
            }
        }
    }
    
    private func getDirections() async {
        isGettingLocation = true
        errorMessage = nil
        
        defer { isGettingLocation = false }
        
        guard let destination = selectedStop else {
            errorMessage = "Please select a destination"
            return
        }
        
        do {
            // Get current location for source
            let location = try await locationClient.getCurrentLocation()
            currentLocation = location
            
            // Open directions from current location (as coordinates) to destination (as address string)
            let sourceCoord = location.coordinate
            openDirections(
                fromCoordinate: sourceCoord,
                toAddress: destination.name
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func openDirections(
        fromCoordinate source: CLLocationCoordinate2D,
        toAddress destination: String
    ) {
        // Build saddr (lat,lng) and daddr (address string). We use address for destination
        // so Google Maps can resolve it flexibly.
        let saddr = "\(source.latitude),\(source.longitude)"
        let daddr = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        
        // Prefer the Google Maps URL scheme for the native app when available.
        let urlString = "comgooglemaps://?saddr=\(saddr)&daddr=\(daddr)&directionsmode=transit"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Unable to create Google Maps URL"
            return
        }
        
        // Note: Add "comgooglemaps" to LSApplicationQueriesSchemes in Info.plist for reliable canOpenURL checks.
        // Check if the Google Maps app is installed
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            // Fallback: open in the browser if the app isn't installed.
            let webUrlString = "https://www.google.com/maps/dir/?api=1&origin=\(saddr)&destination=\(daddr)&travelmode=transit"
            if let webUrl = URL(string: webUrlString) {
                UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
            } else {
                errorMessage = "Unable to open Google Maps. Please install the Google Maps app."
            }
        }
    }
}

// Stop Picker Sheet
/// StopPickerView
///
/// Sheet for choosing a destination from the user's saved stops. Updates the
/// binding and dismisses itself on selection.
struct StopPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let stops: [TransitStop]
    @Binding var selectedStop: TransitStop?
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                List {
                    ForEach(stops) { stop in
                        Button {
                            selectedStop = stop
                            dismiss()
                        } label: {
                            HStack {
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
                                
                                if selectedStop?.id == stop.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(SteelersTheme.steelersGold)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(SteelersTheme.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SteelersTheme.steelersGold)
                }
            }
        }
    }
}

#Preview {
    PATHTrainView()
}
