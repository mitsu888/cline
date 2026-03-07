import Foundation
import SwiftData

/// AI秘書のプロアクティブ機能を管理するサービス
/// - 日次スケジュール報告の生成
/// - タスク優先度の自動調整
/// - 低優先度タスクの「箱入れ」（アーカイブ）
/// - こなせない量の検知と提案
@MainActor
final class DailyBriefingService: ObservableObject {
    @Published var todaysBriefing: DailyBriefing?
    @Published var isGenerating = false

    private var apiService: ClaudeAPIService?

    func setup(apiKey: String) {
        self.apiService = ClaudeAPIService(apiKey: apiKey)
    }

    /// 毎朝の日次報告を生成
    func generateDailyBriefing(
        schedules: [ScheduleItem],
        tasks: [TaskItem],
        userName: String
    ) async throws -> DailyBriefing {
        guard let apiService else { throw ClaudeError.noAPIKey }

        isGenerating = true
        defer { isGenerating = false }

        let todaySchedules = schedules.filter { $0.startDate.isToday }
        let tomorrowSchedules = schedules.filter { $0.startDate.isTomorrow }
        let pendingTasks = tasks.filter { !$0.isCompleted }
        let overdueTasks = pendingTasks.filter {
            guard let due = $0.dueDate else { return false }
            return due < Date()
        }
        let todayTasks = pendingTasks.filter {
            guard let due = $0.dueDate else { return false }
            return due.isToday
        }

        let scheduleList = todaySchedules.map {
            "- \($0.startDate.shortTimeString) \($0.title) [\($0.priority.label)]"
        }.joined(separator: "\n")

        let tomorrowList = tomorrowSchedules.map {
            "- \($0.startDate.shortTimeString) \($0.title)"
        }.joined(separator: "\n")

        let taskList = pendingTasks.map {
            "- \($0.title) [優先度: \($0.priority.label)] \($0.dueDate != nil ? "期限: \($0.dueDate!.shortDateString)" : "期限なし")"
        }.joined(separator: "\n")

        let overdueList = overdueTasks.map {
            "- \($0.title) (期限: \($0.dueDate!.shortDateString))"
        }.joined(separator: "\n")

        let prompt = """
        \(userName.isEmpty ? "ユーザー" : userName)さんの秘書として、今日の日次報告を作成してください。

        ## 今日の予定 (\(todaySchedules.count)件):
        \(scheduleList.isEmpty ? "予定なし" : scheduleList)

        ## 明日の予定 (\(tomorrowSchedules.count)件):
        \(tomorrowList.isEmpty ? "予定なし" : tomorrowList)

        ## 未完了タスク (\(pendingTasks.count)件):
        \(taskList.isEmpty ? "なし" : taskList)

        ## 期限超過タスク (\(overdueTasks.count)件):
        \(overdueList.isEmpty ? "なし" : overdueList)

        ## 今日が期限のタスク (\(todayTasks.count)件):
        \(todayTasks.map { "- \($0.title)" }.joined(separator: "\n"))

        以下の形式でJSON応答してください:
        ```json
        {
            "greeting": "おはようございます、○○さん。今日の報告です。",
            "schedule_summary": "今日のスケジュール概要（自然な日本語で）",
            "task_summary": "タスク状況の概要",
            "overload_detected": true/false,
            "recommendations": ["提案1", "提案2"],
            "tasks_to_archive": [{"title": "タスク名", "reason": "理由"}],
            "priority_adjustments": [{"title": "タスク名", "new_priority": "high/normal/low", "reason": "理由"}],
            "motivational_note": "一言励まし/アドバイス"
        }
        ```

        重要なルール:
        - タスクが多すぎて1日でこなせない場合は overload_detected を true にする
        - 優先度の低いタスクは tasks_to_archive で「箱にしまう」提案をする
        - 期限超過タスクがあれば最優先で対応を提案する
        - スケジュールの隙間時間を活用した提案もする
        """

        let messages = [ClaudeAPIService.APIMessage(role: "user", content: prompt)]
        let response = try await apiService.sendMessage(messages: messages)

        let briefing = parseBriefing(response, todayScheduleCount: todaySchedules.count, pendingTaskCount: pendingTasks.count)
        self.todaysBriefing = briefing
        return briefing
    }

