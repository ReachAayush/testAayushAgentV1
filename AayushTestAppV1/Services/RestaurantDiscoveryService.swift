//
//  RestaurantDiscoveryService.swift
//  AayushTestAppV1
//
//

import Foundation
import CoreLocation
import MapKit

/// Configuration for restaurant search filters.
struct RestaurantSearchFilters: CustomStringConvertible {
    /// Specific cuisine types to include. Empty array means all cuisines.
    var cuisines: [String] = []
    
    /// Whether to require vegetarian-friendly restaurants.
    var vegetarianRequired: Bool = false
    
    /// Whether to require vegan-friendly restaurants.
    var veganRequired: Bool = false
    
    /// Maximum distance in meters from search location. Nil means use search radius.
    var maxDistance: Int? = nil
    
    /// Minimum number of vegetarian options (if vegetarianRequired is true).
    var minVegetarianOptions: Int? = nil
    
    /// Default filters (no restrictions)
    nonisolated static let `default` = RestaurantSearchFilters()
    
    /// Filters for vegetarian restaurants
    nonisolated static let vegetarian = RestaurantSearchFilters(
        vegetarianRequired: true
    )
    
    var description: String {
        var parts: [String] = []
        if !cuisines.isEmpty { parts.append("cuisines:\(cuisines.joined(separator: ","))") }
        if vegetarianRequired { parts.append("vegetarian") }
        if veganRequired { parts.append("vegan") }
        if let maxDist = maxDistance { parts.append("maxDistance:\(maxDist)m") }
        if let minVegOptions = minVegetarianOptions { parts.append("minVegOptions:\(minVegOptions)") }
        return parts.isEmpty ? "none" : parts.joined(separator: ", ")
    }
}

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
        ///   - filters: Optional search filters for cuisine, etc.
    /// - Returns: Array of discovered restaurants
    /// - Throws: Errors from network or API
    func searchRestaurants(
        near location: CLLocation,
        query: String? = nil,
        radius: Int = 5000,
        limit: Int = 10,
        filters: RestaurantSearchFilters = .default
    ) async throws -> [Restaurant] {
        logger.debug("Searching restaurants near (\(location.coordinate.latitude), \(location.coordinate.longitude)), query=\(query ?? "none"), radius=\(radius)m, filters=\(filters)", category: .restaurant)
        
        // TODO: OPERATIONAL METRICS - Track restaurant search
        // Metrics to emit:
        // - restaurant.search.initiated (counter) - search attempts
        // - restaurant.search.query_type (counter) - query types (vegetarian, cuisine, etc.)
        
        // Use Apple Maps MKLocalSearch (free, no API key required)
        var restaurants = try await searchRestaurantsAppleMaps(
            near: location,
            query: query,
            radius: radius,
            limit: limit
        )
        
        // Apply filters using protocol-based approach
        let filterPredicates = filters.createFilters(referenceLocation: location)
        if !filterPredicates.isEmpty {
            restaurants = restaurants.filter { restaurant in
                filterPredicates.allSatisfy { $0.matches(restaurant, location: location) }
            }
            logger.debug("Applied \(filterPredicates.count) filters: \(restaurants.count) restaurants remaining", category: .restaurant)
        }
        
        return restaurants
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
        let searchQuery = buildSearchQuery(from: query)
        
        logger.debug("MKLocalSearch query: '\(searchQuery)' near (\(location.coordinate.latitude), \(location.coordinate.longitude))", category: .restaurant)
        
        // Create search request
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        
        // Use MKPointOfInterestFilter to restrict to restaurant categories (Apple's recommended approach)
        // This filters at the API level for better performance and accuracy
        let restaurantCategories: [MKPointOfInterestCategory] = [
            .restaurant,
            .cafe,
            .bakery,
            .brewery,
            .foodMarket,
            .winery
        ]
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: restaurantCategories)
        
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: Double(radius * 2), // MKLocalSearch uses diameter
            longitudinalMeters: Double(radius * 2)
        )
        // resultTypes can be omitted when using pointOfInterestFilter
        
        // Perform search
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            logger.debug("Apple Maps returned \(response.mapItems.count) results", category: .restaurant)
            
            // Map and filter results
            let restaurants = response.mapItems
                .compactMap { mapItem -> Restaurant? in
                    guard let itemLocation = mapItem.placemark.location,
                          location.distance(from: itemLocation) <= Double(radius),
                          RestaurantMapper.isRestaurant(mapItem) else {
                        return nil
                    }
                    // Debug: Log all available data for first restaurant (uncomment to see all data)
                    // if restaurants.isEmpty {
                    //     RestaurantMapper.logAllAvailableData(mapItem, logger: logger)
                    // }
                    return RestaurantMapper.map(mapItem, query: query, location: location)
                }
                .prefix(limit)
                .sorted { r1, r2 in
                    location.distance(from: r1.coordinates) < location.distance(from: r2.coordinates)
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
    
    // MARK: - Helper Functions
    
    /// Builds search query string from optional query parameter.
    private func buildSearchQuery(from query: String?) -> String {
        guard let query = query, !query.isEmpty else {
            return "restaurant"
        }
        
        let lowerQuery = query.lowercased()
        
        if lowerQuery.contains("vegetarian") || lowerQuery.contains("vegan") {
            return "restaurant vegetarian"
        }
        
        if let mappedCuisine = RestaurantSearchConstants.cuisineMap[lowerQuery] {
            return mappedCuisine
        }
        
        return "restaurant \(query)"
    }
    
    // MARK: - Legacy Helper Functions (kept for backward compatibility)
    
    
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
        let areaCode: String
        if location.coordinate.latitude > 40.5 && location.coordinate.latitude < 40.8 &&
           location.coordinate.longitude > -74.1 && location.coordinate.longitude < -73.9 {
            // New Jersey / New York area
            cityName = "Jersey City, NJ"
            areaCode = "201"
        } else if location.coordinate.latitude > 40.3 && location.coordinate.latitude < 40.6 &&
                  location.coordinate.longitude > -80.1 && location.coordinate.longitude < -79.8 {
            // Pittsburgh area
            cityName = "Pittsburgh, PA"
            areaCode = "412"
        } else {
            // Default/Generic
            cityName = "Local Area"
            areaCode = "555"
        }
        
        // Mock data
        let mockRestaurants: [Restaurant] = [
            Restaurant(
                id: "restaurant-1",
                name: "Green Leaf Bistro",
                cuisine: "Vegetarian/Organic",
                address: "123 Main St, \(cityName)",
                phone: "+1-\(areaCode)-555-0101",
                isVegetarianFriendly: true,
                vegetarianOptionsCount: 15,
                coordinates: CLLocation(latitude: location.coordinate.latitude + 0.01, longitude: location.coordinate.longitude + 0.01)
            ),
            Restaurant(
                id: "restaurant-2",
                name: "Veggie Garden",
                cuisine: "Vegetarian/Asian Fusion",
                address: "456 Oak Ave, \(cityName)",
                phone: "+1-\(areaCode)-555-0102",
                isVegetarianFriendly: true,
                vegetarianOptionsCount: 20,
                coordinates: CLLocation(latitude: location.coordinate.latitude + 0.015, longitude: location.coordinate.longitude - 0.01)
            ),
            Restaurant(
                id: "restaurant-3",
                name: "Farm to Table",
                cuisine: "American/Organic",
                address: "789 Market St, \(cityName)",
                phone: "+1-\(areaCode)-555-0103",
                isVegetarianFriendly: true,
                vegetarianOptionsCount: 12,
                coordinates: CLLocation(latitude: location.coordinate.latitude - 0.01, longitude: location.coordinate.longitude + 0.015)
            ),
            Restaurant(
                id: "restaurant-4",
                name: "Mediterranean Delight",
                cuisine: "Mediterranean",
                address: "321 Pine St, \(cityName)",
                phone: "+1-\(areaCode)-555-0104",
                isVegetarianFriendly: true,
                vegetarianOptionsCount: 18,
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
        
        // Sort by distance (closest first)
        filtered.sort { 
            location.distance(from: $0.coordinates) < location.distance(from: $1.coordinates)
        }
        
        let results = Array(filtered.prefix(limit))
        
        logger.debug("Mock restaurant search completed: found \(results.count) restaurants", category: .restaurant)
        
        return results
    }
    
    
    /// Finds the closest restaurant matching criteria.
    ///
    /// - Parameters:
    ///   - location: The location to search near
    ///   - vegetarianRequired: Whether vegetarian options are required
    /// - Returns: The closest matching restaurant, or nil if none found
    /// - Throws: Errors from network or API
    func findBestRestaurant(
        near location: CLLocation,
        vegetarianRequired: Bool = true
    ) async throws -> Restaurant? {
        let restaurants = try await searchRestaurants(
            near: location,
            query: vegetarianRequired ? "vegetarian" : nil,
            limit: 20
        )
        
        let filtered = restaurants.filter { !vegetarianRequired || $0.isVegetarianFriendly }
        
        // Return closest restaurant
        return filtered.min { 
            location.distance(from: $0.coordinates) < location.distance(from: $1.coordinates)
        }
    }
}

/// Represents a discovered restaurant.
struct Restaurant: Codable, Identifiable {
    let id: String
    let name: String
    let cuisine: String
    let address: String
    let phone: String
    let isVegetarianFriendly: Bool
    let vegetarianOptionsCount: Int
    let coordinates: CLLocation
    
    enum CodingKeys: String, CodingKey {
        case id, name, cuisine, address, phone
        case isVegetarianFriendly, vegetarianOptionsCount
        case latitude, longitude
    }
    
    init(id: String, name: String, cuisine: String,
         address: String, phone: String, isVegetarianFriendly: Bool,
         vegetarianOptionsCount: Int, coordinates: CLLocation) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.address = address
        self.phone = phone
        self.isVegetarianFriendly = isVegetarianFriendly
        self.vegetarianOptionsCount = vegetarianOptionsCount
        self.coordinates = coordinates
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cuisine = try container.decode(String.self, forKey: .cuisine)
        address = try container.decode(String.self, forKey: .address)
        phone = try container.decode(String.self, forKey: .phone)
        isVegetarianFriendly = try container.decode(Bool.self, forKey: .isVegetarianFriendly)
        vegetarianOptionsCount = try container.decode(Int.self, forKey: .vegetarianOptionsCount)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinates = CLLocation(latitude: lat, longitude: lon)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(cuisine, forKey: .cuisine)
        try container.encode(address, forKey: .address)
        try container.encode(phone, forKey: .phone)
        try container.encode(isVegetarianFriendly, forKey: .isVegetarianFriendly)
        try container.encode(vegetarianOptionsCount, forKey: .vegetarianOptionsCount)
        try container.encode(coordinates.coordinate.latitude, forKey: .latitude)
        try container.encode(coordinates.coordinate.longitude, forKey: .longitude)
    }
}


// MARK: - Logging Category Extension
extension LogCategory {
    static let restaurant = LogCategory(rawValue: "Restaurant") ?? .general
}
