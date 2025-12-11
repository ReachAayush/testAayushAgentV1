//
//  UserProfileStore.swift
//  AayushTestAppV1
//
//

import Foundation
import Combine

/// Model representing user profile information for reservations and other services.
///
/// **Purpose**: Stores user contact information that can be pre-filled in forms
/// throughout the app (e.g., restaurant reservations).
struct UserProfile: Codable, Equatable {
    var name: String
    var email: String
    var phone: String
    
    init(name: String = "", email: String = "", phone: String = "") {
        self.name = name
        self.email = email
        self.phone = phone
    }
}

/// Store for managing user profile information.
///
/// **Purpose**: Provides a centralized store for user contact information with persistence.
/// Uses UserDefaults for simple key-value storage.
///
/// **Architecture**: Observable object that publishes changes to profile. Automatically
/// saves to UserDefaults when profile is updated.
final class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet {
            saveProfile()
        }
    }
    
    private let profileKey = "UserProfile"
    
    init() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = UserProfile()
        }
    }
    
    /// Updates the user profile.
    func update(name: String? = nil, email: String? = nil, phone: String? = nil) {
        if let name = name { profile.name = name }
        if let email = email { profile.email = email }
        if let phone = phone { profile.phone = phone }
    }
    
    /// Checks if profile is complete (all fields filled).
    var isComplete: Bool {
        !profile.name.isEmpty && !profile.email.isEmpty && !profile.phone.isEmpty
    }
    
    /// Saves profile to UserDefaults.
    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }
}
