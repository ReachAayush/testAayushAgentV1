//
//  LocationClient.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import Foundation
import Combine
import CoreLocation

/// Service for accessing user location.
///
/// **Purpose**: Provides location services for features that need to know where the user is.
/// Handles permissions and location updates.
///
/// **Architecture**: Follows the service layer pattern - pure data access with no business logic.
final class LocationClient: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// Requests location access if needed.
    /// - Throws: Error if access is denied
    func requestAccessIfNeeded() async throws {
        guard authorizationStatus == .notDetermined else {
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                throw NSError(
                    domain: "LocationClient",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Location access denied. Please enable location services in Settings."]
                )
            }
            return
        }
        
        locationManager.requestWhenInUseAuthorization()
        
        // Wait for authorization status to update
        var attempts = 0
        while authorizationStatus == .notDetermined && attempts < 10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }
        
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            throw NSError(
                domain: "LocationClient",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access denied. Please enable location services in Settings."]
            )
        }
    }
    
    /// Requests one-shot current location (with a 10s timeout) and returns it asynchronously.
    /// Gets the user's current location.
    /// - Returns: Current location
    /// - Throws: Error if location access is not available
    func getCurrentLocation() async throws -> CLLocation {
        try await requestAccessIfNeeded()
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            // Store continuation to resume when location is received
            locationUpdateContinuation = continuation
            locationManager.requestLocation()
            
            // Use a timeout to avoid waiting indefinitely
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if let continuation = locationUpdateContinuation {
                    locationUpdateContinuation = nil
                    continuation.resume(throwing: NSError(
                        domain: "LocationClient",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to get location. Please try again."]
                    ))
                }
            }
        }
    }
    
    private var locationUpdateContinuation: CheckedContinuation<CLLocation, Error>?
}

extension LocationClient: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            currentLocation = location
            locationUpdateContinuation?.resume(returning: location)
            locationUpdateContinuation = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationUpdateContinuation?.resume(throwing: error)
        locationUpdateContinuation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
