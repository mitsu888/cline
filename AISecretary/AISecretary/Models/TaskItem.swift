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

    init(
        title: String,
        detail: String = "",
        dueDate: Date? = nil,
        priority: Priority = .normal
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = false
        self.completedAt = nil
        self.createdAt = Date()
    }

    func toggleComplete() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }
}
