import Foundation
import Combine

final class ToneProfileStore: ObservableObject {
    @Published var samples: [String] = []
    @Published var toneSummary: String = "" // compact style descriptor

    private let samplesKey = "ToneSamplesJSON"
    private let summaryKey = "ToneSummaryString"

    init() {
        load()
    }

    func setSamples(_ new: [String]) {
        samples = new
        save()
    }

    func setToneSummary(_ summary: String) {
        toneSummary = summary
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: samplesKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            samples = decoded
        }
        if let summary = UserDefaults.standard.string(forKey: summaryKey) {
            toneSummary = summary
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(samples) {
            UserDefaults.standard.set(data, forKey: samplesKey)
        }
        UserDefaults.standard.set(toneSummary, forKey: summaryKey)
    }
}
