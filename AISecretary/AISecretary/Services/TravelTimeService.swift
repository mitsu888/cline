import Foundation

/// 移動時間を管理するサービス（簡易版 - GPS不使用）
/// ユーザーが手動で設定した移動時間を使用し、出発通知を提供
@MainActor
final class TravelTimeService: ObservableObject {
    @Published var isCalculating = false

    /// 保存済みの移動時間プリセット（場所名 → 移動分数）
    /// UserDefaultsで永続化
    var savedTravelTimes: [String: Int] {
        get {
            UserDefaults.standard.dictionary(forKey: "saved_travel_times") as? [String: Int] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "saved_travel_times")
        }
    }

    /// デフォルトの移動時間（分）- プリセットに登録がない場合に使用
    var defaultTravelMinutes: Int {
        get { UserDefaults.standard.object(forKey: "default_travel_minutes") as? Int ?? 30 }
        set { UserDefaults.standard.set(newValue, forKey: "default_travel_minutes") }
    }

    /// 場所に対する移動時間を取得（手動設定値を参照）
    func getTravelTime(to destination: String) -> TravelTimeResult {
        let minutes: Int

        // 完全一致で検索
        if let saved = savedTravelTimes[destination] {
            minutes = saved
        }
        // 部分一致で検索（「渋谷」で「渋谷駅前ホール」にもマッチ）
        else if let match = savedTravelTimes.first(where: { destination.contains($0.key) || $0.key.contains(destination) }) {
            minutes = match.value
        }
        // デフォルト値を使用
        else {
            minutes = defaultTravelMinutes
        }

        return TravelTimeResult(
            travelTimeMinutes: minutes,
            destinationName: destination,
            isEstimated: savedTravelTimes[destination] == nil
        )
    }

    /// 移動時間プリセットを保存
    func saveTravelTime(destination: String, minutes: Int) {
        var times = savedTravelTimes
        times[destination] = minutes
        savedTravelTimes = times
    }

    /// 移動時間プリセットを削除
    func removeTravelTime(destination: String) {
        var times = savedTravelTimes
        times.removeValue(forKey: destination)
        savedTravelTimes = times
    }

    /// スケジュールに対して出発通知を設定
    func calculateAndNotify(
        nextSchedule: ScheduleItem,
        prepTimeMinutes: Int
    ) -> TravelTimeResult? {
        guard !nextSchedule.location.isEmpty else { return nil }

        let result = getTravelTime(to: nextSchedule.location)

        // 移動時間 + バッファ（10分）を考慮した出発時刻を計算
        let bufferMinutes = 10
        let totalMinutes = result.travelTimeMinutes + bufferMinutes
        let departureTime = nextSchedule.startDate.addingTimeInterval(
            -TimeInterval(totalMinutes * 60)
        )

        if departureTime > Date() {
            NotificationService.shared.scheduleNotification(
                id: "travel-\(nextSchedule.id)",
                title: "そろそろ出発の時間です",
                body: "「\(nextSchedule.title)」まで約\(result.travelTimeMinutes)分\(result.isEstimated ? "（推定）" : "")。\(nextSchedule.location)への移動を始めましょう。",
                date: departureTime
            )
        }

        return result
    }

    /// 今日のスケジュールに対して移動時間を一括取得
    func getTravelTimesForToday(
        schedules: [ScheduleItem]
    ) -> [UUID: TravelTimeResult] {
        var results: [UUID: TravelTimeResult] = [:]
        let todaySchedules = schedules
            .filter { $0.startDate.isToday && !$0.location.isEmpty }
            .sorted { $0.startDate < $1.startDate }

        for schedule in todaySchedules {
            results[schedule.id] = getTravelTime(to: schedule.location)
        }

        return results
    }
}

/// 移動時間の結果（簡易版）
struct TravelTimeResult {
    let travelTimeMinutes: Int
    let destinationName: String
    let isEstimated: Bool   // true = デフォルト値使用（プリセット未登録）

    var travelTimeSeconds: TimeInterval {
        TimeInterval(travelTimeMinutes * 60)
    }

    var summary: String {
        let estimate = isEstimated ? "（推定）" : ""
        return "約\(travelTimeMinutes)分\(estimate)"
    }

    var transportIcon: String {
        "mappin.and.ellipse"
    }
}
