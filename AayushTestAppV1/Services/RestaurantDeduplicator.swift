//
//  RestaurantDeduplicator.swift
//  AayushTestAppV1
//
//

import Foundation
import CoreLocation

/// Utility for deduplicating restaurants by normalizing names and keeping the best option.
enum RestaurantDeduplicator {
    /// Normalizes a restaurant name by removing location-specific suffixes.
    static func normalizeName(_ name: String) -> String {
        var normalized = name.trimmingCharacters(in: .whitespaces)
        
        // Remove location suffixes
        for suffix in RestaurantSearchConstants.locationSuffixes {
            if normalized.lowercased().hasSuffix(suffix) {
                normalized = String(normalized.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        // Remove trailing location indicators in parentheses
        if let openParen = normalized.lastIndex(of: "("),
           let closeParen = normalized[openParen...].firstIndex(of: ")"),
           closeParen > openParen {
            let afterClose = normalized.index(after: closeParen)
            let remaining = afterClose < normalized.endIndex ? String(normalized[afterClose...]) : ""
            if remaining.trimmingCharacters(in: .whitespaces).isEmpty {
                normalized = String(normalized[..<openParen]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return normalized.lowercased()
    }
    
    /// Deduplicates restaurants by keeping the best option for each chain.
    /// - Parameters:
    ///   - restaurants: Array of restaurants to deduplicate
    ///   - location: Reference location for distance calculation
    /// - Returns: Deduplicated array with best restaurant from each chain
    static func deduplicate(_ restaurants: [Restaurant], from location: CLLocation) -> [Restaurant] {
        // Group by normalized name
        let groups = Dictionary(grouping: restaurants) { normalizeName($0.name) }
        
        // Keep best from each group
        return groups.values.compactMap { group in
            group.min { r1, r2 in
                // Prefer closer restaurant
                let dist1 = location.distance(from: r1.coordinates)
                let dist2 = location.distance(from: r2.coordinates)
                return dist1 > dist2
            }
        }
    }
}
