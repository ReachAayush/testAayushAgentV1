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
        // TODO: OPERATIONAL METRICS - Track location permission requests
        // Metrics to emit:
        // - location.permission.request (counter) - permission request attempts
        // - location.permission.status (gauge) - current permission status
        // For now: logger.debug("Location permission request initiated: currentStatus=\(authorizationStatus)", category: .location)
        let logger = LoggingService.shared
        logger.debug("Location permission request initiated: currentStatus=\(authorizationStatus.rawValue)", category: .location)
        
        guard authorizationStatus == .notDetermined else {
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                // TODO: OPERATIONAL METRICS - Track location permission denials
                // Metrics to emit:
                // - location.permission.denied (counter) - permission denials
                // For now: logger.debug("Location permission denied: status=\(authorizationStatus)", category: .location)
                logger.debug("Location permission denied: status=\(authorizationStatus.rawValue)", category: .location)
                throw NSError(
                    domain: "LocationClient",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Location access denied. Please enable location services in Settings."]
                )
            }
            // TODO: OPERATIONAL METRICS - Track location permission already granted
            // Metrics to emit:
            // - location.permission.granted (counter) - permission already available
            // For now: logger.debug("Location permission already granted", category: .location)
            logger.debug("Location permission already granted", category: .location)
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
        
        // TODO: OPERATIONAL METRICS - Track location fetch initiation
        // Metrics to emit:
        // - location.fetch.initiated (counter) - location fetch attempts
        // For now: logger.debug("Location fetch initiated", category: .location)
        let logger = LoggingService.shared
        let fetchStartTime = Date()
        logger.debug("Location fetch initiated", category: .location)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            // Store continuation to resume when location is received
            locationUpdateContinuation = continuation
            locationManager.requestLocation()
            
            // Use a timeout to avoid waiting indefinitely
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if let continuation = locationUpdateContinuation {
                    locationUpdateContinuation = nil
                    // TODO: OPERATIONAL METRICS - Track location fetch timeouts
                    // Metrics to emit:
                    // - location.fetch.timeout (counter) - location fetch timeouts
                    // - location.fetch.failure (counter) - failed location fetches
                    // For now: logger.debug("Location fetch timeout after 10s", category: .location)
                    logger.debug("Location fetch timeout after 10s", category: .location)
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
        let logger = LoggingService.shared
        
        if let location = locations.first {
            // TODO: OPERATIONAL METRICS - Track successful location fetch
            // Metrics to emit:
            // - location.fetch.success (counter) - successful location fetches
            // - location.fetch.duration (histogram) - location fetch latency in milliseconds
            // - location.fetch.accuracy (histogram) - location accuracy in meters
            // For now: logger.debug("Location fetch succeeded: accuracy=\(location.horizontalAccuracy)m", category: .location)
            logger.debug("Location fetch succeeded: accuracy=\(String(format: "%.1f", location.horizontalAccuracy))m", category: .location)
            currentLocation = location
            locationUpdateContinuation?.resume(returning: location)
            locationUpdateContinuation = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // TODO: OPERATIONAL METRICS - Track location fetch errors
        // Metrics to emit:
        // - location.fetch.failure (counter) - failed location fetches
        // - location.fetch.error.type (counter) - error type
        // For now: logger.debug("Location fetch failed: errorType=\(type(of: error))", category: .location)
        let logger = LoggingService.shared
        logger.debug("Location fetch failed: errorType=\(type(of: error))", category: .location)
        locationUpdateContinuation?.resume(throwing: error)
        locationUpdateContinuation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // TODO: OPERATIONAL METRICS - Track location permission status changes
        // Metrics to emit:
        // - location.permission.status (gauge) - current permission status
        // - location.permission.status_change (counter) - permission status changes
        // For now: logger.debug("Location permission status changed: newStatus=\(manager.authorizationStatus.rawValue)", category: .location)
        let logger = LoggingService.shared
        logger.debug("Location permission status changed: newStatus=\(manager.authorizationStatus.rawValue)", category: .location)
        authorizationStatus = manager.authorizationStatus
    }
}
