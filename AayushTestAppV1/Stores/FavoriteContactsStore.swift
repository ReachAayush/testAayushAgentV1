//
//  FavoriteContactsStore.swift
//  AayushTestAppV1
//
//

import Foundation
import Combine

/// Model representing a favorite contact with personalization settings.
///
/// **Purpose**: Stores contact information along with style hints and timezone
/// preferences for personalized message generation.
struct FavoriteContact: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var phone: String
    var styleHint: String? // Optional per-contact personalization
    var timezoneIdentifier: String? // Optional timezone for time-of-day greetings (e.g., "America/New_York")

    init(id: UUID = UUID(), name: String, phone: String, styleHint: String? = nil, timezoneIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.styleHint = styleHint
        self.timezoneIdentifier = timezoneIdentifier
    }
}

/// Store for managing favorite contacts.
///
/// **Purpose**: Provides a centralized store for favorite contacts with their
/// personalization settings. Currently uses hardcoded contacts, but designed
/// to support persistence in the future.
///
/// **Architecture**: Observable object that publishes changes to contacts list.
/// Used by views and actions that need access to favorite contacts.
final class FavoriteContactsStore: ObservableObject {
    @Published var contacts: [FavoriteContact] = []

    init() {
        // Always use hardcoded contacts - no persistence, no customization
        // TODO: Add persistence to UserDefaults or Core Data in future
        contacts = [
            FavoriteContact(
                name: "Savannah Milford",
                phone: "5094990003",
                styleHint: "Warm, deeply affectionate, and highly personal. Acknowledge the immense strength and courage she shows every day in her fight for social justice and equality, especially her primary work advocating for Black, low-income, and marginalized families. Express how deeply proud I am of her powerful voice and unwavering conviction. Frame the message as supportive of her exhausting advocacy work, emphasizing that our relationship is a partnership built on mutual respect and admiration for her character.",
                timezoneIdentifier: "America/PacificStandardTime"
            ),
            FavoriteContact(
                name: "Ashima Agarwal",
                phone: "7328299902",
                styleHint: "Warm, proud, and in a down-to-earth, sibling tone. Acknowledge her extreme dedication and the long, exhausting shifts she works as a doctor. Express immense pride in her commitment to healing and the personal sacrifices she makes for her patients. The message should be highly encouraging, reminding her to prioritize her own well-being and thanking her for being such a supportive older/younger sister.",
                timezoneIdentifier: "America/New_York"
            ),
            FavoriteContact(
                name: "Alika Agarwal",
                phone: "7328222597",
                styleHint: "Gentle, caring, and reassuring, using a compassionate, mother-child tone. Acknowledge the incredible emotional strength and comforting presence she provides, especially while managing ongoing family health challenges. Express gratitude for the sacrifices she makes as the family's emotional anchor. The message should offer steady, unwavering support and reassurance that she doesn't have to carry the burdens alone.",
                timezoneIdentifier: "America/New_York"
            ),
            FavoriteContact(
                name: "Maneesh Agarwal",
                phone: "7324294408",
                styleHint: "This message is for my dad, who is my greatest role model. He has taught me the true meaning of unconditional love and sacrifice. I look up to his strength, his kindness, and the way he shows up every single day. I owe so much of who I am to his constant presence and unwavering support.",
                timezoneIdentifier: "America/New_York"
            ),
            FavoriteContact(
                name: "Dylan Nelson",
                phone: "9174083594",
                styleHint: "Upbeat, humorous, and highly fraternal (best friend tone). Reference his reputation as a 'Casanova' in NYC with huge success on Hinge. Acknowledge his reliability and willingness to hang out whenever I'm bored. Include a friendly nod to his consistent gym invitations. Crucially, the text should incorporate or play on his favorite word, **'cozy.'**",
                timezoneIdentifier: "America/New_York"
            )
        ]
    }
}
