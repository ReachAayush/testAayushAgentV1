//
//  RestaurantReservationView.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
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
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(selected.name)
                                                .font(.headline)
                                                .foregroundColor(SteelersTheme.textPrimary)
                                            Text(selected.cuisine)
                                                .font(.subheadline)
                                                .foregroundColor(SteelersTheme.textSecondary)
                                            HStack(spacing: 6) {
                                                Text("⭐ \(String(format: "%.1f", selected.rating))")
                                                Text("•")
                                                Text(selected.priceLevel)
                                                if let currentLoc = currentLocation {
                                                    let transitMinutes = transitTimes[selected.id] ?? 0
                                                    if transitMinutes > 0 {
                                                        HStack(spacing: 2) {
                                                            Image(systemName: "tram.fill")
                                                                .font(.caption2)
                                                            Text("\(transitMinutes) min")
                                                        }
                                                    }
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundColor(SteelersTheme.steelersGold.opacity(0.8))
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
                            Text("The AI will search for 5-10 high-rated restaurants with vegetarian options near your location. Choose your favorite and open it in Apple Maps to see reservation options (OpenTable, Resy, etc.).")
                                .font(.caption)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding()
                        .steelersCard()
                        .padding(.horizontal, 20)
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
        // Reset state
        restaurantOptions = []
        selectedRestaurant = nil
        
        // Validate location access
        do {
            try await locationClient.requestAccessIfNeeded()
        } catch {
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
        
        // Ensure we show 5-10 options (filter to top rated if we got more)
        // Sort by rating first
        restaurantOptions = restaurantOptions.sorted { $0.rating > $1.rating }
        
        // If we have more than 10, take top 10
        if restaurantOptions.count > 10 {
            restaurantOptions = Array(restaurantOptions.prefix(10))
        }
        
        // Log if we have fewer than 5 options
        if restaurantOptions.count < 5 {
            let logger = LoggingService.shared
            logger.debug("Found \(restaurantOptions.count) restaurant option(s). Would prefer 5-10 if available.", category: .restaurant)
        }
        
        // Calculate transit times for all restaurants
        if let currentLoc = currentLocation {
            Task {
                await calculateTransitTimes(for: restaurantOptions, from: currentLoc)
            }
        }
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
                  let rating = restaurantDict["rating"] as? Double,
                  let priceLevel = restaurantDict["priceLevel"] as? String,
                  let address = restaurantDict["address"] as? String,
                  let phone = restaurantDict["phone"] as? String,
                  let isVegetarianFriendly = restaurantDict["isVegetarianFriendly"] as? Bool,
                  let vegetarianOptionsCount = restaurantDict["vegetarianOptionsCount"] as? Int,
                  let reservationProvider = restaurantDict["reservationProvider"] as? String,
                  let lat = restaurantDict["latitude"] as? Double,
                  let lon = restaurantDict["longitude"] as? Double else {
                return nil
            }
            
            let coordinates = CLLocation(latitude: lat, longitude: lon)
            return Restaurant(
                id: id,
                name: name,
                cuisine: cuisine,
                rating: rating,
                priceLevel: priceLevel,
                address: address,
                phone: phone,
                isVegetarianFriendly: isVegetarianFriendly,
                vegetarianOptionsCount: vegetarianOptionsCount,
                reservationProvider: reservationProvider,
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
        // URL encode restaurant name for search
        let restaurantNameEncoded = restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? restaurant.name
        
        // Try multiple Google Maps URL formats
        // Format 1: Search by restaurant name (most reliable for showing restaurant place card)
        let searchQuery = "\(restaurantNameEncoded) restaurant"
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
                    ForEach(restaurants) { restaurant in
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
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(restaurant.name)
                                        .font(.headline)
                                        .foregroundColor(SteelersTheme.textPrimary)
                                    Text(restaurant.cuisine)
                                        .font(.subheadline)
                                        .foregroundColor(SteelersTheme.textSecondary)
                                    HStack(spacing: 6) {
                                        Text("⭐ \(String(format: "%.1f", restaurant.rating))")
                                        Text("•")
                                        Text(restaurant.priceLevel)
                                        if let currentLoc = currentLocation {
                                            let transitMinutes = transitTimes[restaurant.id] ?? 0
                                            if transitMinutes > 0 {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "tram.fill")
                                                        .font(.caption2)
                                                    Text("\(transitMinutes) min")
                                                }
                                            }
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(SteelersTheme.steelersGold.opacity(0.8))
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
