//
//  RestaurantReservationView.swift
//  AayushTestAppV1
//
//

import SwiftUI
import CoreLocation
import MapKit

/// View for the restaurant reservation agentic workflow.
///
/// **Purpose**: Provides UI for users to request restaurant reservations. The agentic
/// workflow will automatically search for restaurants, select the best option, and
/// make a reservation.
struct RestaurantReservationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var agent: AgentController
    @ObservedObject var locationClient: LocationClient
    
    @State private var currentLocation: CLLocation?
    @State private var restaurantOptions: [Restaurant] = []
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantPicker = false
    @State private var transitTimes: [String: Int] = [:] // Restaurant ID -> transit minutes
    @State private var isSearching = false
    
    // Services
    private let restaurantService = RestaurantDiscoveryService()
    
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
                            Image(systemName: "fork.knife")
                                .font(.system(size: 50))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("Restaurant Reservation")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SteelersTheme.textPrimary)
                            Text("AI-powered restaurant discovery & booking")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Find Button
                        Button {
                            Task {
                                await findRestaurants()
                            }
                        } label: {
                            HStack {
                                if agent.isBusy {
                                    ProgressView()
                                        .tint(SteelersTheme.textOnGold)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(agent.isBusy ? "Finding..." : "Find")
                                    .fontWeight(.semibold)
                            }
                        }
                        .steelersButton()
                        .padding(.horizontal, 20)
                        .disabled(agent.isBusy)
                        
                        // Restaurant Selection Card
                        if !restaurantOptions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select a Restaurant")
                                    .font(.headline)
                                    .foregroundColor(SteelersTheme.textPrimary)
                                
                                if let selected = selectedRestaurant {
                                    // Selected restaurant display
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(SteelersTheme.steelersGold.opacity(0.2))
                                                .frame(width: 50, height: 50)
                                            Image(systemName: "fork.knife")
                                                .font(.title3)
                                                .foregroundColor(SteelersTheme.steelersGold)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(selected.name)
                                                .font(.headline)
                                                .foregroundColor(SteelersTheme.textPrimary)
                                            
                                            Text(selected.cuisine)
                                                .font(.subheadline)
                                                .foregroundColor(SteelersTheme.textSecondary)
                                            
                                            // Vegetarian Badge
                                            if selected.isVegetarianFriendly {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "leaf.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(.green)
                                                    Text("Vegetarian")
                                                        .font(.caption2)
                                                }
                                            }
                                            
                                            // Distance and Transit Time
                                            if let currentLoc = currentLocation {
                                                let distanceMeters = currentLoc.distance(from: selected.coordinates)
                                                let distanceMiles = distanceMeters / 1609.34
                                                let transitMinutes = transitTimes[selected.id] ?? 0
                                                
                                                HStack(spacing: 8) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "mappin.circle.fill")
                                                            .font(.caption2)
                                                            .foregroundColor(SteelersTheme.steelersGold)
                                                        Text(String(format: "%.1f mi", distanceMiles))
                                                    }
                                                    
                                                    if transitMinutes > 0 {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "tram.fill")
                                                                .font(.caption2)
                                                                .foregroundColor(SteelersTheme.steelersGold)
                                                            Text("\(transitMinutes) min")
                                                        }
                                                    }
                                                }
                                                .font(.caption)
                                                .foregroundColor(SteelersTheme.textSecondary)
                                            }
                                            
                                            // Address
                                            if !selected.address.isEmpty && selected.address != "Address not available" {
                                                Text(selected.address)
                                                    .font(.caption)
                                                    .foregroundColor(SteelersTheme.textSecondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            showingRestaurantPicker = true
                                        } label: {
                                            Text("Change")
                                                .font(.subheadline)
                                                .foregroundColor(SteelersTheme.steelersGold)
                                        }
                                    }
                                    .padding()
                                    .steelersCard()
                                    
                                    // Make Reservation Button
                                    Button {
                                        openInGoogleMaps(restaurant: selected)
                                    } label: {
                                        HStack {
                                            Image(systemName: "map.fill")
                                            Text("Open in Google Maps")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .steelersButton()
                                } else {
                                    Button {
                                        showingRestaurantPicker = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "fork.knife.circle.fill")
                                                .font(.title2)
                                            Text("Choose a Restaurant (\(restaurantOptions.count) options)")
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
                        }
                        
                        // Results Display (LLM response)
                        if !agent.lastOutput.isEmpty && restaurantOptions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Result")
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Spacer()
                                }
                                
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
                        
                        // Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(SteelersTheme.steelersGold)
                                Text("How it works")
                                    .font(.headline)
                                    .foregroundColor(SteelersTheme.textPrimary)
                            }
                            Text("The AI will search for 5-10 high-rated restaurants with vegetarian options near your location. Results are grouped by distance. Choose your favorite and open it in Google Maps to see available reservation options.")
                                .font(.caption)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding()
                        .steelersCard()
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
                
                // Loading overlay - shows when searching
                if isSearching || agent.isBusy {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(SteelersTheme.steelersGold)
                            
                            Text("Finding restaurants...")
                                .font(.headline)
                                .foregroundColor(SteelersTheme.textPrimary)
                        }
                        .padding(30)
                        .background(SteelersTheme.darkGray)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                    }
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
            .sheet(isPresented: $showingRestaurantPicker) {
                RestaurantPickerView(
                    restaurants: restaurantOptions,
                    selectedRestaurant: $selectedRestaurant,
                    currentLocation: currentLocation,
                    transitTimes: $transitTimes
                )
            }
            .onAppear {
                // Get location on appear
                Task {
                    do {
                        try await locationClient.requestAccessIfNeeded()
                        currentLocation = try? await locationClient.getCurrentLocation()
                    } catch {
                        // Location access not granted, will request when needed
                    }
                }
            }
        }
    }
    
    private func findRestaurants() async {
        // Show loading indicator
        isSearching = true
        
        // Reset state
        restaurantOptions = []
        selectedRestaurant = nil
        
        // Validate location access
        do {
            try await locationClient.requestAccessIfNeeded()
        } catch {
            isSearching = false
            agent.errorMessage = "Location access is required to find nearby restaurants."
            return
        }
        
        // Get current location (use cached if available, otherwise fetch)
        let location: CLLocation
        if let cachedLocation = currentLocation {
            location = cachedLocation
        } else {
            do {
                location = try await locationClient.getCurrentLocation()
                currentLocation = location
            } catch {
                isSearching = false
                agent.errorMessage = "Unable to get your location. Please try again."
                return
            }
        }
        
        // Create and run action
        let action = RestaurantReservationAction(
            locationClient: locationClient,
            restaurantService: restaurantService,
            location: location
        )
        
        await agent.run(action: action)
        
        // Parse restaurant options from embedded JSON in output
        if !agent.lastOutput.isEmpty {
            parseRestaurantsFromOutput(agent.lastOutput)
        }
        
        // Deduplicate restaurants (remove multiple branches of the same chain)
        // Note: Action already deduplicates, but this provides a safety net
        restaurantOptions = RestaurantDeduplicator.deduplicate(restaurantOptions, from: currentLocation ?? location)
        
        // Ensure we show 5-10 options (sort by distance if we got more)
        // Sort by distance first
        if let currentLoc = currentLocation {
            restaurantOptions = restaurantOptions.sorted { 
                currentLoc.distance(from: $0.coordinates) < currentLoc.distance(from: $1.coordinates)
            }
        }
        
        // If we have more than 10, take top 10
        if restaurantOptions.count > 10 {
            restaurantOptions = Array(restaurantOptions.prefix(10))
        }
        
        // Log if we have fewer than 5 options
        if restaurantOptions.count < 5 {
            let logger = LoggingService.shared
            logger.debug("Found \(restaurantOptions.count) restaurant option(s). Would prefer 5-10 if available.", category: .restaurant)
        }
        
        // Calculate transit times for all restaurants in background
        if let currentLoc = currentLocation {
            transitTimes = [:] // Reset transit times
            Task {
                await calculateTransitTimes(for: restaurantOptions, from: currentLoc)
            }
        }
        
        // Hide loading indicator
        isSearching = false
    }
    
    /// Parses restaurant data from LLM output (embedded as JSON comment).
    private func parseRestaurantsFromOutput(_ output: String) {
        // Look for embedded JSON in comment
        guard let range = output.range(of: "<!--RESTAURANT_DATA:", options: .backwards),
              let endRange = output.range(of: "-->", range: range.upperBound..<output.endIndex) else {
            return
        }
        
        let jsonString = String(output[range.upperBound..<endRange.lowerBound])
        
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let restaurantsArray = json["restaurants"] as? [[String: Any]] else {
            return
        }
        
        restaurantOptions = restaurantsArray.compactMap { restaurantDict in
            guard let id = restaurantDict["id"] as? String,
                  let name = restaurantDict["name"] as? String,
                  let cuisine = restaurantDict["cuisine"] as? String,
                  let address = restaurantDict["address"] as? String,
                  let phone = restaurantDict["phone"] as? String,
                  let isVegetarianFriendly = restaurantDict["isVegetarianFriendly"] as? Bool,
                  let vegetarianOptionsCount = restaurantDict["vegetarianOptionsCount"] as? Int,
                  let lat = restaurantDict["latitude"] as? Double,
                  let lon = restaurantDict["longitude"] as? Double else {
                return nil
            }
            
            let coordinates = CLLocation(latitude: lat, longitude: lon)
            return Restaurant(
                id: id,
                name: name,
                cuisine: cuisine,
                address: address,
                phone: phone,
                isVegetarianFriendly: isVegetarianFriendly,
                vegetarianOptionsCount: vegetarianOptionsCount,
                coordinates: coordinates
            )
        }
    }
    
    /// Calculates transit times for restaurants using MKDirections.
    private func calculateTransitTimes(for restaurants: [Restaurant], from location: CLLocation) async {
        await withTaskGroup(of: (String, Int).self) { group in
            for restaurant in restaurants {
                group.addTask {
                    let request = MKDirections.Request()
                    request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: restaurant.coordinates.coordinate))
                    request.transportType = .transit
                    request.requestsAlternateRoutes = false
                    
                    do {
                        let directions = MKDirections(request: request)
                        let response = try await directions.calculate()
                        
                        // Get ETA from first route
                        if let route = response.routes.first {
                            let transitMinutes = Int(route.expectedTravelTime / 60) // Convert to minutes
                            return (restaurant.id, transitMinutes)
                        }
                    } catch {
                        // If transit not available, leave as 0 (will just show walking time)
                    }
                    return (restaurant.id, 0)
                }
            }
            
            // Collect results
            for await (restaurantId, minutes) in group {
                transitTimes[restaurantId] = minutes
            }
        }
    }
    
    /// Opens Google Maps with the restaurant location, which will show the restaurant place card.
    /// Google Maps displays detailed restaurant information including reservation options.
    private func openInGoogleMaps(restaurant: Restaurant) {
        // Build search query with name and address for better reliability
        // This helps especially with restaurants that have special characters or common names
        var searchQuery = restaurant.name
        
        // Add address if available to make search more specific
        if !restaurant.address.isEmpty && restaurant.address != "Address not available" {
            // Extract just the street address (first part before city/state)
            let addressParts = restaurant.address.split(separator: ",")
            if let streetAddress = addressParts.first, !streetAddress.trimmingCharacters(in: .whitespaces).isEmpty {
                searchQuery += " \(streetAddress.trimmingCharacters(in: .whitespaces))"
            } else {
                // If we can't parse, just use the full address
                searchQuery += " \(restaurant.address)"
            }
        }
        
        // URL encode the search query
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
        
        // Try Google Maps app first (comgooglemaps:// URL scheme)
        if let googleMapsURL = URL(string: "comgooglemaps://?q=\(encodedQuery)"),
           UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL)
            return
        }
        
        // Fallback to Google Maps universal link (opens app if installed, otherwise web)
        if let universalURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)") {
            UIApplication.shared.open(universalURL)
            return
        }
        
        // Final fallback: coordinates-based search
        let lat = restaurant.coordinates.coordinate.latitude
        let lng = restaurant.coordinates.coordinate.longitude
        if let coordURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)") {
            UIApplication.shared.open(coordURL)
        }
    }
}

