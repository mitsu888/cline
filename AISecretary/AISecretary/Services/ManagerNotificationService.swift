import Foundation
import UserNotifications
import MapKit

/// 芸能人のマネージャーのように、出発時刻を逆算して段階的に催促通知を送るサービス
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
        homeLocation: String,
        prepTimeMinutes: Int,
        transportType: MKDirectionsTransportType
    ) async {
        guard !schedule.location.isEmpty, !homeLocation.isEmpty else { return }

        isCalculating = true
        defer { isCalculating = false }

        guard let travel = await travelTimeService.calculateTravelTime(
            from: homeLocation,
            to: schedule.location,
            transportType: transportType
        ) else { return }

        let bufferMinutes: TimeInterval = 10 * 60  // 余裕10分
        let travelSeconds = travel.travelTimeSeconds + bufferMinutes
        let departureDate = schedule.startDate.addingTimeInterval(-travelSeconds)
        let prepDate = departureDate.addingTimeInterval(-TimeInterval(prepTimeMinutes * 60))
        let urgentDate = departureDate.addingTimeInterval(5 * 60) // 出発5分後

        let now = Date()
        let scheduleId = schedule.id.uuidString.prefix(8)
        let travelMin = travel.travelTimeMinutes
        let departureTimeStr = departureDate.shortTimeString

        // 1. 準備開始通知
        if prepDate > now {
            let content = UNMutableNotificationContent()
            content.title = "準備を始めましょう"
            content.body = "「\(schedule.title)」は\(schedule.startDate.shortTimeString)から。\(schedule.location)まで約\(travelMin)分。\(departureTimeStr)には出発しましょう。"
            content.sound = .default
            content.categoryIdentifier = "MANAGER_PREP"
            scheduleNotification(id: "mgr-prep-\(scheduleId)", content: content, date: prepDate)
        }

        // 2. 出発通知（短い音で催促）
        if departureDate > now {
            let content = UNMutableNotificationContent()
            content.title = "出発の時間です！"
            content.body = "「\(schedule.title)」に間に合うよう、今すぐ出発してください。\(schedule.location)まで約\(travelMin)分です。"
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
        homeLocation: String,
        prepTimeMinutes: Int,
        transportType: MKDirectionsTransportType
    ) async {
        let todaySchedules = schedules
            .filter { $0.startDate.isToday && !$0.location.isEmpty && $0.startDate > Date() }
            .sorted { $0.startDate < $1.startDate }

        for schedule in todaySchedules {
            await setupManagerAlerts(
                for: schedule,
                homeLocation: homeLocation,
                prepTimeMinutes: prepTimeMinutes,
                transportType: transportType
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
