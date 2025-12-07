//
//  RestaurantReservationAction.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
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
        
        let restaurants = try await restaurantService.searchRestaurants(
            near: userLocation,
            query: "vegetarian",
            radius: 5000,
            limit: 10
        )
        
        logger.debug("Restaurant search completed, found \(restaurants.count) restaurants", category: .action)
        
        // Build result message with embedded JSON for UI parsing
        let restaurantsJson = restaurants.map { restaurant in
            [
                "id": restaurant.id,
                "name": restaurant.name,
                "cuisine": restaurant.cuisine,
                "rating": restaurant.rating,
                "priceLevel": restaurant.priceLevel,
                "address": restaurant.address,
                "phone": restaurant.phone,
                "isVegetarianFriendly": restaurant.isVegetarianFriendly,
                "vegetarianOptionsCount": restaurant.vegetarianOptionsCount,
                "reservationProvider": restaurant.reservationProvider,
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
