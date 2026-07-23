// Levels.swift — XP → levels, garden tiers, stages, keepsakes. Ported from util.js/progress.js.
import Foundation

struct LevelInfo: Equatable {
    var level: Int
    var into: Int      // XP into the current level
    var need: Int      // XP this level costs
}

/// util.js levelForXp: 1.5h to level 2, then +1.5h per level (3h, 4.5h, …) capped at 20h a level.
func levelForXp(_ xp: Int) -> LevelInfo {
    var level = 1
    var into = max(0, xp)
    var need = 90
    while into >= need && level < 99 {
        into -= need
        level += 1
        need = min(90 * level, 1200)
    }
    return LevelInfo(level: level, into: into, need: need)
}

/// progress.js stageName — matched to what the plant visually shows at that level.
func stageName(_ level: Int) -> String {
    if level <= 2 { return "sprout" }
    if level <= 6 { return "bud" }
    if level <= 9 { return "bloom" }
    return "radiant"
}

// MARK: - Garden-wide tiers

struct Tier: Equatable {
    var name: String
    var icon: String
    var hours: Double
}

let TIERS: [Tier] = [
    Tier(name: "Seed", icon: "seed", hours: 0),
    Tier(name: "Sprout", icon: "sprout", hours: 5),
    Tier(name: "Bud", icon: "leaf", hours: 15),
    Tier(name: "Bloom", icon: "flower", hours: 40),
    Tier(name: "Meadow", icon: "daisy", hours: 100),
    Tier(name: "Forest", icon: "pine", hours: 250),
]

struct TierInfo {
    var index: Int
    var cur: Tier
    var next: Tier?
    var progress: Double
    var minutesToNext: Int
}

func gardenTier(totalMinutes: Int) -> TierInfo {
    let h = Double(totalMinutes) / 60
    var i = 0
    while i + 1 < TIERS.count && h >= TIERS[i + 1].hours { i += 1 }
    let cur = TIERS[i]
    let next = i + 1 < TIERS.count ? TIERS[i + 1] : nil
    let progress = next.map { min(1, (h - cur.hours) / ($0.hours - cur.hours)) } ?? 1
    let toNext = next.map { Int((($0.hours - h) * 60).rounded(.up)) } ?? 0
    return TierInfo(index: i, cur: cur, next: next, progress: progress, minutesToNext: toNext)
}

// MARK: - Keepsakes

/// The slice of AppStore the keepsake tests need — keeps this file UI-free.
protocol ProgressQueries {
    var state: BloomState { get }
    func streak() -> Int
    func minutesTotal(_ skillId: String?) -> Int
    func levelOf(_ skillId: String) -> LevelInfo
}

struct Keepsake: Identifiable {
    var id: String
    var icon: String
    var name: String
    var how: String
    var test: (any ProgressQueries) -> Bool
}

let KEEPSAKES: [Keepsake] = [
    Keepsake(id: "first-drop", icon: "drop", name: "First watering", how: "log your first session", test: { !$0.state.sessions.isEmpty }),
    Keepsake(id: "real-garden", icon: "sprout", name: "A real garden", how: "grow three plants at once", test: { $0.state.skills.count >= 3 }),
    Keepsake(id: "week-streak", icon: "flame", name: "A full week", how: "keep a 7-day streak", test: { $0.streak() >= 7 }),
    Keepsake(id: "month-streak", icon: "star", name: "A whole month", how: "keep a 30-day streak", test: { $0.streak() >= 30 }),
    Keepsake(id: "ten-hours", icon: "clock", name: "Ten hours grown", how: "reach 10 focused hours", test: { $0.minutesTotal(nil) >= 600 }),
    Keepsake(id: "deep-roots", icon: "pine", name: "Deep roots", how: "reach 50 focused hours", test: { $0.minutesTotal(nil) >= 3000 }),
    Keepsake(id: "first-bloom", icon: "flower", name: "First bloom", how: "grow a plant to level 7", test: { s in s.state.skills.contains { s.levelOf($0.id).level >= 7 } }),
    Keepsake(id: "radiant", icon: "daisy", name: "Radiant", how: "grow a plant to level 10", test: { s in s.state.skills.contains { s.levelOf($0.id).level >= 10 } }),
    Keepsake(id: "task-tamer", icon: "check-square", name: "Task tamer", how: "finish 25 tasks", test: { s in
        s.state.tasks.filter(\.done).count + s.state.tasks.reduce(0) { $0 + ($1.completions ?? 0) } >= 25
    }),
]
