import Foundation

enum PendingResponseStore {
    private static let key = "LockedPendingMoodResponse"

    static func save(_ response: PendingMoodResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> PendingMoodResponse? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PendingMoodResponse.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
