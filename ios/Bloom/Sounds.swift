// Sounds.swift — port of audio.js: kalimba UI toks, four selectable ringers, all
// synthesized. (Synth engine lands with the extras pass; the API is stable now.)
import Foundation

struct RingerInfo {
    var key: String
    var label: String
}

let RINGERS: [RingerInfo] = [
    RingerInfo(key: "chime", label: "Chime"),
    RingerInfo(key: "bell", label: "Bell"),
    RingerInfo(key: "birdsong", label: "Birdsong"),
    RingerInfo(key: "marimba", label: "Marimba"),
    RingerInfo(key: "silent", label: "Silent"),
]

final class Sfx {
    static let shared = Sfx()
    /// The store injects itself so sounds can honor settings.sound / settings.taps.
    weak var store: AppStore?

    private var soundOn: Bool { store?.state.settings.sound ?? true }
    private var tapsOn: Bool { soundOn && (store?.state.settings.taps ?? true) }

    func click() { guard tapsOn else { return } ; Synth.play(.click) }
    func pop() { guard tapsOn else { return } ; Synth.play(.pop) }
    func start() { guard soundOn else { return } ; Synth.play(.start) }
    func chime() { guard soundOn else { return } ; Synth.play(.chime) }
    func level() { guard soundOn else { return } ; Synth.play(.level) }
    func uhoh() { guard soundOn else { return } ; Synth.play(.uhoh) }
    func alarm() {
        guard soundOn else { return }
        Synth.playRinger(store?.state.settings.ringer ?? "chime", repeats: 3)
    }
    func ringerPreview(_ key: String) { guard soundOn else { return } ; Synth.playRinger(key, repeats: 1) }
}
