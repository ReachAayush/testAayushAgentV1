//
//  ReservationService.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import Foundation

/// Service for making restaurant reservations via OpenTable or Rezzy.
///
/// **Purpose**: Handles the actual reservation booking process through different
/// reservation providers (OpenTable, Rezzy, etc.).
///
/// **Architecture**: Service layer pattern - pure data access with no business logic.
/// This is a mock implementation. In production, you would integrate with actual
/// OpenTable API (https://opentable.herokuapp.com/) or Rezzy API.
final class ReservationService {
    private let logger = LoggingService.shared
    
    /// Makes a reservation at a restaurant.
    ///
    /// - Parameters:
    ///   - restaurant: The restaurant to book
    ///   - date: Reservation date and time
    ///   - partySize: Number of guests
    ///   - dinerName: Name for the reservation
    ///   - dinerEmail: Email for confirmation
    ///   - dinerPhone: Phone number for confirmation
    /// - Returns: Reservation confirmation details
    /// - Throws: Errors from network, API, or validation
    func makeReservation(
        at restaurant: Restaurant,
        date: Date,
        partySize: Int,
        dinerName: String,
        dinerEmail: String,
        dinerPhone: String
    ) async throws -> Reservation {
        logger.debug("Making reservation at \(restaurant.name) for \(partySize) guests on \(date)", category: .reservation)
        
        // TODO: OPERATIONAL METRICS - Track reservation attempts
        // Metrics to emit:
        // - reservation.attempt.initiated (counter) - reservation attempts
        // - reservation.attempt.provider (counter) - provider type (OpenTable, Rezzy)
        // - reservation.attempt.party_size (histogram) - party sizes
        
        // Validate inputs
        guard partySize > 0 && partySize <= 20 else {
            throw AppError.invalidInput(field: "partySize", reason: "Party size must be between 1 and 20")
        }
        
        guard date > Date() else {
            throw AppError.invalidInput(field: "date", reason: "Reservation date must be in the future")
        }
        
        // Mock reservation - In production, replace with actual API call
        // OpenTable API example: POST https://opentable.herokuapp.com/api/restaurants/{restaurantId}/reservations
        // Rezzy API would have similar structure
        
        let confirmationNumber = "\(restaurant.id.prefix(4).uppercased())-\(Int.random(in: 1000...9999))"
        
        let reservation = Reservation(
            id: UUID().uuidString,
            restaurant: restaurant,
            date: date,
            partySize: partySize,
            dinerName: dinerName,
            dinerEmail: dinerEmail,
            dinerPhone: dinerPhone,
            confirmationNumber: confirmationNumber,
            status: .confirmed,
            provider: restaurant.reservationProvider
        )
        
        logger.debug("Reservation created successfully: confirmationNumber=\(confirmationNumber)", category: .reservation)
        
        // TODO: OPERATIONAL METRICS - Track successful reservations
        // Metrics to emit:
        // - reservation.success (counter) - successful reservations
        // - reservation.provider.success (counter) - success by provider
        
        return reservation
    }
    
    /// Checks available reservation times for a restaurant.
    ///
    /// - Parameters:
    ///   - restaurant: The restaurant to check
    ///   - date: Date to check availability
    ///   - partySize: Number of guests
    /// - Returns: Array of available time slots
    /// - Throws: Errors from network or API
    func checkAvailability(
        at restaurant: Restaurant,
        date: Date,
        partySize: Int
    ) async throws -> [Date] {
        logger.debug("Checking availability at \(restaurant.name) for \(partySize) guests on \(date)", category: .reservation)
        
        // Mock available times (every 30 minutes from 6 PM to 10 PM)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 18
        components.minute = 0
        
        guard let startDate = calendar.date(from: components) else {
            return []
        }
        
        var availableTimes: [Date] = []
        var currentTime = startDate
        
        while availableTimes.count < 9 { // 6:00 PM to 10:00 PM in 30-min increments
            if currentTime > date {
                availableTimes.append(currentTime)
            }
            currentTime = calendar.date(byAdding: .minute, value: 30, to: currentTime) ?? currentTime
        }
        
        return availableTimes
    }
}

/// Represents a restaurant reservation.
struct Reservation: Codable, Identifiable {
    let id: String
    let restaurant: Restaurant
    let date: Date
    let partySize: Int
    let dinerName: String
    let dinerEmail: String
    let dinerPhone: String
    let confirmationNumber: String
    let status: ReservationStatus
    let provider: String
    
    enum ReservationStatus: String, Codable {
        case pending = "pending"
        case confirmed = "confirmed"
        case cancelled = "cancelled"
    }
}

// MARK: - Logging Category Extension
extension LogCategory {
    static let reservation = LogCategory(rawValue: "Reservation") ?? .general
}