// Restaurant Picker Sheet (similar to ContactPickerView)
struct RestaurantPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let restaurants: [Restaurant]
    @Binding var selectedRestaurant: Restaurant?
    let currentLocation: CLLocation?
    @Binding var transitTimes: [String: Int]
    
    // Group restaurants by distance
    private var groupedRestaurants: RestaurantGrouper.GroupedRestaurants {
        guard let location = currentLocation else {
            // If no location, return empty groups
            return RestaurantGrouper.GroupedRestaurants(groups: [])
        }
        return RestaurantGrouper.group(restaurants, from: location)
    }
    
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
                    ForEach(groupedRestaurants.groups) { group in
                        Section(header: Text(group.title)
                            .font(.headline)
                            .foregroundColor(SteelersTheme.steelersGold)
                            .textCase(nil)) {
                            ForEach(group.restaurants) { restaurant in
                        Button {
                            selectedRestaurant = restaurant
                            dismiss()
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(SteelersTheme.steelersGold.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "fork.knife")
                                        .font(.title3)
                                        .foregroundColor(SteelersTheme.steelersGold)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(restaurant.name)
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    
                                    Text(restaurant.cuisine)
                                        .font(.subheadline)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                    
                                    // Vegetarian Badge
                                    if restaurant.isVegetarianFriendly {
                                        HStack(spacing: 4) {
                                            Image(systemName: "leaf.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Vegetarian")
                                                .font(.caption2)
                                        }
                                    }
                                    
                                    // Distance and Transit Time
                                    if let currentLoc = currentLocation {
                                        let distanceMeters = currentLoc.distance(from: restaurant.coordinates)
                                        let distanceMiles = distanceMeters / 1609.34
                                        let transitMinutes = transitTimes[restaurant.id] ?? 0
                                        
                                        HStack(spacing: 8) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(SteelersTheme.steelersGold)
                                                Text(String(format: "%.1f mi", distanceMiles))
                                            }
                                            
                                            if transitMinutes > 0 {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "tram.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(SteelersTheme.steelersGold)
                                                    Text("\(transitMinutes) min")
                                                }
                                            } else {
                                                // Show "calculating..." or nothing while transit is being calculated
                                                if restaurants.count > 0 && transitTimes.count < restaurants.count {
                                                    HStack(spacing: 4) {
                                                        ProgressView()
                                                            .scaleEffect(0.7)
                                                        Text("transit")
                                                            .font(.caption2)
                                                    }
                                                }
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                    }
                                    
                                    // Address
                                    if !restaurant.address.isEmpty && restaurant.address != "Address not available" {
                                        Text(restaurant.address)
                                            .font(.caption)
                                            .foregroundColor(SteelersTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedRestaurant?.id == restaurant.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(SteelersTheme.steelersGold)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(SteelersTheme.cardBackground)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Restaurant")
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

#Preview("RestaurantReservationView Preview") {
    let llm = LLMClient(apiKey: "preview", baseURL: URL(string: "https://example.com")!, model: "preview")
    let agent = AgentController(
        llmClient: llm,
        calendarClient: CalendarClient(),
        messagesClient: MessagesClient(),
        favoritesStore: FavoriteContactsStore()
    )
    return RestaurantReservationView(
        agent: agent,
        locationClient: LocationClient()
    )
}
