import Foundation
import SwiftData

/// AI秘書のプロアクティブ機能を管理するサービス
/// - 日次スケジュール報告の生成（エネルギーレベル・移動時間・習慣考慮）
/// - タスク優先度の自動調整
/// - 低優先度タスクの「箱入れ」（アーカイブ）
/// - こなせない量の検知と提案
@MainActor
final class DailyBriefingService: ObservableObject {
    @Published var todaysBriefing: DailyBriefing?
    @Published var isGenerating = false

    private var apiService: ClaudeAPIService?

    /// リレーサーバー経由またはAPI直接接続でセットアップ
    func setup(appState: AppState) {
        if appState.isRelayConfigured {
            self.apiService = ClaudeAPIService(
                serverURL: appState.relayServerURL,
                authToken: appState.relayAuthToken
            )
        } else {
            self.apiService = ClaudeAPIService(apiKey: appState.apiKey)
        }
    }

    /// 旧互換: apiKeyのみでセットアップ
    func setup(apiKey: String) {
        self.apiService = ClaudeAPIService(apiKey: apiKey)
    }

    /// 毎朝の日次報告を生成（エネルギーレベル・習慣情報込み）
    func generateDailyBriefing(
        schedules: [ScheduleItem],
        tasks: [TaskItem],
        habits: [HabitItem],
        habitLogs: [HabitLog],
        energyProfile: EnergyProfile?,
        travelTimes: [UUID: TravelTimeResult],
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

        // スケジュールリスト（移動時間付き）
        let scheduleList = todaySchedules.map { schedule in
            var line = "- \(schedule.startDate.shortTimeString) \(schedule.title) [\(schedule.priority.label)]"
            if !schedule.location.isEmpty {
                line += " [場所: \(schedule.location)]"
            }
            if let travel = travelTimes[schedule.id] {
                line += " [移動時間: \(travel.summary)]"
            }
            return line
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

        // エネルギー情報
        let energyInfo: String
        if let profile = energyProfile {
            let peakHoursStr = profile.peakHours.map { "\($0)時" }.joined(separator: ", ")
            energyInfo = """
            タイプ: \(profile.chronotype.label)
            ピーク時間帯: \(peakHoursStr)
            重要タスクの推奨時間: \(profile.recommendedTimeSlot(for: .high))
            """
        } else {
            energyInfo = "未設定"
        }

        // 習慣情報
        let activeHabits = habits.filter { $0.isActive }
        let todayHabitLogs = habitLogs.filter { Calendar.current.isDateInToday($0.date) }
        let completedHabits = activeHabits.filter { habit in
            todayHabitLogs.contains { $0.habitId == habit.id && $0.isCompleted }
        }
        let habitInfo = activeHabits.map { habit in
            let completed = completedHabits.contains { $0.id == habit.id }
            return "- \(habit.title) (\(habit.durationMinutes)分/\(habit.preferredTimeSlot.shortLabel)) [達成: \(completed ? "済" : "未")] [連続: \(habit.currentStreak)日]"
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

        ## エネルギープロファイル:
        \(energyInfo)

        ## 習慣トラッカー (\(activeHabits.count)件中\(completedHabits.count)件達成):
        \(habitInfo.isEmpty ? "なし" : habitInfo)

        以下の形式でJSON応答してください:
        ```json
        {
            "greeting": "おはようございます、○○さん。今日の報告です。",
            "schedule_summary": "今日のスケジュール概要（移動時間の注意も含めて）",
            "task_summary": "タスク状況の概要（エネルギーレベルに基づく配置提案を含む）",
            "habit_summary": "習慣の達成状況と提案",
            "energy_advice": "エネルギーレベルに基づく今日の過ごし方アドバイス",
            "travel_warnings": ["移動時間に関する注意事項"],
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
        - エネルギーのピーク時間帯に重要タスクを配置する提案をする
        - 移動時間がある場合、出発時刻の注意を含める
        - 習慣の連続達成日数が途切れそうなら注意を促す
        - スケジュールの隙間時間に習慣を入れる提案もする
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
                habitSummary: "",
                energyAdvice: "",
                travelWarnings: [],
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
            habitSummary: json["habit_summary"] as? String ?? "",
            energyAdvice: json["energy_advice"] as? String ?? "",
            travelWarnings: json["travel_warnings"] as? [String] ?? [],
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
    let habitSummary: String
    let energyAdvice: String
    let travelWarnings: [String]
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
