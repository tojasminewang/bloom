// NotificationPlanner.swift — real iOS notifications for what the web could only wish for:
// the session-end ringer fires with the app closed, and the daily reminder too.
import Foundation
import UserNotifications

enum NotificationPlanner {
    static let sessionEndId = "bloom-session-end"
    static let reminderId = "bloom-daily-reminder"

    static func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Re-plan everything from current state. Called from every save.
    static func sync(store: AppStore) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [sessionEndId, reminderId])

        // 1) session end — scheduled at the phase's wall-clock end so it fires when suspended
        if let t = store.state.timer, t.pausedAt == nil {
            let remaining = store.timerRemaining()
            if remaining > 1 {
                let content = UNMutableNotificationContent()
                let sk = store.skill(t.skillId)
                if t.phase == "break" {
                    content.title = "Break over"
                    content.body = t.mode == "cycle" ? "Back to \(sk?.name ?? "it") — you've got this." : "Fresh and ready to grow."
                } else {
                    let minutes = max(1, Int((t.durationSec / 60).rounded()))
                    content.title = "Session complete"
                    content.body = sk.map { "+\(minutes)m to \($0.name) — lovely work." } ?? "Lovely work."
                }
                content.sound = ringerSound(store.state.settings)
                content.interruptionLevel = .timeSensitive
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
                center.add(UNNotificationRequest(identifier: sessionEndId, content: content, trigger: trigger))
            }
        }

        // 2) daily reminder — same voice as reminders.js
        let s = store.state.settings
        if s.reminder {
            let parts = s.reminderTime.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                let content = UNMutableNotificationContent()
                let st = store.streak()
                if st >= 2 {
                    content.title = "Keep your \(st)-day streak alive 🌱"
                    content.body = "A few focused minutes today keeps your garden growing."
                } else {
                    content.title = "Your garden is thirsty 🌱"
                    content.body = "A little water today — even five minutes counts."
                }
                content.sound = .default
                var comps = DateComponents()
                comps.hour = parts[0]; comps.minute = parts[1]
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                center.add(UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger))
            }
        }
    }

    private static func ringerSound(_ settings: BloomSettings) -> UNNotificationSound? {
        guard settings.sound, settings.ringer != "silent" else { return nil }
        let file = "ringer-\(settings.ringer).caf"
        if Bundle.main.url(forResource: file, withExtension: nil) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(file))
        }
        return .default
    }
}
