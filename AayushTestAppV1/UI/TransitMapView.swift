import SwiftUI

/// TransitMapView (Apple Maps) — Deprecated
///
/// This Apple Maps-based transit explorer has been removed in favor of the
/// newer Google Maps–driven flow (`PATHTrainView`). Keeping a lightweight
/// deprecated stub here avoids breaking builds that still reference
/// `TransitMapView` while making it clear that the feature is no longer supported.
///
/// Action removal:
/// - The Home screen no longer presents this view.
/// - Prefer opening transit directions using the Google Maps URL scheme from `PATHTrainView`.
///
/// To migrate existing code, launch `PATHTrainView()` instead.
///
/// Note: This type is kept only as a non-functional placeholder and may be removed in a future release.
@available(*, deprecated, message: "TransitMapView (Apple Maps) has been removed. Use PATHTrainView (Google Maps flow) instead.")
struct TransitMapView: View {
    // Preserved for source-compatibility, not used.
    @ObservedObject var store: TransitStopsStore

    var body: some View {
        RemovedTransitMapsPlaceholder()
    }
}

/// Simple placeholder view shown if any legacy code still presents TransitMapView.
private struct RemovedTransitMapsPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(SteelersTheme.steelersGold)
            Text("Transit (Apple Maps) Removed")
                .font(.headline)
                .foregroundColor(SteelersTheme.textPrimary)
            Text("This feature has been replaced by the Google Maps version. Please use the Transit Directions action.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(SteelersTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
