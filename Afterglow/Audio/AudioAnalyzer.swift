import AVFoundation
import Foundation

struct AudioFrame: Sendable {
    var bands = [Float](repeating: 0, count: 64)
    var waveform = [Float](repeating: 0, count: 256)
    var rms: Float = 0
    var peak: Float = 0
    var bass: Float = 0
    var mid: Float = 0
    var treble: Float = 0
    static let silent = AudioFrame()

    static func ambient(at time: Double) -> AudioFrame {
        var frame = AudioFrame()
        for i in frame.bands.indices {
            let x = Double(i) / 64
            frame.bands[i] = Float(0.16 + 0.42 * pow((sin(x * 9 + time * 0.9) + 1) / 2, 2)
                                  + 0.12 * sin(x * 23 - time * 1.3))
        }
        for i in frame.waveform.indices {
            let x = Double(i) / 256
            frame.waveform[i] = Float(sin(x * .pi * 6 + time) * 0.32 + sin(x * .pi * 14 - time * 0.7) * 0.12)
        }
        frame.rms = 0.12; frame.bass = 0.36; frame.mid = 0.28; frame.treble = 0.22
        return frame
    }
}

/// All C state is protected by its internal mutex. This object may cross the audio callback boundary.
final class AudioAnalyzer: @unchecked Sendable {
    private let handle: OpaquePointer
    init() {
        guard let handle = AGAnalyzerCreate() else { fatalError("Cannot allocate audio analyzer") }
        self.handle = handle
    }
    deinit { AGAnalyzerDestroy(handle) }
    func reset() { AGAnalyzerReset(handle) }
    func consume(_ buffer: AVAudioPCMBuffer) {
        guard buffer.format.commonFormat == .pcmFormatFloat32,
              let channels = buffer.floatChannelData else { return }
        if buffer.format.isInterleaved {
            AGAnalyzerPushInterleaved(handle, channels[0], Int(buffer.frameLength),
                                     buffer.format.channelCount, buffer.format.sampleRate)
        } else {
            AGAnalyzerPushPlanar(handle, channels[0], buffer.format.channelCount > 1 ? channels[1] : nil,
                                Int(buffer.frameLength), buffer.format.sampleRate)
        }
    }
    func snapshot() -> AudioFrame {
        var frame = AudioFrame()
        var levels = [Float](repeating: 0, count: 5)
        AGAnalyzerCopyFrame(handle, &frame.bands, &frame.waveform, &levels)
        frame.rms = levels[0]; frame.peak = levels[1]
        frame.bass = levels[2]; frame.mid = levels[3]; frame.treble = levels[4]
        return frame
    }
}
