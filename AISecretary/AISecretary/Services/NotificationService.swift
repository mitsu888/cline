import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        sound: UNNotificationSound = .default
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleReminder(for schedule: ScheduleItem) {
        guard let minutesBefore = schedule.reminderMinutesBefore else { return }

        let reminderDate = schedule.startDate.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        guard reminderDate > Date() else { return }

        scheduleNotification(
            id: "schedule-\(schedule.id)",
            title: "予定のリマインダー",
            body: "\(schedule.title)が\(minutesBefore)分後に始まります",
            date: reminderDate
        )
    }

    func scheduleTaskReminder(for task: TaskItem) {
        guard let dueDate = task.dueDate, !task.isCompleted else { return }

        let reminderDate = Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: dueDate
        ) ?? dueDate

        guard reminderDate > Date() else { return }

        scheduleNotification(
            id: "task-\(task.id)",
            title: "タスクの期限",
            body: "「\(task.title)」の期限日です",
            date: reminderDate
        )
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
