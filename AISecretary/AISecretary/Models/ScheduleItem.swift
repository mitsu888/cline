import Foundation
import SwiftData

@Model
final class ScheduleItem {
    var id: UUID
    var title: String
    var detail: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var priority: Priority
    var location: String
    var reminderMinutesBefore: Int?
    var isCompleted: Bool
    var createdAt: Date

    init(
        title: String,
        detail: String = "",
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        priority: Priority = .normal,
        location: String = "",
        reminderMinutesBefore: Int? = 15
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.startDate = startDate
        self.endDate = endDate ?? startDate.addingTimeInterval(3600)
        self.isAllDay = isAllDay
        self.priority = priority
        self.location = location
        self.reminderMinutesBefore = reminderMinutesBefore
        self.isCompleted = false
        self.createdAt = Date()
    }
}
