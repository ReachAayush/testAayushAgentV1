//
//  RestaurantSearchConstants.swift
//  AayushTestAppV1
//
//

import Foundation
import MapKit

/// Constants and configuration for restaurant search functionality.
enum RestaurantSearchConstants {
    // Search defaults
    static let defaultRadius: Int = 5000 // 5km
    static let defaultLimit: Int = 10
    static let maxRadius: Int = 20000 // 20km
    static let minDesiredResults: Int = 5
    
    // Restaurant-related POI categories
    static let restaurantCategories: Set<MKPointOfInterestCategory> = [
        .restaurant, .bakery, .brewery, .cafe, .foodMarket, .winery
    ]
    
    // Restaurant name keywords
    static let restaurantKeywords: Set<String> = [
        "restaurant", "cafe", "diner", "bistro", "kitchen", "grill"
    ]
    
    // Location suffixes for deduplication
    static let locationSuffixes: [String] = [
        " - downtown", " - uptown", " - midtown", " - east", " - west",
        " - north", " - south", " - central", " - main", " - plaza",
        " - mall", " - airport", " - station", " - square", " - center",
        " downtown", " uptown", " midtown", " east", " west",
        " north", " south", " central", " main", " plaza",
        " mall", " airport", " station", " square", " center"
    ]
    
    // Cuisine mapping for search queries
    static let cuisineMap: [String: String] = [
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
    
    // Cuisine detection keywords
    static let cuisineKeywords: [String: String] = [
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
    
    // Vegetarian-friendly cuisine types
    static let vegetarianFriendlyCuisines: Set<String> = [
        "indian", "mediterranean", "thai", "middle eastern", "ethiopian"
    ]
    
    // Vegetarian indicators in names
    static let vegetarianKeywords: Set<String> = [
        "vegetarian", "vegan", "veggie", "green", "plant"
    ]
}
