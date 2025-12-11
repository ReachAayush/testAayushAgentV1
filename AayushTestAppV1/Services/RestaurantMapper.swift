//
//  RestaurantMapper.swift
//  AayushTestAppV1
//
//

import Foundation
import CoreLocation
import MapKit
import Contacts

/// Maps MKMapItem to Restaurant model.
enum RestaurantMapper {
    /// Determines if a map item represents a restaurant.
    static func isRestaurant(_ mapItem: MKMapItem) -> Bool {
        if let category = mapItem.pointOfInterestCategory {
            return RestaurantSearchConstants.restaurantCategories.contains(category)
        }
        
        // Fallback: check name for restaurant keywords
        let name = (mapItem.name ?? "").lowercased()
        return RestaurantSearchConstants.restaurantKeywords.contains { name.contains($0) }
    }
    
    /// Maps an MKMapItem to a Restaurant.
    static func map(_ mapItem: MKMapItem, query: String?, location: CLLocation) -> Restaurant? {
        guard let itemLocation = mapItem.placemark.location else { return nil }
        
        let name = mapItem.name ?? "Restaurant"
        let category = mapItem.pointOfInterestCategory ?? .restaurant
        let cuisine = determineCuisine(from: name, category: category)
        let isVegetarianFriendly = isVegetarianFriendly(name: name, cuisine: cuisine, query: query)
        
        // Use CNPostalAddressFormatter to get Apple's formatted address
        // This provides a properly formatted address string that matches Apple Maps display
        let address: String
        if let postalAddress = mapItem.placemark.postalAddress {
            let formatter = CNPostalAddressFormatter()
            address = formatter.string(from: postalAddress)
        } else {
            // Fallback: build from components if postal address not available
            let addressParts = [
                mapItem.placemark.subThoroughfare,
                mapItem.placemark.thoroughfare,
                mapItem.placemark.locality,
                mapItem.placemark.administrativeArea,
                mapItem.placemark.postalCode
            ].compactMap { $0 }
            address = addressParts.isEmpty ? "Address not available" : addressParts.joined(separator: ", ")
        }
        let phone = mapItem.phoneNumber ?? "Phone not available"
        
        return Restaurant(
            id: itemLocation.coordinate.latitude.description,
            name: name,
            cuisine: cuisine,
            address: address,
            phone: phone,
            isVegetarianFriendly: isVegetarianFriendly,
            vegetarianOptionsCount: isVegetarianFriendly ? 10 : 5,
            coordinates: itemLocation
        )
    }
    
    // MARK: - Private Helpers
    
    private static func determineCuisine(from name: String, category: MKPointOfInterestCategory) -> String {
        let lowerName = name.lowercased()
        
        for (keyword, cuisine) in RestaurantSearchConstants.cuisineKeywords {
            if lowerName.contains(keyword) {
                return cuisine
            }
        }
        
        switch category {
        case .bakery: return "Bakery"
        case .cafe: return "Cafe"
        default: return "Restaurant"
        }
    }
    
    private static func isVegetarianFriendly(name: String, cuisine: String, query: String?) -> Bool {
        let lowerName = name.lowercased()
        let lowerCuisine = cuisine.lowercased()
        
        // Check name for vegetarian keywords
        if RestaurantSearchConstants.vegetarianKeywords.contains(where: { lowerName.contains($0) }) {
            return true
        }
        
        // Check cuisine type
        if RestaurantSearchConstants.vegetarianFriendlyCuisines.contains(lowerCuisine) {
            return true
        }
        
        // If query is about vegetarian/vegan, be more lenient for restaurants that might have options
        // but don't explicitly advertise as vegetarian (e.g., Indian, Mediterranean restaurants)
        // However, we still require some indication (cuisine type or name pattern)
        if let query = query?.lowercased(), 
           (query.contains("vegetarian") || query.contains("vegan")) {
            // Only be lenient for cuisines that typically have vegetarian options
            // Don't mark everything as vegetarian just because we searched for it
            return RestaurantSearchConstants.vegetarianFriendlyCuisines.contains(lowerCuisine)
        }
        
        return false
    }
    
}
