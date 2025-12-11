//
//  RestaurantGrouper.swift
//  AayushTestAppV1
//

import Foundation
import CoreLocation

/// Groups restaurants by distance ranges for better UI organization.
enum RestaurantGrouper {
    /// Distance range categories
    enum DistanceCategory: String, CaseIterable {
        case close = "<2 mi"
        case moderate = "2-5 mi"
        case far = "5 mi+"
        
        var maxDistanceMiles: Double {
            switch self {
            case .close: return 2.0
            case .moderate: return 5.0
            case .far: return Double.infinity
            }
        }
        
        static func category(for distanceMiles: Double) -> DistanceCategory {
            if distanceMiles < 2.0 { return .close }
            if distanceMiles < 5.0 { return .moderate }
            return .far
        }
    }
    
    /// Grouped restaurant result
    struct GroupedRestaurants {
        let groups: [RestaurantGroup]
        
        struct RestaurantGroup: Identifiable {
            let id: String
            let title: String
            let restaurants: [Restaurant]
        }
    }
    
    /// Groups restaurants by distance.
    static func group(
        _ restaurants: [Restaurant],
        from location: CLLocation
    ) -> GroupedRestaurants {
        let groups = Dictionary(grouping: restaurants) { restaurant in
            let distanceMeters = location.distance(from: restaurant.coordinates)
            let distanceMiles = distanceMeters / 1609.34
            return DistanceCategory.category(for: distanceMiles)
        }
        
        let sortedGroups = DistanceCategory.allCases.compactMap { category -> GroupedRestaurants.RestaurantGroup? in
            guard let restaurants = groups[category], !restaurants.isEmpty else { return nil }
            
            // Sort within group by distance
            let sorted = restaurants.sorted { r1, r2 in
                let dist1 = location.distance(from: r1.coordinates)
                let dist2 = location.distance(from: r2.coordinates)
                return dist1 < dist2
            }
            
            return GroupedRestaurants.RestaurantGroup(
                id: category.rawValue,
                title: category.rawValue,
                restaurants: sorted
            )
        }
        
        return GroupedRestaurants(groups: sortedGroups)
    }
}
