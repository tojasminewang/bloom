// Synth.swift — placeholder tone engine; the faithful WebAudio port arrives with the
// extras pass. Keeping the surface tiny: patterns by name, ringers by key.
import Foundation

enum SfxPattern {
    case click, pop, start, chime, level, uhoh
}

enum Synth {
    static func play(_ pattern: SfxPattern) {
        // real synthesis lands in the extras pass
    }
    static func playRinger(_ key: String, repeats: Int) {
        // real synthesis lands in the extras pass
    }
}
