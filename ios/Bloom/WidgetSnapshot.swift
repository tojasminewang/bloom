// WidgetSnapshot.swift — a light summary of the garden, written to the shared App Group
// container on every save so the home-screen widget can draw without the full state.
import Foundation
import WidgetKit

struct GardenSnapshot: Codable {
    var streak: Int
    var minutesToday: Int
    var minutesWeek: Int
    var tierName: String
    var topSkillName: String?
    var topSkillColor: String?
    var topSkillSpecies: String?
    var topSkillLevel: Int?
    var updatedAt: Date

    static let appGroup = "group.com.jasmine.bloom"
    static let fileName = "garden-snapshot.json"

    static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    static func read() -> GardenSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GardenSnapshot.self, from: data)
    }
}

enum WidgetSnapshotWriter {
    static func write(store: AppStore) {
        guard let url = GardenSnapshot.url else { return }
        let top = store.state.skills
            .sorted {
                let (a, b) = (store.weekMinutes($0.id), store.weekMinutes($1.id))
                return a != b ? a > b : store.xpOf($0.id) > store.xpOf($1.id)
            }
            .first
        let snap = GardenSnapshot(
            streak: store.streak(),
            minutesToday: store.minutesOn(todayYmd()),
            minutesWeek: store.weekMinutes(),
            tierName: store.tier().cur.name,
            topSkillName: top?.name,
            topSkillColor: top?.color,
            topSkillSpecies: top?.species,
            topSkillLevel: top.map { store.levelOf($0.id).level },
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadTimelines(ofKind: "BloomGarden")
        }
    }
}
