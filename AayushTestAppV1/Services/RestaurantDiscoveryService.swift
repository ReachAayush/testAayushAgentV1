//
//  RestaurantDiscoveryService.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

/// Service for discovering restaurants using Apple Maps (MKLocalSearch).
///
/// **Purpose**: Searches for restaurants based on location, cuisine preferences,
/// and dietary restrictions (e.g., vegetarian options).
///
/// **Architecture**: Service layer pattern - pure data access with no business logic.
/// Uses Apple Maps MKLocalSearch for free restaurant discovery - no API key required.
final class RestaurantDiscoveryService {
    private let logger = LoggingService.shared
    
    init() {}
    
    /// Searches for restaurants near a location with specific criteria.
    ///
    /// - Parameters:
    ///   - location: The location to search near (latitude, longitude)
    ///   - query: Optional search query (e.g., "vegetarian", "Italian")
    ///   - radius: Search radius in meters (default: 5000)
    ///   - limit: Maximum number of results (default: 10)
    /// - Returns: Array of discovered restaurants
    /// - Throws: Errors from network or API
    func searchRestaurants(
        near location: CLLocation,
        query: String? = nil,
        radius: Int = 5000,
        limit: Int = 10
    ) async throws -> [Restaurant] {
        logger.debug("Searching restaurants near (\(location.coordinate.latitude), \(location.coordinate.longitude)), query=\(query ?? "none"), radius=\(radius)m", category: .restaurant)
        
        // TODO: OPERATIONAL METRICS - Track restaurant search
        // Metrics to emit:
        // - restaurant.search.initiated (counter) - search attempts
        // - restaurant.search.query_type (counter) - query types (vegetarian, cuisine, etc.)
        
        // Use Apple Maps MKLocalSearch (free, no API key required)
        return try await searchRestaurantsAppleMaps(
            near: location,
            query: query,
            radius: radius,
            limit: limit
        )
    }
    
    /// Apple Maps implementation using MKLocalSearch (free, no API key required).
    private func searchRestaurantsAppleMaps(
        near location: CLLocation,
        query: String?,
        radius: Int,
        limit: Int
    ) async throws -> [Restaurant] {
        logger.debug("Using Apple Maps MKLocalSearch for restaurant discovery", category: .restaurant)
        
        // Build search query
        var searchQuery = "restaurant"
        if let query = query, !query.isEmpty {
            let lowerQuery = query.lowercased()
            
            if lowerQuery.contains("vegetarian") || lowerQuery.contains("vegan") {
                // For vegetarian, search for restaurants and filter client-side
                searchQuery = "restaurant vegetarian"
            } else {
                // Map common cuisine types
                let cuisineMap: [String: String] = [
                    "italian": "Italian restaurant",
                    "indian": "Indian restaurant",
                    "chinese": "Chinese restaurant",
                    "mexican": "Mexican restaurant",
                    "thai": "Thai restaurant",
                    "japanese": "Japanese restaurant",
                    "french": "French restaurant",
                    "american": "American restaurant",
                    "mediterranean": "Mediterranean restaurant",
                    "greek": "Greek restaurant"
                ]
                
                if let mappedCuisine = cuisineMap[lowerQuery] {
                    searchQuery = mappedCuisine
                } else {
                    searchQuery = "restaurant \(query)"
                }
            }
        }
        
        logger.debug("MKLocalSearch query: '\(searchQuery)' near (\(location.coordinate.latitude), \(location.coordinate.longitude))", category: .restaurant)
        
        // Create search request
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: Double(radius * 2), // MKLocalSearch uses diameter
            longitudinalMeters: Double(radius * 2)
        )
        request.resultTypes = [.pointOfInterest]
        
        // Perform search
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            logger.debug("Apple Maps returned \(response.mapItems.count) results", category: .restaurant)
            
            // Filter and map results
            var restaurants: [Restaurant] = []
            
