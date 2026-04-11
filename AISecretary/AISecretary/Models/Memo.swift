import Foundation
import SwiftData

@Model
final class Memo {
    var id: UUID
    var content: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isVoiceMemo: Bool
    var audioFilePath: String?
    var priority: Priority
    var tags: [String]

    init(
        content: String,
        title: String = "",
        isVoiceMemo: Bool = false,
        audioFilePath: String? = nil,
        priority: Priority = .normal,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.content = content
        self.title = title.isEmpty ? String(content.prefix(30)) : title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isVoiceMemo = isVoiceMemo
        self.audioFilePath = audioFilePath
        self.priority = priority
        self.tags = tags
    }
}

enum Priority: Int, Codable, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3

    var label: String {
        switch self {
        case .low: "低"
        case .normal: "普通"
        case .high: "高"
        case .urgent: "緊急"
        }
    }

    var color: String {
        switch self {
        case .low: "gray"
        case .normal: "blue"
        case .high: "orange"
        case .urgent: "red"
        }
    }
}
