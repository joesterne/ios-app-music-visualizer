import Foundation

struct SavedPreferences: Codable {
    var version = 1
    var settings: VisualSettings
    var volume: Double
    var motionPaused: Bool

    func validated() -> Self {
        var copy = self
        copy.settings = settings.validated()
        copy.volume = volume.isFinite ? min(1, max(0, volume)) : 0.8
        return copy
    }
}

enum PreferenceStore {
    private static let key = "afterglow.localPreferences.v1"
    static func load(defaults: UserDefaults = .standard) -> SavedPreferences? {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(SavedPreferences.self, from: data),
              value.version == 1 else { return nil }
        return value.validated()
    }
    static func save(_ value: SavedPreferences, defaults: UserDefaults = .standard) throws {
        let data = try JSONEncoder().encode(value.validated())
        defaults.set(data, forKey: key)
    }
    static func forget(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: "visualSettings.v1")
    }
}
