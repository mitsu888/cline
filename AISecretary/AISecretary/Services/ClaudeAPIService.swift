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
            print("[AISecretary] エラー: APIキーが空です")
            throw ClaudeError.noAPIKey
        }

        guard let url = URL(string: baseURL) else {
            print("[AISecretary] エラー: 無効なURL")
            throw ClaudeError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let body = APIRequest(
            model: model,
            max_tokens: 2048,
            system: systemPrompt,
            messages: messages
        )
        request.httpBody = try JSONEncoder().encode(body)

        print("[AISecretary] API呼び出し開始: モデル=\(model), メッセージ数=\(messages.count)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[AISecretary] ネットワークエラー: \(error.localizedDescription)")
            throw ClaudeError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[AISecretary] エラー: HTTPレスポンスではありません")
            throw ClaudeError.invalidResponse
        }

        print("[AISecretary] HTTPステータス: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "(読み取り不可)"
            print("[AISecretary] APIエラーレスポンス: \(responseBody)")
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ClaudeError.apiError(apiError.error.message)
            }
            throw ClaudeError.httpError(httpResponse.statusCode)
        }

        let apiResponse: APIResponse
        do {
            apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "(読み取り不可)"
            print("[AISecretary] JSONデコードエラー: \(error), レスポンス: \(responseBody)")
            throw ClaudeError.parseError
        }

        let result = apiResponse.content.compactMap(\.text).joined()
        if result.isEmpty {
            print("[AISecretary] 警告: APIレスポンスのテキストが空です")
            let responseBody = String(data: data, encoding: .utf8) ?? "(読み取り不可)"
            print("[AISecretary] 生レスポンス: \(responseBody)")
        } else {
            print("[AISecretary] 応答受信: \(result.prefix(100))...")
        }
        return result
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

    /// ボイスメモから「約束」（スケジュール候補）を自動抽出
    func extractPromises(transcription: String) async throws -> [PromiseCandidate] {
        let today = DateFormatters.isoDateFormatter.string(from: Date())
        let prompt = """
        以下の音声メモから、約束・予定・スケジュールに関する情報を抽出してください。
        今日の日付: \(today)

        音声メモ:
        「\(transcription)」

        以下の形式でJSON応答してください。約束が見つからない場合は空配列を返してください:
        ```json
        {
            "promises": [
                {
                    "title": "予定のタイトル",
                    "person": "相手の名前（不明なら空文字）",
                    "date": "YYYY-MM-DD（推測含む。「来週の水曜」等は具体的な日付に変換）",
                    "time": "HH:mm（不明なら空文字）",
                    "duration_minutes": 60,
                    "location": "場所（不明なら空文字）",
                    "detail": "詳細メモ",
                    "confidence": 0.9
                }
            ]
        }
        ```

        重要なルール:
        - 「来週の水曜」「明後日」「今度の金曜」等の相対日付は、今日(\(today))を基準に具体的な日付に変換する
        - 「ランチ」→12:00、「夕食」「ディナー」→19:00、「朝」→9:00 等、時間が明示されていなくても推測する
        - confidence は抽出の確信度（0.0〜1.0）。明確な約束は0.8以上、推測が多い場合は低く設定
        - 人名、場所、日時のいずれかが含まれていれば約束候補として抽出する
        """

        let messages = [APIMessage(role: "user", content: prompt)]
        let response = try await sendMessage(messages: messages)
        return try parsePromises(response)
    }

    private func parsePromises(_ response: String) throws -> [PromiseCandidate] {
        guard let jsonRange = response.range(of: "```json"),
              let endRange = response.range(of: "```", range: jsonRange.upperBound..<response.endIndex) else {
            return []
        }

        let jsonString = String(response[jsonRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = jsonString.data(using: .utf8) else {
            return []
        }

        let decoded = try JSONDecoder().decode(PromisesDTO.self, from: jsonData)
        let calendar = Calendar.current

        return decoded.promises.compactMap { dto in
            let dateFormatter = DateFormatters.isoDateFormatter
            guard let date = dateFormatter.date(from: dto.date) else { return nil }

            var startDate = date
            if !dto.time.isEmpty {
                let parts = dto.time.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 {
                    startDate = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date) ?? date
                }
            }

            return PromiseCandidate(
                title: dto.title,
                person: dto.person,
                startDate: startDate,
                durationMinutes: dto.duration_minutes,
                location: dto.location,
                detail: dto.detail,
                confidence: dto.confidence
            )
        }
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
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "APIキーが設定されていません。設定画面でAPIキーを入力してください。"
        case .invalidResponse: "無効なレスポンスです"
        case .httpError(let code): "HTTP エラー: \(code). APIキーやネットワーク設定を確認してください。"
        case .apiError(let msg): "API エラー: \(msg)"
        case .parseError: "レスポンスの解析に失敗しました"
        case .networkError(let msg): "ネットワークエラー: \(msg). インターネット接続を確認してください。macOSの場合、Xcodeの「Signing & Capabilities」で「Outgoing Connections (Client)」を有効にしてください。"
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

struct PromiseCandidate: Identifiable {
    let id = UUID()
    let title: String
    let person: String
    let startDate: Date
    let durationMinutes: Int
    let location: String
    let detail: String
    let confidence: Double

    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    var confidenceLabel: String {
        if confidence >= 0.8 { return "高確度" }
        if confidence >= 0.5 { return "推測あり" }
        return "低確度"
    }
}

struct PromisesDTO: Decodable {
    let promises: [PromiseDTO]
}

struct PromiseDTO: Decodable {
    let title: String
    let person: String
    let date: String
    let time: String
    let duration_minutes: Int
    let location: String
    let detail: String
    let confidence: Double
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
