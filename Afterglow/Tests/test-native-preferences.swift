import Foundation

// Invoked by build-apple.sh on a Mac. Uses a private defaults suite, never app data.
@main
enum NativePreferenceRegression {
    static func main() throws {
        let name = "com.afterglow.regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var settings = VisualSettings()
        settings.audioReactive = false
        settings.style = .yosemite; settings.palette = .glacier
        settings.tronMode = .identityDiscs; settings.tronPalette = .orange
        settings.speed = 0.85; settings.fps = 30; settings.favorites = [.orbit, .orbit, .yosemite]
        try PreferenceStore.save(SavedPreferences(settings: settings, volume: 0.42, motionPaused: true), defaults: defaults)
        let saved = try require(PreferenceStore.load(defaults: defaults))
        assert(saved.settings.style == .yosemite && saved.settings.palette == .glacier)
        assert(saved.settings.speed == 0.85 && saved.settings.fps == 30)
        assert(saved.settings.tronMode == .identityDiscs && saved.settings.tronPalette == .orange)
        assert(!saved.settings.audioReactive)
        assert(saved.volume == 0.42 && saved.motionPaused)
        assert(saved.settings.favorites == [.orbit, .yosemite])
        settings.speed = .nan; settings.sensitivity = 999; settings.glow = -1
        try PreferenceStore.save(SavedPreferences(settings: settings, volume: .infinity, motionPaused: false), defaults: defaults)
        let sanitized = try require(PreferenceStore.load(defaults: defaults))
        assert(sanitized.settings.speed == 0.65 && sanitized.settings.sensitivity == 3)
        assert(sanitized.settings.glow == 0 && sanitized.volume == 0.8)
        defaults.set(Data("broken JSON".utf8), forKey: "afterglow.localPreferences.v1")
        assert(PreferenceStore.load(defaults: defaults) == nil)
        defaults.set("keep", forKey: "unrelated")
        PreferenceStore.forget(defaults: defaults)
        assert(PreferenceStore.load(defaults: defaults) == nil && defaults.string(forKey: "unrelated") == "keep")

        let start = Date(), clock = VisualizerClock()
        clock.setPaused(true, at: start); clock.setSpeed(0.5, at: start); clock.setPaused(false, at: start)
        let at: (Double) -> Date = { start.addingTimeInterval($0) }
        assert(abs(clock.elapsed(at: at(10)) - 5) < 1e-8)
        clock.setSpeed(2, at: at(10))
        assert(abs(clock.elapsed(at: at(15)) - 15) < 1e-8)
        clock.setPaused(true, at: at(15)); clock.setSpeed(1, at: at(18))
        assert(abs(clock.elapsed(at: at(20)) - 15) < 1e-8)
        clock.setPaused(false, at: at(20)); clock.setPaused(false, at: at(22))
        assert(abs(clock.elapsed(at: at(24)) - 19) < 1e-8)
        print("PASS: local preferences, safe validation, corruption, scoped forget, continuous speed, and pause/resume.")
    }
    private static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw NSError(domain: "AfterglowRegression", code: 1) }
        return value
    }
}
