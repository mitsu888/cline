import Foundation
import SwiftData

/// 「断る」提案サービス
/// 過負荷時に予定やタスクを断る・延期する提案を生成し、メッセージの下書きも作成
@MainActor
final class DeclineSuggestionService: ObservableObject {
    @Published var suggestions: [DeclineSuggestion] = []
    @Published var isGenerating = false

    private var apiService: ClaudeAPIService?

    func setup(apiKey: String) {
        self.apiService = ClaudeAPIService(apiKey: apiKey)
    }

    /// 過負荷時の「断る」提案を生成
    func generateDeclineSuggestions(
        schedules: [ScheduleItem],
        tasks: [TaskItem],
        energyProfile: EnergyProfile?
    ) async throws {
        guard let apiService else { throw ClaudeError.noAPIKey }

        isGenerating = true
        defer { isGenerating = false }

        let todaySchedules = schedules.filter { $0.startDate.isToday }
        let pendingTasks = tasks.filter { !$0.isCompleted }
        let totalItems = todaySchedules.count + pendingTasks.filter { $0.dueDate?.isToday == true }.count

        // 負荷がそれほど高くなければ提案不要
        guard totalItems > 6 else {
            suggestions = []
            return
        }

        let scheduleInfo = todaySchedules.map {
            "- \($0.startDate.shortTimeString) \($0.title) [優先度:\($0.priority.label)] [場所:\($0.location.isEmpty ? "なし" : $0.location)]"
        }.joined(separator: "\n")

        let taskInfo = pendingTasks
            .filter { $0.dueDate?.isToday == true }
            .map {
                "- \($0.title) [優先度:\($0.priority.label)]"
            }.joined(separator: "\n")

        let energyInfo: String
        if let profile = energyProfile {
            energyInfo = "ユーザーは\(profile.chronotype.label)です。ピーク時間帯: \(profile.peakHours.map { "\($0)時" }.joined(separator: ", "))"
        } else {
            energyInfo = "エネルギー情報なし"
        }

        let prompt = """
        秘書として、ユーザーの今日のスケジュールとタスクを分析し、負荷が高すぎる場合に「断る・延期すべき」項目を提案してください。

        ## 今日のスケジュール (\(todaySchedules.count)件):
        \(scheduleInfo.isEmpty ? "なし" : scheduleInfo)

        ## 今日期限のタスク (\(pendingTasks.filter { $0.dueDate?.isToday == true }.count)件):
        \(taskInfo.isEmpty ? "なし" : taskInfo)

        ## エネルギー情報:
        \(energyInfo)

        以下のJSON形式で応答してください:
        ```json
        {
            "suggestions": [
                {
                    "target_title": "予定/タスク名",
                    "type": "decline/postpone/delegate/shorten",
                    "reason": "理由",
                    "draft_message": "断り/延期のメッセージ下書き（相手に送る丁寧なメッセージ）",
                    "alternative": "代替案（あれば）"
                }
            ],
            "overall_advice": "全体的なアドバイス"
        }
        ```

        ルール:
        - 優先度が低いもの、延期可能なものを優先的に提案
        - 断りのメッセージは丁寧でプロフェッショナルに
        - 「type」は decline(断る), postpone(延期), delegate(委任), shorten(短縮) のいずれか
        - エネルギーレベルを考慮して、ピーク時間帯の重要な予定は残す
        """

        let messages = [ClaudeAPIService.APIMessage(role: "user", content: prompt)]
        let response = try await apiService.sendMessage(messages: messages)
        self.suggestions = parseSuggestions(response)
    }

    private func parseSuggestions(_ response: String) -> [DeclineSuggestion] {
        guard let jsonRange = response.range(of: "```json"),
              let endRange = response.range(of: "```", range: jsonRange.upperBound..<response.endIndex),
              let data = String(response[jsonRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let suggestionsArray = json["suggestions"] as? [[String: Any]] else {
            return []
        }

        return suggestionsArray.compactMap { dict in
            guard let title = dict["target_title"] as? String,
                  let typeStr = dict["type"] as? String,
                  let reason = dict["reason"] as? String else { return nil }

            return DeclineSuggestion(
                targetTitle: title,
                type: DeclineType(rawValue: typeStr) ?? .postpone,
                reason: reason,
                draftMessage: dict["draft_message"] as? String ?? "",
                alternative: dict["alternative"] as? String ?? ""
            )
        }
    }
}

/// 「断る」提案
struct DeclineSuggestion: Identifiable {
    let id = UUID()
    let targetTitle: String
    let type: DeclineType
    let reason: String
    let draftMessage: String
    let alternative: String
}

/// 断り方のタイプ
enum DeclineType: String, Codable {
    case decline = "decline"
    case postpone = "postpone"
    case delegate = "delegate"
    case shorten = "shorten"

    var label: String {
        switch self {
        case .decline: "断る"
        case .postpone: "延期する"
        case .delegate: "委任する"
        case .shorten: "短縮する"
        }
    }

    var icon: String {
        switch self {
        case .decline: "xmark.circle.fill"
        case .postpone: "clock.arrow.circlepath"
        case .delegate: "person.2.fill"
        case .shorten: "arrow.down.left.and.arrow.up.right"
        }
    }

    var color: String {
        switch self {
        case .decline: "red"
        case .postpone: "orange"
        case .delegate: "blue"
        case .shorten: "purple"
        }
    }
}
