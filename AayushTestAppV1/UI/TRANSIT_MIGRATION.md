//
//  TransitRouteHelper.swift
//  Pathways
//
//  Created by Developer on 2020-01-01.
//

import Foundation
import CoreLocation

/// A deprecated helper for opening transit directions using Apple Maps.
/// This class is now a no-op and will be removed in a future release.
/// Use `PATHTrainView.openDirections(fromCoordinate:toAddress:)` instead.
@available(*, deprecated, message: "Use PATHTrainView with Google Maps instead. This helper is now a no-op.")
final class TransitRouteHelper {
    
    /// Attempts to open transit directions to a given address or coordinate.
    /// - Parameters:
    ///   - address: The destination address as a string.
    ///   - coordinate: The destination coordinate.
    /// - Note: This method no longer attempts to open Apple Maps and is a no-op.
    static func openTransitDirections(to address: String?, coordinate: CLLocationCoordinate2D?) {
        // This method is deprecated and intentionally left blank.
        // Use PATHTrainView.openDirections(fromCoordinate:toAddress:) for Google Maps directions.
    }
    
    private init() { }
}

---

## Removing Deprecated Files via git (optional)

```bash
git rm TransitMapView.swift TransitRouteHelper.swift LocationManager.swift
