import Foundation
import Combine

/// Model representing a saved transit destination.
///
/// Stored by `TransitStopsStore` and used by the Google Maps transit flow.
/// Only contains a display name and optional description; coordinates are
/// resolved on-demand by Google Maps when opening directions.
struct TransitStop: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    
    init(id: UUID = UUID(), name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

/// Persistent store for user-managed transit stops.
///
/// - Persists to UserDefaults as JSON for simplicity.
/// - Publishes changes via `@Published` for SwiftUI bindings.
/// - Used by PATHTrainView and the Stops Management UI.
///
/// Note: This store is intentionally lightweight; it avoids eager geocoding and
/// defers coordinate resolution to Google Maps.
final class TransitStopsStore: ObservableObject {
    @Published var stops: [TransitStop] = []
    
    private let stopsKey = "TransitStopsJSON"
    
    init() {
        load()
        // Add default stops if empty
        if stops.isEmpty {
            addDefaultStops()
        }
    }
    
    private func addDefaultStops() {
        stops = [
            TransitStop(
                name: "Hoboken PATH Station",
                description: "Home station"
            ),
            TransitStop(
                name: "Christopher St PATH Station",
                description: "NYC station"
            )
        ]
        save()
    }
    
    /// Adds a new stop and persists the change.
    func addStop(_ stop: TransitStop) {
        stops.append(stop)
        save()
    }
    
    /// Updates an existing stop by id and persists the change.
    func updateStop(_ stop: TransitStop) {
        if let index = stops.firstIndex(where: { $0.id == stop.id }) {
            stops[index] = stop
            save()
        }
    }
    
    /// Deletes a stop by id and persists the change.
    func deleteStop(_ stop: TransitStop) {
        stops.removeAll { $0.id == stop.id }
        save()
    }
    
    /// Loads the stop list from UserDefaults.
    private func load() {
        if let data = UserDefaults.standard.data(forKey: stopsKey),
           let decoded = try? JSONDecoder().decode([TransitStop].self, from: data) {
            stops = decoded
        }
    }
    
    /// Saves the stop list to UserDefaults.
    private func save() {
        if let data = try? JSONEncoder().encode(stops) {
            UserDefaults.standard.set(data, forKey: stopsKey)
        }
    }
}

#if DEBUG
import SwiftUI

#Preview("TransitStopsStore Preview") {
    let store = TransitStopsStore()
    return NavigationStack {
        TransitStopsManagementView(store: store)
    }
}
#endif
