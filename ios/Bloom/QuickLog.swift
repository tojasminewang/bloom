// QuickLog.swift — "1h math" → parsed. Ported from util.js parseQuickLog + guessIcon.
import Foundation

struct QuickLogResult {
    var minutes: Int
    var date: String
    var name: String          // pretty-cased new-plant name
    var skill: Skill?         // matched existing plant, if any
}

private let FILLERS: Set<String> = ["of", "on", "for", "doing", "i", "did", "me", "my", "a", "an", "the", "spent", "practicing", "practiced", "studying", "studied", "was", "been", "just"]

func parseQuickLog(_ text: String, skills: [Skill], forced: Skill? = nil) -> QuickLogResult? {
    var t = " " + text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + " "
    if t.trimmingCharacters(in: .whitespaces).isEmpty { return nil }

    var date = todayYmd()
    if t.range(of: "\\byesterday\\b", options: .regularExpression) != nil {
        date = addDays(date, -1)
        t = t.replacingOccurrences(of: "\\byesterday\\b", with: " ", options: .regularExpression)
    }
    t = t.replacingOccurrences(of: "\\btoday\\b", with: " ", options: .regularExpression)

    if let m = t.range(of: "\\b(\\d{4}-\\d{2}-\\d{2})\\b", options: .regularExpression) {
        date = String(t[m])
        t = t.replacingOccurrences(of: date, with: " ")
    }

    var minutes = 0
    // hours: "1h", "1.5 hours", "2hrs"
    if let re = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)\\s*h(?:ours?|rs?)?\\b") {
        let ns = t as NSString
        var consumed: [NSRange] = []
        re.enumerateMatches(in: t, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m else { return }
            if let v = Double(ns.substring(with: m.range(at: 1))) { minutes += Int((v * 60).rounded()) }
            consumed.append(m.range)
        }
        for r in consumed.reversed() { t = (t as NSString).replacingCharacters(in: r, with: " ") }
    }
    // minutes: "30m", "45 min", "10 minutes"
    if let re = try? NSRegularExpression(pattern: "(\\d+)\\s*m(?:in(?:ute)?s?)?\\b") {
        let ns = t as NSString
        var consumed: [NSRange] = []
        re.enumerateMatches(in: t, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m else { return }
            if let v = Int(ns.substring(with: m.range(at: 1))) { minutes += v }
            consumed.append(m.range)
        }
        for r in consumed.reversed() { t = (t as NSString).replacingCharacters(in: r, with: " ") }
    }

    if minutes == 0 || minutes > 24 * 60 { return nil }
    if let forced { return QuickLogResult(minutes: minutes, date: date, name: forced.name, skill: forced) }

    let name = t.split(separator: " ").map(String.init).filter { !$0.isEmpty && !FILLERS.contains($0) }.joined(separator: " ")
    if name.isEmpty { return nil }
    let pretty = name.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    let lower = name.lowercased()
    let skill = skills.first { $0.name.lowercased() == lower }
        ?? skills.first { $0.name.lowercased().hasPrefix(lower) || lower.hasPrefix($0.name.lowercased()) }
    return QuickLogResult(minutes: minutes, date: date, name: pretty, skill: skill)
}

/// util.js guessIcon — name → line-icon key for a freshly planted skill.
func guessIcon(_ name: String) -> String {
    let n = name.lowercased()
    let map: [(String, String)] = [
        ("math|calc|algebra|geometr|trig|physic", "calc"),
        ("read|book|novel|liter", "book"),
        ("code|coding|program|dev|python|javascript|swift", "code"),
        ("spanish|french|language|english|japanese|korean|chinese|german|italian", "globe"),
        ("piano|keyboard|guitar|ukulele|music|sing|voice|violin|drum", "music"),
        ("gym|workout|lift|fitness|exercise", "dumbbell"),
        ("run|jog|cardio|swim|soccer|basket|tennis|sport", "ball"),
        ("yoga|stretch|meditat|journal.*grat|selfcare|self-care", "heart"),
        ("art|draw|paint|sketch|design", "palette"),
        ("write|writing|journal|essay|blog", "pencil"),
        ("science|chem|bio|lab", "flask"),
        ("study|school|exam|homework|class|course", "cap"),
        ("cook|bake|recipe", "pan"),
        ("game|unity|phaser|godot", "gamepad"),
        ("business|shop|store|dropship|marketing", "briefcase"),
        ("video|edit|youtube|film|short", "film"),
        ("dance|ballet|perform", "star"),
        ("chess|strateg|aim|goal", "target"),
        ("photo|camera", "camera"),
        ("talk|speech|debate", "chat"),
    ]
    for (pattern, icon) in map where n.range(of: pattern, options: .regularExpression) != nil {
        return icon
    }
    return "sprout"
}
