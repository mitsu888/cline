import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var detail: String
    var dueDate: Date?
    var priority: Priority
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var isPrioritySuggested: Bool      // AIが優先度を提案したか
    var priorityConfidence: Double     // 提案の確信度 (0.0~1.0)

    init(
        title: String,
        detail: String = "",
        dueDate: Date? = nil,
        priority: Priority = .normal,
        isPrioritySuggested: Bool = false,
        priorityConfidence: Double = 0.0
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = false
        self.completedAt = nil
        self.createdAt = Date()
        self.isPrioritySuggested = isPrioritySuggested
        self.priorityConfidence = priorityConfidence
    }

    func toggleComplete() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }
}
