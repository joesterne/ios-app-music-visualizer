import Foundation

@main
struct AudioResponseTests {
    static func main() {
        let silence = AudioResponse(rms: 0, bass: 0, mid: 0, treble: 0, beat: 0, sensitivity: 3)
        assert([silence.energy, silence.bass, silence.mid, silence.treble, silence.hit].allSatisfy { $0 == 0 })
        for gain in [0.2, 1.25, 3.0] {
            var last = -1.0
            for step in 0...100 {
                let value = Double(step) / 100
                let response = AudioResponse(rms: value, bass: value, mid: value, treble: value, beat: value, sensitivity: gain)
                assert([response.energy, response.bass, response.mid, response.treble, response.hit].allSatisfy { $0.isFinite && $0 >= 0 && $0 < 1 })
                assert(response.bass > last)
                last = response.bass
            }
        }
        let bass = AudioResponse(rms: 0.1, bass: 0.7, mid: 0.1, treble: 0.01, beat: 0, sensitivity: 1.25)
        assert(bass.bass > bass.mid && bass.mid > bass.treble)
        assert(bass.energy > 0.3 && bass.hit == 0)
        assert(AudioResponse.band(0.9, gain: 3) > AudioResponse.band(0.8, gain: 3))
        assert(AudioResponse.compress(.nan, gain: 1) == 0)
        assert(AudioResponse.compress(.infinity, gain: 1) == 0)
        assert(AudioResponse.compress(1, gain: .nan) == 0)
        print("PASS: native audio response silence, quiet music, band separation, bounded gain and loud-track headroom.")
    }
}
