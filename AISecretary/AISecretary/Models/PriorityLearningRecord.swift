import Foundation
import SwiftData

/// タスク完了パターンの学習データ
/// ユーザーの行動パターンを記録し、優先度の自動提案に使用
@Model
final class PriorityLearningRecord {
    var id: UUID
    var keyword: String          // タスク名のキーワード
    var assignedPriority: Int    // ユーザーが設定した優先度 (Priority.rawValue)
    var wasCompleted: Bool       // 完了したか
    var completionTimeHours: Double? // 作成から完了までの時間
    var dayOfWeek: Int           // 曜日 (1=日, 7=土)
    var hourCreated: Int         // 作成時刻
    var createdAt: Date

    init(
        keyword: String,
        assignedPriority: Priority,
        wasCompleted: Bool = false,
        completionTimeHours: Double? = nil,
        dayOfWeek: Int = 1,
        hourCreated: Int = 9
    ) {
        self.id = UUID()
        self.keyword = keyword.lowercased()
        self.assignedPriority = assignedPriority.rawValue
        self.wasCompleted = wasCompleted
        self.completionTimeHours = completionTimeHours
        self.dayOfWeek = dayOfWeek
        self.hourCreated = hourCreated
        self.createdAt = Date()
    }
}
