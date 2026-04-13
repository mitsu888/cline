import Foundation
import SwiftData

/// 1日の振り返りメモサービス
/// 感動や学びを音声・テキストで記録し、AIが分析・要約する
@MainActor
final class ReflectionService: ObservableObject {
    @Published var isAnalyzing = false

    private var apiService: ClaudeAPIService?

    func setup(appState: AppState) {
        if appState.isRelayConfigured {
            self.apiService = ClaudeAPIService(serverURL: appState.relayServerURL, authToken: appState.relayAuthToken)
        } else {
            self.apiService = ClaudeAPIService(apiKey: appState.apiKey)
        }
    }

    func setup(apiKey: String) {
        self.apiService = ClaudeAPIService(apiKey: apiKey)
    }

    /// 振り返りメモをAIで分析
    func analyzeReflection(
        content: String,
        todaySchedules: [ScheduleItem],
        completedTasks: [TaskItem],
        habitLogs: [HabitLog]
    ) async throws -> ReflectionAnalysis {
        guard let apiService else { throw ClaudeError.noAPIKey }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let completedSchedules = todaySchedules.filter { $0.isCompleted }.count
        let completedTaskList = completedTasks.map { "- \($0.title)" }.joined(separator: "\n")
        let habitCompletions = habitLogs.filter { $0.isCompleted }.count
        let totalHabits = habitLogs.count

        let prompt = """
        秘書として、ユーザーの1日の振り返りメモを分析してください。

        ## ユーザーの振り返り:
        「\(content)」

        ## 今日の実績:
        - 予定: \(completedSchedules)/\(todaySchedules.count)件 完了
        - タスク完了: \(completedTasks.count)件
        \(completedTaskList.isEmpty ? "" : completedTaskList)
        - 習慣: \(habitCompletions)/\(totalHabits)件 達成

        以下のJSON形式で分析結果を返してください:
        ```json
        {
            "summary": "今日の振り返りの要約（2-3文）",
            "detected_emotion": "veryHappy/happy/neutral/tired/stressed",
            "impression_level": 1-5,
            "learnings": ["学んだこと1", "学んだこと2"],
            "gratitudes": ["感謝すること1"],
            "tags": ["タグ1", "タグ2"],
            "encouragement": "明日に向けた励ましの一言",
            "weekly_insight": "今週の傾向から見えるアドバイス（あれば）"
        }
        ```

        ルール:
        - ユーザーの言葉から感情を正確に読み取る
        - 「感動」「嬉しい」「やった」→ veryHappy/happy
        - 「疲れた」「大変だった」→ tired
        - 学びや感謝を具体的に抽出する
        - 励ましは温かく、翌日のモチベーションにつながるように
        """

        let messages = [ClaudeAPIService.APIMessage(role: "user", content: prompt)]
        let response = try await apiService.sendMessage(messages: messages)
        return parseAnalysis(response)
    }

    private func parseAnalysis(_ response: String) -> ReflectionAnalysis {
        guard let jsonRange = response.range(of: "```json"),
              let endRange = response.range(of: "```", range: jsonRange.upperBound..<response.endIndex),
              let data = String(response[jsonRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ReflectionAnalysis(
                summary: response,
                detectedEmotion: .neutral,
                impressionLevel: 3,
                learnings: [],
                gratitudes: [],
                tags: [],
                encouragement: "",
                weeklyInsight: nil
            )
        }

        let emotionStr = json["detected_emotion"] as? String ?? "neutral"
        let emotion: Emotion
        switch emotionStr {
        case "veryHappy": emotion = .veryHappy
        case "happy": emotion = .happy
        case "tired": emotion = .tired
        case "stressed": emotion = .stressed
        default: emotion = .neutral
        }

        return ReflectionAnalysis(
            summary: json["summary"] as? String ?? "",
            detectedEmotion: emotion,
            impressionLevel: json["impression_level"] as? Int ?? 3,
            learnings: json["learnings"] as? [String] ?? [],
            gratitudes: json["gratitudes"] as? [String] ?? [],
            tags: json["tags"] as? [String] ?? [],
            encouragement: json["encouragement"] as? String ?? "",
            weeklyInsight: json["weekly_insight"] as? String
        )
    }
}

/// 振り返り分析結果
struct ReflectionAnalysis {
    let summary: String
    let detectedEmotion: Emotion
    let impressionLevel: Int
    let learnings: [String]
    let gratitudes: [String]
    let tags: [String]
    let encouragement: String
    let weeklyInsight: String?
}