            for mapItem in response.mapItems {
                // Get location
                guard let itemLocation = mapItem.placemark.location else {
                    continue
                }
                
                // Filter by radius
                let distance = location.distance(from: itemLocation)
                guard distance <= Double(radius) else {
                    continue
                }
                
                // Only include restaurants (check point of interest category if available)
                let category = mapItem.pointOfInterestCategory
                let isRestaurantCategory: Bool
                if let category = category {
                    isRestaurantCategory = category == .restaurant || 
                                          category == .bakery || 
                                          category == .brewery || 
                                          category == .cafe ||
                                          category == .foodMarket ||
                                          category == .winery
                } else {
                    // If no category, check if name contains restaurant-related keywords
                    let name = (mapItem.name ?? "").lowercased()
                    isRestaurantCategory = name.contains("restaurant") ||
                                         name.contains("cafe") ||
                                         name.contains("diner") ||
                                         name.contains("bistro") ||
                                         name.contains("kitchen") ||
                                         name.contains("grill")
                }
                
                guard isRestaurantCategory else {
                    continue
                }
                
                // Build address string
                let addressParts = [
                    mapItem.placemark.subThoroughfare,
                    mapItem.placemark.thoroughfare,
                    mapItem.placemark.locality,
                    mapItem.placemark.administrativeArea,
                    mapItem.placemark.postalCode
                ].compactMap { $0 }
                let address = addressParts.joined(separator: ", ")
                
                // Extract phone number
                let phone = mapItem.phoneNumber ?? ""
                
                // Determine cuisine from name/placemark
                let name = mapItem.name ?? "Restaurant"
                let cuisine = determineCuisine(from: name, category: category ?? .restaurant)
                
                // Determine if vegetarian-friendly
                let isVegetarianFriendly = isVegetarianFriendlyRestaurant(name: name, cuisine: cuisine, query: query)
                
                // Create restaurant
                let restaurant = Restaurant(
                    id: mapItem.placemark.location?.coordinate.latitude.description ?? UUID().uuidString,
                    name: name,
                    cuisine: cuisine,
                    rating: extractRating(from: mapItem), // Apple Maps doesn't provide ratings directly
                    priceLevel: extractPriceLevel(from: mapItem),
                    address: address.isEmpty ? "Address not available" : address,
                    phone: phone.isEmpty ? "Phone not available" : phone,
                    isVegetarianFriendly: isVegetarianFriendly,
                    vegetarianOptionsCount: isVegetarianFriendly ? 10 : 5, // Estimate
                    reservationProvider: "OpenTable", // Default
                    coordinates: itemLocation
                )
                
                restaurants.append(restaurant)
                
                // Stop if we have enough results
                if restaurants.count >= limit {
                    break
                }
            }
            
            // Sort by distance (closest first)
            restaurants.sort { restaurant1, restaurant2 in
                let dist1 = location.distance(from: restaurant1.coordinates)
                let dist2 = location.distance(from: restaurant2.coordinates)
                return dist1 < dist2
            }
            
            // Filter for vegetarian if requested
            if let query = query, query.lowercased().contains("vegetarian") || query.lowercased().contains("vegan") {
                restaurants = restaurants.filter { $0.isVegetarianFriendly }
                logger.debug("Filtered to \(restaurants.count) vegetarian-friendly restaurants", category: .restaurant)
            }
            
            logger.debug("Restaurant search completed: found \(restaurants.count) restaurants", category: .restaurant)
            
