//
//  RestaurantFilter.swift
//  AayushTestAppV1
//
//

import Foundation
import CoreLocation

/// Protocol for restaurant filtering logic.
protocol RestaurantFilter {
    func matches(_ restaurant: Restaurant, location: CLLocation) -> Bool
}

/// Filter implementations
extension RestaurantSearchFilters {
    /// Creates an array of filter predicates from the filter configuration.
    func createFilters(referenceLocation: CLLocation) -> [RestaurantFilter] {
        var filters: [RestaurantFilter] = []
        
        if !cuisines.isEmpty {
            filters.append(CuisineFilter(allowedCuisines: cuisines))
        }
        
        if vegetarianRequired {
            filters.append(VegetarianFilter())
        }
        
        if veganRequired {
            filters.append(VeganFilter())
        }
        
        if let maxDistance = maxDistance {
            filters.append(DistanceFilter(maxDistance: maxDistance, location: referenceLocation))
        }
        
        if let minOptions = minVegetarianOptions {
            filters.append(VegetarianOptionsFilter(minCount: minOptions))
        }
        
        return filters
    }
}

// MARK: - Filter Implementations

private struct CuisineFilter: RestaurantFilter {
    let allowedCuisines: [String]
    private let lowerCuisines: Set<String>
    
    init(allowedCuisines: [String]) {
        self.allowedCuisines = allowedCuisines
        self.lowerCuisines = Set(allowedCuisines.map { $0.lowercased() })
    }
    
    func matches(_ restaurant: Restaurant, location: CLLocation) -> Bool {
        lowerCuisines.contains { restaurant.cuisine.lowercased().contains($0) }
    }
}

private struct VegetarianFilter: RestaurantFilter {
    func matches(_ restaurant: Restaurant, location: CLLocation) -> Bool {
        restaurant.isVegetarianFriendly
    }
}

private struct VeganFilter: RestaurantFilter {
    func matches(_ restaurant: Restaurant, location: CLLocation) -> Bool {
        guard restaurant.isVegetarianFriendly else { return false }
        let lowerName = restaurant.name.lowercased()
        let lowerCuisine = restaurant.cuisine.lowercased()
        return lowerName.contains("vegan") || lowerCuisine.contains("vegan")
    }
}

private struct DistanceFilter: RestaurantFilter {
    let maxDistance: Int
    let location: CLLocation
    
    func matches(_ restaurant: Restaurant, location: CLLocation) -> Bool {
        self.location.distance(from: restaurant.coordinates) <= Double(maxDistance)
    }
}

private struct VegetarianOptionsFilter: RestaurantFilter {
    let minCount: Int
    
    func matches(_ restaurant: Restaurant, location: CLLocation) -> Bool {
        restaurant.vegetarianOptionsCount >= minCount
    }
}
