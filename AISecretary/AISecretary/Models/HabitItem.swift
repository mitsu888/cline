import Foundation
import SwiftData

/// 習慣トラッカーのモデル
/// 毎日繰り返す習慣を管理し、達成率を追跡する
@Model
final class HabitItem {
    var id: UUID
    var title: String
    var detail: String
    /// 習慣の実行時間（分）
    var durationMinutes: Int
    /// 希望する時間帯
    var preferredTimeSlot: TimeSlot
    /// 作成日
    var createdAt: Date
    /// 有効かどうか
    var isActive: Bool
    /// アイコン名（SF Symbols）
    var iconName: String
    /// 連続達成日数
    var currentStreak: Int
    /// 最長連続達成日数
    var bestStreak: Int

    init(
        title: String,
        detail: String = "",
        durationMinutes: Int = 30,
        preferredTimeSlot: TimeSlot = .morning,
        iconName: String = "star.fill"
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.durationMinutes = durationMinutes
        self.preferredTimeSlot = preferredTimeSlot
        self.createdAt = Date()
        self.isActive = true
        self.iconName = iconName
        self.currentStreak = 0
        self.bestStreak = 0
    }
}

/// 習慣の達成記録（日ごと）
@Model
final class HabitLog {
    var id: UUID
    var habitId: UUID
    var date: Date
    var isCompleted: Bool
    var completedAt: Date?
    var note: String

    init(habitId: UUID, date: Date = Date()) {
        self.id = UUID()
        self.habitId = habitId
        self.date = Calendar.current.startOfDay(for: date)
        self.isCompleted = false
        self.completedAt = nil
        self.note = ""
    }
}

/// 希望する時間帯
enum TimeSlot: Int, Codable, CaseIterable {
    case earlyMorning = 0  // 5-7時
    case morning = 1       // 7-9時
    case forenoon = 2      // 9-12時
    case afternoon = 3     // 12-15時
    case evening = 4       // 15-18時
    case night = 5         // 18-21時

    var label: String {
        switch self {
        case .earlyMorning: "早朝 (5-7時)"
        case .morning: "朝 (7-9時)"
        case .forenoon: "午前 (9-12時)"
        case .afternoon: "午後 (12-15時)"
        case .evening: "夕方 (15-18時)"
        case .night: "夜 (18-21時)"
        }
    }

    var shortLabel: String {
        switch self {
        case .earlyMorning: "早朝"
        case .morning: "朝"
        case .forenoon: "午前"
        case .afternoon: "午後"
        case .evening: "夕方"
        case .night: "夜"
        }
    }

    var icon: String {
        switch self {
        case .earlyMorning: "sunrise"
        case .morning: "sun.and.horizon"
        case .forenoon: "sun.max"
        case .afternoon: "sun.min"
        case .evening: "sunset"
        case .night: "moon.stars"
        }
    }

    /// この時間帯の開始時間（時）
    var startHour: Int {
        switch self {
        case .earlyMorning: 5
        case .morning: 7
        case .forenoon: 9
        case .afternoon: 12
        case .evening: 15
        case .night: 18
        }
    }
}