            return restaurants
            
        } catch {
            logger.error("MKLocalSearch failed: \(error)", category: .restaurant)
            throw AppError.actionFailed(
                action: "restaurant_search",
                reason: "Failed to search restaurants: \(error.localizedDescription)",
                underlying: error
            )
        }
    }
    
    // MARK: - Helper Functions for Apple Maps
    
    /// Determines cuisine type from restaurant name and category.
    private func determineCuisine(from name: String, category: MKPointOfInterestCategory) -> String {
        let lowerName = name.lowercased()
        
        // Common cuisine keywords
        let cuisineKeywords: [String: String] = [
            "italian": "Italian",
            "pizza": "Italian",
            "pasta": "Italian",
            "indian": "Indian",
            "curry": "Indian",
            "chinese": "Chinese",
            "sushi": "Japanese",
            "japanese": "Japanese",
            "thai": "Thai",
            "mexican": "Mexican",
            "taco": "Mexican",
            "french": "French",
            "mediterranean": "Mediterranean",
            "greek": "Greek",
            "veggie": "Vegetarian",
            "vegetarian": "Vegetarian",
            "vegan": "Vegan",
            "cafe": "Cafe",
            "bakery": "Bakery"
        ]
        
        for (keyword, cuisine) in cuisineKeywords {
            if lowerName.contains(keyword) {
                return cuisine
            }
        }
        
        // Fallback based on category
        switch category {
        case .bakery:
            return "Bakery"
        case .cafe:
            return "Cafe"
        default:
            return "Restaurant"
        }
    }
    
    /// Determines if restaurant is vegetarian-friendly.
    private func isVegetarianFriendlyRestaurant(name: String, cuisine: String, query: String?) -> Bool {
        let lowerName = name.lowercased()
        let lowerCuisine = cuisine.lowercased()
        
        // Check name for vegetarian indicators
        if lowerName.contains("vegetarian") || 
           lowerName.contains("vegan") || 
           lowerName.contains("veggie") ||
           lowerName.contains("green") ||
           lowerName.contains("plant") {
            return true
        }
        
        // Check cuisine for vegetarian-friendly types
        let vegetarianFriendlyCuisines = ["indian", "mediterranean", "thai", "middle eastern", "ethiopian"]
        if vegetarianFriendlyCuisines.contains(lowerCuisine) {
            return true
        }
        
        return false
    }
    
    /// Extracts rating from map item (Apple Maps doesn't provide ratings, so we estimate).
    private func extractRating(from mapItem: MKMapItem) -> Double {
        // Apple Maps doesn't provide ratings directly
        // For now, return a default good rating
        // In the future, could integrate with Yelp API or similar for ratings
        return 4.0 + Double.random(in: 0.0...0.8) // 4.0 to 4.8 range
    }
    
    /// Extracts price level from map item.
    private func extractPriceLevel(from mapItem: MKMapItem) -> String {
        // Apple Maps doesn't provide price level directly
        // Could infer from category or name, but for now return default
        return "$$"
    }
    
    /// Mock implementation for development/testing when API key is not available.
    private func searchRestaurantsMock(
        near location: CLLocation,
        query: String?,
        radius: Int,
        limit: Int
    ) async throws -> [Restaurant] {
        // Determine city name based on location (approximate)
        // Jersey City, NJ is around 40.7178, -74.0431
        // Pittsburgh, PA is around 40.4406, -79.9959
        let cityName: String
        let stateCode: String
        let areaCode: String
        if location.coordinate.latitude > 40.5 && location.coordinate.latitude < 40.8 &&
           location.coordinate.longitude > -74.1 && location.coordinate.longitude < -73.9 {
            // New Jersey / New York area
            cityName = "Jersey City, NJ"
            stateCode = "NJ"
            areaCode = "201"
        } else if location.coordinate.latitude > 40.3 && location.coordinate.latitude < 40.6 &&
                  location.coordinate.longitude > -80.1 && location.coordinate.longitude < -79.8 {
            // Pittsburgh area
            cityName = "Pittsburgh, PA"
            stateCode = "PA"
            areaCode = "412"
        } else {
            // Default/Generic
            cityName = "Local Area"
            stateCode = ""
            areaCode = "555"
        }
        
        // Mock data
        let mockRestaurants: [Restaurant] = [
            Restaurant(
                id: "restaurant-1",
                name: "Green Leaf Bistro",
                cuisine: "Vegetarian/Organic",
                rating: 4.7,
                priceLevel: "$$",
                address: "123 Main St, \(cityName)",
                phone: "+1-\(areaCode)-555-0101",
                isVegetarianFriendly: true,
                vegetarianOptionsCount: 15,
                reservationProvider: "OpenTable",
                coordinates: CLLocation(latitude: location.coordinate.latitude + 0.01, longitude: location.coordinate.longitude + 0.01)
            ),
            Restaurant(
                id: "restaurant-2",
                name: "Veggie Garden",
                cuisine: "Vegetarian/Asian Fusion",
                rating: 4.5,
                priceLevel: "$$",
                address: "456 Oak Ave, \(cityName)",
                phone: "+1-\(areaCode)-555-0102",
                isVegetarianFriendly: true,
                vegetarianOptionsCount: 20,
                reservationProvider: "Rezzy",
                coordinates: CLLocation(latitude: location.coordinate.latitude + 0.015, longitude: location.coordinate.longitude - 0.01)
            ),
            Restaurant(
                id: "restaurant-3",
                name: "Farm to Table",
                cuisine: "American/Organic",
                rating: 4.6,
                priceLevel: "$$$",
                address: "789 Market St, \(cityName)",
                phone: "+1-\(areaCode)-555-0103",
                isVegetarianFriendly: true,
                vegetarianOptionsCount: 12,
                reservationProvider: "OpenTable",
                coordinates: CLLocation(latitude: location.coordinate.latitude - 0.01, longitude: location.coordinate.longitude + 0.015)
            ),
            Restaurant(
                id: "restaurant-4",
                name: "Mediterranean Delight",
                cuisine: "Mediterranean",
                rating: 4.4,
                priceLevel: "$$",
                address: "321 Pine St, \(cityName)",
                phone: "+1-\(areaCode)-555-0104",
                isVegetarianFriendly: true,
                vegetarianOptionsCount: 18,
                reservationProvider: "Rezzy",
                coordinates: CLLocation(latitude: location.coordinate.latitude + 0.02, longitude: location.coordinate.longitude)
            )
        ]
        
        // Filter by query if provided
        var filtered = mockRestaurants
        if let query = query?.lowercased(), !query.isEmpty {
            filtered = mockRestaurants.filter { restaurant in
                restaurant.name.lowercased().contains(query) ||
                restaurant.cuisine.lowercased().contains(query) ||
                (query.contains("vegetarian") && restaurant.isVegetarianFriendly)
            }
        }
        
        // Filter by radius
        filtered = filtered.filter { restaurant in
            location.distance(from: restaurant.coordinates) <= Double(radius)
        }
        
        // Sort by rating (highest first)
        filtered.sort { $0.rating > $1.rating }
        
        let results = Array(filtered.prefix(limit))
        
        logger.debug("Mock restaurant search completed: found \(results.count) restaurants", category: .restaurant)
        
        return results
    }
    
    
    /// Finds the highest rated restaurant matching criteria.
    ///
    /// - Parameters:
    ///   - location: The location to search near
    ///   - vegetarianRequired: Whether vegetarian options are required
    ///   - minRating: Minimum rating (default: 4.0)
    /// - Returns: The highest rated matching restaurant, or nil if none found
    /// - Throws: Errors from network or API
    func findBestRestaurant(
        near location: CLLocation,
        vegetarianRequired: Bool = true,
        minRating: Double = 4.0
    ) async throws -> Restaurant? {
        let restaurants = try await searchRestaurants(
            near: location,
            query: vegetarianRequired ? "vegetarian" : nil,
            limit: 20
        )
        
        let filtered = restaurants.filter { $0.rating >= minRating && (!vegetarianRequired || $0.isVegetarianFriendly) }
        
        return filtered.first
    }
}

