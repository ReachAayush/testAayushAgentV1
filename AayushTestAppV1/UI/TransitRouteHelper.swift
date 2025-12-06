import Foundation
import CoreLocation

/// TransitRouteHelper — Deprecated (Apple Maps flow removed)
///
/// This helper previously launched Apple Maps in Transit mode.
/// The app now uses the Google Maps flow in `PATHTrainView`.
///
/// Calls to this helper are no-ops and should be removed. Use the Google Maps
/// URL scheme instead (see `PATHTrainView.openDirections`).
@available(*, deprecated, message: "Use Google Maps URL scheme from PATHTrainView instead of TransitRouteHelper.")
struct TransitRouteHelper {
    /// No-op placeholder retained for source compatibility.
    static func openTransitDirections(to name: String, coordinate: CLLocationCoordinate2D) {
        // Intentionally left blank. Previously opened Apple Maps with transit directions.
        // Migrate to Google Maps: see PATHTrainView.openDirections(fromCoordinate:toAddress:).
        #if DEBUG
        print("[TransitRouteHelper] Deprecated call ignored. Destination: \(name) @ \(coordinate.latitude),\(coordinate.longitude)")
        #endif
    }
}