    /// タスク量を評価し、こなせない場合は自動的に提案
    func evaluateWorkload(tasks: [TaskItem]) -> WorkloadStatus {
        let pendingTasks = tasks.filter { !$0.isCompleted }
        let todayTasks = pendingTasks.filter {
            guard let due = $0.dueDate else { return false }
            return due.isToday
        }
        let urgentTasks = pendingTasks.filter { $0.priority == .urgent || $0.priority == .high }

        if todayTasks.count > 8 || urgentTasks.count > 5 {
            return .overloaded
        } else if todayTasks.count > 5 || urgentTasks.count > 3 {
            return .heavy
        } else {
            return .manageable
        }
    }

    /// 低優先度タスクをアーカイブ（箱にしまう）提案
    func suggestArchiveTasks(tasks: [TaskItem]) -> [TaskItem] {
        let pendingTasks = tasks.filter { !$0.isCompleted }
        guard pendingTasks.count > 8 else { return [] }

        return pendingTasks
            .filter { $0.priority == .low }
            .sorted { ($0.dueDate ?? .distantFuture) > ($1.dueDate ?? .distantFuture) }
    }

    private func parseBriefing(_ response: String, todayScheduleCount: Int, pendingTaskCount: Int) -> DailyBriefing {
        guard let jsonRange = response.range(of: "```json"),
              let endRange = response.range(of: "```", range: jsonRange.upperBound..<response.endIndex),
              let data = String(response[jsonRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return DailyBriefing(
                greeting: "おはようございます。今日も頑張りましょう。",
                scheduleSummary: "本日の予定は\(todayScheduleCount)件です。",
                taskSummary: "未完了タスクは\(pendingTaskCount)件です。",
                overloadDetected: false,
                recommendations: [],
                tasksToArchive: [],
                priorityAdjustments: [],
                motivationalNote: response
            )
        }

        return DailyBriefing(
            greeting: json["greeting"] as? String ?? "おはようございます。",
            scheduleSummary: json["schedule_summary"] as? String ?? "",
            taskSummary: json["task_summary"] as? String ?? "",
            overloadDetected: json["overload_detected"] as? Bool ?? false,
            recommendations: json["recommendations"] as? [String] ?? [],
            tasksToArchive: (json["tasks_to_archive"] as? [[String: String]])?.map {
                ArchiveSuggestion(title: $0["title"] ?? "", reason: $0["reason"] ?? "")
            } ?? [],
            priorityAdjustments: (json["priority_adjustments"] as? [[String: String]])?.map {
                PriorityAdjustment(title: $0["title"] ?? "", newPriority: $0["new_priority"] ?? "normal", reason: $0["reason"] ?? "")
            } ?? [],
            motivationalNote: json["motivational_note"] as? String ?? ""
        )
    }
}

struct DailyBriefing {
    let greeting: String
    let scheduleSummary: String
    let taskSummary: String
    let overloadDetected: Bool
    let recommendations: [String]
    let tasksToArchive: [ArchiveSuggestion]
    let priorityAdjustments: [PriorityAdjustment]
    let motivationalNote: String
}

struct ArchiveSuggestion {
    let title: String
    let reason: String
}

struct PriorityAdjustment {
    let title: String
    let newPriority: String
    let reason: String
}

enum WorkloadStatus {
    case manageable
    case heavy
    case overloaded

    var label: String {
        switch self {
        case .manageable: "余裕あり"
        case .heavy: "やや多い"
        case .overloaded: "オーバーロード"
        }
    }

    var color: String {
        switch self {
        case .manageable: "green"
        case .heavy: "orange"
        case .overloaded: "red"
        }
    }
}
