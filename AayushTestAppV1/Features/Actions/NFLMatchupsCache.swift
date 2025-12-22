import Foundation

actor NFLMatchupsCache {
    nonisolated static let shared = NFLMatchupsCache()
    
    struct Entry {
        let value: String
        let storedAt: Date
    }
    
    private var storage: [String: Entry] = [:]
    
    // Time-based eviction TTL (in seconds). Adjust as needed.
    private let ttl: TimeInterval = 3 * 60 * 60 // 3 hours
    
    func get(forKey key: String) -> String? {
        let now = Date()
        if let entry = storage[key] {
            if isExpired(entry: entry, now: now) {
                storage.removeValue(forKey: key)
                return nil
            } else {
                return entry.value
            }
        } else {
            return nil
        }
    }
    
    func set(_ value: String, forKey key: String) {
        storage[key] = Entry(value: value, storedAt: Date())
    }
    
    // MARK: - Expiration Logic
    private func isExpired(entry: Entry, now: Date) -> Bool {
        // TTL expiration
        if now.timeIntervalSince(entry.storedAt) > ttl { return true }
        
        // Weekly reset at Monday 00:00 PT
        let tz = TimeZone(identifier: "America/Los_Angeles") ?? .current
        let currentMondayStart = mondayStart(for: now, in: tz)
        if entry.storedAt < currentMondayStart { return true }
        
        return false
    }
    
    private func mondayStart(for date: Date, in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let startOfDay = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: startOfDay) // 1=Sun, 2=Mon, ... 7=Sat
        let daysSinceMonday = (weekday + 5) % 7 // Mon->0, Tue->1, ..., Sun->6
        let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay)!
        return monday
    }
}
