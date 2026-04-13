import Foundation
import SwiftData
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentConversation: Conversation?

    private var apiService: ClaudeAPIService?
    private var modelContext: ModelContext?

    /// リレーサーバー経由（推奨）またはAPI直接接続でセットアップ
    func setup(appState: AppState, modelContext: ModelContext) {
        if appState.isRelayConfigured {
            self.apiService = ClaudeAPIService(
                serverURL: appState.relayServerURL,
                authToken: appState.relayAuthToken
            )
        } else {
            self.apiService = ClaudeAPIService(apiKey: appState.apiKey)
        }
        self.modelContext = modelContext

        if currentConversation == nil {
            let conversation = Conversation()
            modelContext.insert(conversation)
            currentConversation = conversation
        }
    }

    /// 旧互換: apiKeyのみでセットアップ（フォールバック用）
    func setup(apiKey: String, modelContext: ModelContext) {
        self.apiService = ClaudeAPIService(apiKey: apiKey)
        self.modelContext = modelContext

        if currentConversation == nil {
            let conversation = Conversation()
            modelContext.insert(conversation)
            currentConversation = conversation
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let apiService, let modelContext else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        modelContext.insert(userMessage)
        if let conversation = currentConversation {
            userMessage.conversation = conversation
            conversation.messages.append(userMessage)
            conversation.updatedAt = Date()
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let apiMessages = currentConversation?.messages
                .sorted { $0.timestamp < $1.timestamp }
                .filter { $0.role != .system }
                .map { ClaudeAPIService.APIMessage(role: $0.role.rawValue, content: $0.content) }
                ?? [ClaudeAPIService.APIMessage(role: "user", content: text)]

            let response = try await apiService.sendMessage(messages: apiMessages)

            guard !response.isEmpty else {
                print("[AISecretary] 空の応答を受信しました")
                errorMessage = "AIからの応答が空でした。APIキーとネットワーク接続を確認してください。"
                return
            }

            let assistantMessage = ChatMessage(role: .assistant, content: response)
            modelContext.insert(assistantMessage)
            if let conversation = currentConversation {
                assistantMessage.conversation = conversation
                conversation.messages.append(assistantMessage)
                conversation.updatedAt = Date()
                // 最初のメッセージならタイトルを更新
                if conversation.title == "新しい会話" {
                    conversation.title = String(text.prefix(20))
                }
            }

            parseAndExecuteActions(from: response, modelContext: modelContext)

            try? modelContext.save()
        } catch {
            print("[AISecretary] sendMessage エラー: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func sendVoiceMessage(_ transcription: String) async {
        inputText = transcription
        await sendMessage()
    }

    func newConversation() {
        guard let modelContext else { return }
        let conversation = Conversation()
        modelContext.insert(conversation)
        currentConversation = conversation
    }

    private func parseAndExecuteActions(from response: String, modelContext: ModelContext) {
        guard let jsonRange = response.range(of: "```json"),
              let endRange = response.range(of: "```", range: jsonRange.upperBound..<response.endIndex) else {
            return
        }

        let jsonString = String(response[jsonRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else { return }

        switch action {
        case "add_schedule":
            if let title = json["title"] as? String,
               let dateStr = json["date"] as? String,
               let timeStr = json["time"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                if let date = formatter.date(from: "\(dateStr) \(timeStr)") {
                    let duration = json["duration_minutes"] as? Int ?? 60
                    let priorityStr = json["priority"] as? String ?? "normal"
                    let reminderMin = json["reminder_minutes"] as? Int ?? 15
                    let schedule = ScheduleItem(
                        title: title,
                        startDate: date,
                        endDate: date.addingTimeInterval(TimeInterval(duration * 60)),
                        priority: Priority(fromString: priorityStr),
                        reminderMinutesBefore: reminderMin
                    )
                    modelContext.insert(schedule)
                    NotificationService.shared.scheduleReminder(for: schedule)
                }
            }

        case "add_task":
            if let title = json["title"] as? String {
                let detail = json["detail"] as? String ?? ""
                let priorityStr = json["priority"] as? String ?? "normal"
                var dueDate: Date?
                if let dueDateStr = json["due_date"] as? String {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    dueDate = formatter.date(from: dueDateStr)
                }
                let task = TaskItem(
                    title: title,
                    detail: detail,
                    dueDate: dueDate,
                    priority: Priority(fromString: priorityStr)
                )
                modelContext.insert(task)
                NotificationService.shared.scheduleTaskReminder(for: task)
            }

        case "save_memo":
            if let title = json["title"] as? String,
               let content = json["content"] as? String {
                let priorityStr = json["priority"] as? String ?? "normal"
                let memo = Memo(
                    content: content,
                    title: title,
                    priority: Priority(fromString: priorityStr)
                )
                modelContext.insert(memo)
            }

        default:
            break
        }
    }
}
