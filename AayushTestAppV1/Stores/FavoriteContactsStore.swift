import Foundation
import Combine

struct FavoriteContact: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var phone: String
    var styleHint: String? // Optional per-contact personalization

    init(id: UUID = UUID(), name: String, phone: String, styleHint: String? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.styleHint = styleHint
    }
}

final class FavoriteContactsStore: ObservableObject {
    @Published var contacts: [FavoriteContact] = []

    init() {
        // Always use hardcoded contacts - no persistence, no customization
        contacts = [
            FavoriteContact(
                name: "My Dad",
                phone: "7329999999",
                styleHint: "This message is for my dad, who is my greatest role model. He has taught me the true meaning of unconditional love and sacrifice. I look up to his strength, his kindness, and the way he shows up every single day. I owe so much of who I am to his constant presence and unwavering support."
            )]
    }
}
