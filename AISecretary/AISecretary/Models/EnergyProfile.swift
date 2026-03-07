import Foundation

/// ユーザーのエネルギーレベルプロファイル
/// 時間帯ごとの集中力・エネルギーレベルを管理
struct EnergyProfile: Codable {
    var chronotype: Chronotype
    var timeSlotEnergies: [TimeSlotEnergy]

    init(chronotype: Chronotype = .morning) {
        self.chronotype = chronotype
        self.timeSlotEnergies = chronotype.defaultEnergies
    }

    /// 指定時間のエネルギーレベルを取得
    func energyLevel(at hour: Int) -> EnergyLevel {
        for slot in timeSlotEnergies {
            if hour >= slot.startHour && hour < slot.endHour {
                return slot.energy
            }
        }
        return .low
    }

    /// 高エネルギーの時間帯を取得（重要タスク配置用）
    var peakHours: [Int] {
        timeSlotEnergies
            .filter { $0.energy == .peak }
            .flatMap { Array($0.startHour..<$0.endHour) }
    }

    /// タスクの推奨配置時間を提案
    func recommendedTimeSlot(for priority: Priority) -> String {
        switch priority {
        case .urgent, .high:
            let peakSlots = timeSlotEnergies.filter { $0.energy == .peak }
            if let first = peakSlots.first {
                return "\(first.startHour):00〜\(first.endHour):00（ピーク時間帯）"
            }
            return "午前中（集中力が高い時間帯）"
        case .normal:
            let highSlots = timeSlotEnergies.filter { $0.energy == .high }
            if let first = highSlots.first {
                return "\(first.startHour):00〜\(first.endHour):00"
            }
            return "午後（通常集中力の時間帯）"
        case .low:
            let lowSlots = timeSlotEnergies.filter { $0.energy == .low || $0.energy == .medium }
            if let first = lowSlots.first {
                return "\(first.startHour):00〜\(first.endHour):00"
            }
            return "夕方以降"
        }
    }
}

/// 体内時計タイプ
enum Chronotype: String, Codable, CaseIterable {
    case earlyBird    // 超朝型
    case morning      // 朝型
    case evening      // 夜型
    case nightOwl     // 超夜型

    var label: String {
        switch self {
        case .earlyBird: "超朝型（ヒバリ型）"
        case .morning: "朝型"
        case .evening: "夜型"
        case .nightOwl: "超夜型（フクロウ型）"
        }
    }

    var icon: String {
        switch self {
        case .earlyBird: "sunrise.fill"
        case .morning: "sun.max.fill"
        case .evening: "sunset.fill"
        case .nightOwl: "moon.fill"
        }
    }

    var defaultEnergies: [TimeSlotEnergy] {
        switch self {
        case .earlyBird:
            return [
                TimeSlotEnergy(startHour: 5, endHour: 8, energy: .peak),
                TimeSlotEnergy(startHour: 8, endHour: 11, energy: .high),
                TimeSlotEnergy(startHour: 11, endHour: 14, energy: .medium),
                TimeSlotEnergy(startHour: 14, endHour: 17, energy: .low),
                TimeSlotEnergy(startHour: 17, endHour: 21, energy: .low),
            ]
        case .morning:
            return [
                TimeSlotEnergy(startHour: 6, endHour: 9, energy: .high),
                TimeSlotEnergy(startHour: 9, endHour: 12, energy: .peak),
                TimeSlotEnergy(startHour: 12, endHour: 15, energy: .medium),
                TimeSlotEnergy(startHour: 15, endHour: 18, energy: .high),
                TimeSlotEnergy(startHour: 18, endHour: 22, energy: .low),
            ]
        case .evening:
            return [
                TimeSlotEnergy(startHour: 7, endHour: 10, energy: .low),
                TimeSlotEnergy(startHour: 10, endHour: 13, energy: .medium),
                TimeSlotEnergy(startHour: 13, endHour: 16, energy: .high),
                TimeSlotEnergy(startHour: 16, endHour: 20, energy: .peak),
                TimeSlotEnergy(startHour: 20, endHour: 23, energy: .high),
            ]
        case .nightOwl:
            return [
                TimeSlotEnergy(startHour: 8, endHour: 11, energy: .low),
                TimeSlotEnergy(startHour: 11, endHour: 14, energy: .medium),
                TimeSlotEnergy(startHour: 14, endHour: 17, energy: .high),
                TimeSlotEnergy(startHour: 17, endHour: 21, energy: .peak),
                TimeSlotEnergy(startHour: 21, endHour: 24, energy: .high),
            ]
        }
    }
}

/// 時間帯ごとのエネルギー設定
struct TimeSlotEnergy: Codable, Identifiable {
    var id: String { "\(startHour)-\(endHour)" }
    var startHour: Int
    var endHour: Int
    var energy: EnergyLevel
}

/// エネルギーレベル
enum EnergyLevel: Int, Codable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case peak = 3

    var label: String {
        switch self {
        case .low: "低い"
        case .medium: "普通"
        case .high: "高い"
        case .peak: "ピーク"
        }
    }

    var icon: String {
        switch self {
        case .low: "battery.25"
        case .medium: "battery.50"
        case .high: "battery.75"
        case .peak: "battery.100"
        }
    }

    var color: String {
        switch self {
        case .low: "gray"
        case .medium: "blue"
        case .high: "orange"
        case .peak: "red"
        }
    }
}
