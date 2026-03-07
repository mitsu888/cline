import Foundation

actor ClaudeAPIService {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    private var apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    struct APIRequest: Encodable {
        let model: String
        let max_tokens: Int
        let system: String?
        let messages: [APIMessage]
    }

    struct APIMessage: Codable {
        let role: String
        let content: String
    }

    struct APIResponse: Decodable {
        let content: [ContentBlock]

        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
    }

    struct APIError: Decodable {
        let error: ErrorDetail
        struct ErrorDetail: Decodable {
            let type: String
            let message: String
        }
    }

    private let systemPrompt = """
    あなたは優秀なAI秘書です。ユーザーの仕事や生活をサポートします。

    ## あなたの役割:
    - スケジュール管理の相談・提案
    - タスクの優先度判断と整理
    - メモの要約・整理
    - 一般的な質問への回答
    - リマインダーの提案

    ## 応答のルール:
    - 日本語で丁寧に、でも簡潔に応答してください
    - スケジュールの相談では具体的な時間の提案をしてください
    - 優先度の判断を求められたら、理由と共に提案してください
    - 「秘書」として主体的に提案・助言をしてください

    ## 構造化データの返答:
    ユーザーがスケジュール追加やタスク作成を依頼した場合、以下のJSON形式で返答の最後に含めてください:

    スケジュール追加:
    ```json
    {"action":"add_schedule","title":"...","date":"YYYY-MM-DD","time":"HH:mm","duration_minutes":60,"priority":"normal","reminder_minutes":15}
    ```

    タスク追加:
    ```json
    {"action":"add_task","title":"...","detail":"...","due_date":"YYYY-MM-DD","priority":"normal"}
    ```

    メモ保存:
    ```json
    {"action":"save_memo","title":"...","content":"...","priority":"normal"}
    ```

    優先度は "low", "normal", "high", "urgent" のいずれかです。
    """

    func sendMessage(messages: [APIMessage]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ClaudeError.noAPIKey
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = APIRequest(
            model: model,
            max_tokens: 2048,
            system: systemPrompt,
            messages: messages
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ClaudeError.apiError(apiError.error.message)
            }
            throw ClaudeError.httpError(httpResponse.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        return apiResponse.content.compactMap(\.text).joined()
    }

    func analyzeVoiceMemo(transcription: String) async throws -> VoiceMemoAnalysis {
        let prompt = """
        以下の音声メモの内容を分析してください:
        「\(transcription)」

        以下のJSON形式で分析結果を返してください:
        ```json
        {
            "summary": "要約",
            "priority": "low/normal/high/urgent",
            "suggested_actions": [
                {"action": "add_schedule/add_task/save_memo", "title": "...", "detail": "..."}
            ]
        }
        ```
        """

        let messages = [APIMessage(role: "user", content: prompt)]
        let response = try await sendMessage(messages: messages)
        return try parseVoiceMemoAnalysis(response)
    }

    private func parseVoiceMemoAnalysis(_ response: String) throws -> VoiceMemoAnalysis {
        guard let jsonRange = response.range(of: "```json"),
              let endRange = response.range(of: "```", range: jsonRange.upperBound..<response.endIndex) else {
            return VoiceMemoAnalysis(
                summary: response,
                priority: .normal,
                suggestedActions: []
            )
        }

        let jsonString = String(response[jsonRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeError.parseError
        }

        let decoded = try JSONDecoder().decode(VoiceMemoAnalysisDTO.self, from: jsonData)
        return VoiceMemoAnalysis(
            summary: decoded.summary,
            priority: Priority(fromString: decoded.priority),
            suggestedActions: decoded.suggested_actions.map { action in
                SuggestedAction(action: action.action, title: action.title, detail: action.detail ?? "")
            }
        )
    }
}

enum ClaudeError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "APIキーが設定されていません"
        case .invalidResponse: "無効なレスポンスです"
        case .httpError(let code): "HTTP エラー: \(code)"
        case .apiError(let msg): "API エラー: \(msg)"
        case .parseError: "レスポンスの解析に失敗しました"
        }
    }
}

struct VoiceMemoAnalysis {
    let summary: String
    let priority: Priority
    let suggestedActions: [SuggestedAction]
}

struct SuggestedAction {
    let action: String
    let title: String
    let detail: String
}

struct VoiceMemoAnalysisDTO: Decodable {
    let summary: String
    let priority: String
    let suggested_actions: [SuggestedActionDTO]

    struct SuggestedActionDTO: Decodable {
        let action: String
        let title: String
        let detail: String?
    }
}

extension Priority {
    init(fromString string: String) {
        switch string.lowercased() {
        case "low": self = .low
        case "high": self = .high
        case "urgent": self = .urgent
        default: self = .normal
        }
    }
}
