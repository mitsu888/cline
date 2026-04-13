import Foundation
import UserNotifications

/// 芸能人のマネージャーのように、出発時刻を逆算して段階的に催促通知を送るサービス
/// 簡易版: GPS不使用、手動設定の移動時間を使用
/// - 準備開始通知（出発時刻 - 準備時間）
/// - 出発通知（移動時間 + バッファから逆算）
/// - 急ぎ催促通知（出発時刻を過ぎた場合）
@MainActor
final class ManagerNotificationService: ObservableObject {
    @Published var isCalculating = false

    private let travelTimeService = TravelTimeService()

    /// スケジュールに対してマネージャー式の段階通知をセットアップ
    func setupManagerAlerts(
        for schedule: ScheduleItem,
        prepTimeMinutes: Int
    ) {
        guard !schedule.location.isEmpty else { return }

        isCalculating = true
        defer { isCalculating = false }

        let travel = travelTimeService.getTravelTime(to: schedule.location)

        let bufferMinutes = 10  // 余裕10分
        let totalTravelMinutes = travel.travelTimeMinutes + bufferMinutes
        let departureDate = schedule.startDate.addingTimeInterval(-TimeInterval(totalTravelMinutes * 60))
        let prepDate = departureDate.addingTimeInterval(-TimeInterval(prepTimeMinutes * 60))
        let urgentDate = departureDate.addingTimeInterval(5 * 60) // 出発5分後

        let now = Date()
        let scheduleId = schedule.id.uuidString.prefix(8)
        let travelMin = travel.travelTimeMinutes
        let departureTimeStr = departureDate.shortTimeString
        let estimateNote = travel.isEstimated ? "（推定値）" : ""

        // 1. 準備開始通知
        if prepDate > now {
            let content = UNMutableNotificationContent()
            content.title = "準備を始めましょう"
            content.body = "「\(schedule.title)」は\(schedule.startDate.shortTimeString)から。\(schedule.location)まで約\(travelMin)分\(estimateNote)。\(departureTimeStr)には出発しましょう。"
            content.sound = .default
            content.categoryIdentifier = "MANAGER_PREP"
            scheduleNotification(id: "mgr-prep-\(scheduleId)", content: content, date: prepDate)
        }

        // 2. 出発通知
        if departureDate > now {
            let content = UNMutableNotificationContent()
            content.title = "出発の時間です！"
            content.body = "「\(schedule.title)」に間に合うよう、今すぐ出発してください。\(schedule.location)まで約\(travelMin)分\(estimateNote)です。"
            content.sound = UNNotificationSound.default
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = "MANAGER_DEPART"
            scheduleNotification(id: "mgr-depart-\(scheduleId)", content: content, date: departureDate)
        }

        // 3. 急ぎ催促通知（出発時刻5分後）
        if urgentDate > now && urgentDate < schedule.startDate {
            let content = UNMutableNotificationContent()
            content.title = "急いでください！"
            content.body = "「\(schedule.title)」の開始まであと\(Int(schedule.startDate.timeIntervalSince(urgentDate) / 60))分。まだ出発していなければ急ぎましょう！"
            content.sound = UNNotificationSound.default
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = "MANAGER_URGENT"
            scheduleNotification(id: "mgr-urgent-\(scheduleId)", content: content, date: urgentDate)
        }
    }

    /// 今日のすべてのスケジュールに対してマネージャー通知をセットアップ
    func setupAlertsForTodaySchedules(
        schedules: [ScheduleItem],
        prepTimeMinutes: Int
    ) {
        let todaySchedules = schedules
            .filter { $0.startDate.isToday && !$0.location.isEmpty && $0.startDate > Date() }
            .sorted { $0.startDate < $1.startDate }

        for schedule in todaySchedules {
            setupManagerAlerts(
                for: schedule,
                prepTimeMinutes: prepTimeMinutes
            )
        }
    }

    /// スケジュールのマネージャー通知をキャンセル
    func cancelManagerAlerts(for scheduleId: UUID) {
        let prefix = scheduleId.uuidString.prefix(8)
        let ids = ["mgr-prep-\(prefix)", "mgr-depart-\(prefix)", "mgr-urgent-\(prefix)"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func scheduleNotification(id: String, content: UNMutableNotificationContent, date: Date) {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