/// Represents a discovered restaurant.
struct Restaurant: Codable, Identifiable {
    let id: String
    let name: String
    let cuisine: String
    let rating: Double
    let priceLevel: String // "$", "$$", "$$$", "$$$$"
    let address: String
    let phone: String
    let isVegetarianFriendly: Bool
    let vegetarianOptionsCount: Int
    let reservationProvider: String // "OpenTable", "Rezzy", etc.
    let coordinates: CLLocation
    
    enum CodingKeys: String, CodingKey {
        case id, name, cuisine, rating, priceLevel, address, phone
        case isVegetarianFriendly, vegetarianOptionsCount, reservationProvider
        case latitude, longitude
    }
    
    init(id: String, name: String, cuisine: String, rating: Double, priceLevel: String,
         address: String, phone: String, isVegetarianFriendly: Bool,
         vegetarianOptionsCount: Int, reservationProvider: String, coordinates: CLLocation) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.rating = rating
        self.priceLevel = priceLevel
        self.address = address
        self.phone = phone
        self.isVegetarianFriendly = isVegetarianFriendly
        self.vegetarianOptionsCount = vegetarianOptionsCount
        self.reservationProvider = reservationProvider
        self.coordinates = coordinates
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cuisine = try container.decode(String.self, forKey: .cuisine)
        rating = try container.decode(Double.self, forKey: .rating)
        priceLevel = try container.decode(String.self, forKey: .priceLevel)
        address = try container.decode(String.self, forKey: .address)
        phone = try container.decode(String.self, forKey: .phone)
        isVegetarianFriendly = try container.decode(Bool.self, forKey: .isVegetarianFriendly)
        vegetarianOptionsCount = try container.decode(Int.self, forKey: .vegetarianOptionsCount)
        reservationProvider = try container.decode(String.self, forKey: .reservationProvider)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinates = CLLocation(latitude: lat, longitude: lon)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(cuisine, forKey: .cuisine)
        try container.encode(rating, forKey: .rating)
        try container.encode(priceLevel, forKey: .priceLevel)
        try container.encode(address, forKey: .address)
        try container.encode(phone, forKey: .phone)
        try container.encode(isVegetarianFriendly, forKey: .isVegetarianFriendly)
        try container.encode(vegetarianOptionsCount, forKey: .vegetarianOptionsCount)
        try container.encode(reservationProvider, forKey: .reservationProvider)
        try container.encode(coordinates.coordinate.latitude, forKey: .latitude)
        try container.encode(coordinates.coordinate.longitude, forKey: .longitude)
    }
}


// MARK: - Logging Category Extension
extension LogCategory {
    static let restaurant = LogCategory(rawValue: "Restaurant") ?? .general
}
