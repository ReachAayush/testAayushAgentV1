//
//  RestaurantReservationAction.swift
//  AayushTestAppV1
//
//

import Foundation
import CoreLocation

/// Action that finds high-rated restaurants with vegetarian options.
///
/// **Purpose**: Searches for restaurants with vegetarian options and returns 5-10 options.
/// User can then open selected restaurant in Google Maps to make a reservation.
///
/// **Architecture**: Follows the `AgentAction` protocol. Directly calls restaurant service
/// without LLM orchestration for better performance and lower cost.
struct RestaurantReservationAction: AgentAction {
    // MARK: - AgentAction Conformance
    let id = "restaurant-reservation"
    let displayName = "Restaurant Reservation"
    let summary = "Finds 5-10 high-rated restaurants with vegetarian options for you to choose from."
    
    // MARK: - Dependencies
    let locationClient: LocationClient
    let restaurantService: RestaurantDiscoveryService
    
    // MARK: - Parameters
    let location: CLLocation?
    
    // MARK: - AgentAction Implementation
    
    /// Executes the restaurant search workflow.
    ///
    /// - Returns: `AgentActionResult.text` containing the restaurant options
    /// - Throws: Errors from location or restaurant search
    func run() async throws -> AgentActionResult {
        let logger = LoggingService.shared
        logger.debug("Restaurant search action started", category: .action)
        
        // Get user location
        let userLocation: CLLocation
        if let location = location {
            userLocation = location
        } else {
            logger.debug("Requesting user location", category: .action)
            userLocation = try await locationClient.getCurrentLocation()
        }
        
        // Directly search for restaurants (no LLM needed)
        logger.debug("Searching restaurants near location (\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude))", category: .action)
        
        // Start with initial radius, retry with larger radius if not enough results after deduplication
        let minDesiredResults = 5
        var restaurants: [Restaurant] = []
        var searchRadius = 5000 // Start with 5km
        let maxRadius = 20000 // Maximum radius to try (20km)
        
        // Use filters to ensure quality results (vegetarian)
        // Note: We use both query and filter - query helps Apple Maps find relevant restaurants,
        // and the filter ensures we only keep vegetarian-friendly ones
        let filters = RestaurantSearchFilters(
            vegetarianRequired: true
        )
        
        // Search and deduplicate, expanding radius if needed
        while searchRadius <= maxRadius {
            restaurants = try await restaurantService.searchRestaurants(
                near: userLocation,
                query: "vegetarian restaurants", // Help Apple Maps find vegetarian-friendly restaurants
                radius: searchRadius,
                limit: searchRadius > 5000 ? 25 : 20, // Allow more results for larger searches
                filters: filters
            )
            
            logger.debug("Restaurant search completed with \(searchRadius)m radius, found \(restaurants.count) restaurants (before deduplication)", category: .action)
            
            // Deduplicate restaurants
            restaurants = RestaurantDeduplicator.deduplicate(restaurants, from: userLocation)
            
            logger.debug("After deduplication: \(restaurants.count) unique restaurants", category: .action)
            
            // If we have enough unique restaurants, we're done
            if restaurants.count >= minDesiredResults {
                break
            }
            
            // Otherwise, expand search radius and try again
            if searchRadius < maxRadius {
                let nextRadius = min(searchRadius * 2, maxRadius)
                logger.debug("Found only \(restaurants.count) unique restaurants, expanding search to \(nextRadius)m radius", category: .action)
                searchRadius = nextRadius
            } else {
                // Reached max radius, use what we have
                break
            }
        }
        
        logger.debug("Final restaurant search result: \(restaurants.count) unique restaurants", category: .action)
        
        // Build result message with embedded JSON for UI parsing
        let restaurantsJson = restaurants.map { restaurant in
            [
                "id": restaurant.id,
                "name": restaurant.name,
                "cuisine": restaurant.cuisine,
                "address": restaurant.address,
                "phone": restaurant.phone,
                "isVegetarianFriendly": restaurant.isVegetarianFriendly,
                "vegetarianOptionsCount": restaurant.vegetarianOptionsCount,
                "latitude": restaurant.coordinates.coordinate.latitude,
                "longitude": restaurant.coordinates.coordinate.longitude
            ]
        }
        
        var finalMessage = "Found \(restaurants.count) restaurant option\(restaurants.count == 1 ? "" : "s") with vegetarian options for you to choose from."
        
        // Embed restaurant data as JSON for UI parsing
        if let jsonData = try? JSONSerialization.data(withJSONObject: ["restaurants": restaurantsJson]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            finalMessage += "\n\n<!--RESTAURANT_DATA:" + jsonString + "-->"
        }
        
        return .text(finalMessage)
    }
    
}
