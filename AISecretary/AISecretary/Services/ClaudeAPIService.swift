import Foundation

/// ClaudeAPIService - リレーサーバー経由でClaude APIと通信
/// APIキーはサーバー側で管理されるため、クライアントには不要
actor ClaudeAPIService {
    private var serverURL: String
    private var authToken: String

    init(serverURL: String, authToken: String) {
        self.serverURL = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        self.authToken = authToken
    }

    /// サーバーURLを更新（設定変更時）
    func updateServerURL(_ url: String) {
        self.serverURL = url.hasSuffix("/") ? String(url.dropLast()) : url
    }

    /// 認証トークンを更新
    func updateAuthToken(_ token: String) {
        self.authToken = token
    }

    // --- 旧API直接呼び出し用（フォールバック） ---
    private var legacyAPIKey: String?

    init(apiKey: String) {
        self.serverURL = ""
        self.authToken = ""
        self.legacyAPIKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.legacyAPIKey = key
    }

    struct APIMessage: Codable {
        let role: String
        let content: String
    }

    /// リレーサーバーへのリクエスト
    struct RelayRequest: Encodable {
        let messages: [APIMessage]
        let system: String?
        let max_tokens: Int?
    }

    /// リレーサーバーからのレスポンス
    struct RelayResponse: Decodable {
        let text: String
        let usage: Usage?

        struct Usage: Decodable {
            let input_tokens: Int?
            let output_tokens: Int?
        }
    }

    /// リレーサーバーからのエラーレスポンス
    struct RelayErrorResponse: Decodable {
        let error: String
    }

    // --- 旧API直接呼び出し用の型（フォールバック） ---
    struct LegacyAPIRequest: Encodable {
        let model: String
        let max_tokens: Int
        let system: String?
        let messages: [APIMessage]
    }

    struct LegacyAPIResponse: Decodable {
        let content: [ContentBlock]
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
    }

    struct LegacyAPIError: Decodable {
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

    /// リレーサーバー経由でメッセージを送信（推奨）
    /// サーバーが未設定の場合は旧API直接呼び出しにフォールバック
    func sendMessage(messages: [APIMessage]) async throws -> String {
        // リレーサーバーが設定されている場合
        if !serverURL.isEmpty && !authToken.isEmpty {
            return try await sendViaRelay(messages: messages)
        }

        // フォールバック: 旧API直接呼び出し
        if let apiKey = legacyAPIKey, !apiKey.isEmpty {
            return try await sendDirectly(messages: messages, apiKey: apiKey)
        }

        throw ClaudeError.noAPIKey
    }

    /// リレーサーバー経由の送信
    private func sendViaRelay(messages: [APIMessage]) async throws -> String {
        guard let url = URL(string: "\(serverURL)/api/chat") else {
            throw ClaudeError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let body = RelayRequest(
            messages: messages,
            system: systemPrompt,
            max_tokens: 2048
        )
        request.httpBody = try JSONEncoder().encode(body)

        print("[AISecretary] リレーサーバー経由でAPI呼び出し: \(serverURL)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[AISecretary] ネットワークエラー: \(error.localizedDescription)")
            throw ClaudeError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        print("[AISecretary] リレー HTTPステータス: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 {
            throw ClaudeError.apiError("認証エラー: サーバーの認証トークンを確認してください")
        }

        if httpResponse.statusCode != 200 {
            if let errorResp = try? JSONDecoder().decode(RelayErrorResponse.self, from: data) {
                throw ClaudeError.apiError(errorResp.error)
            }
            throw ClaudeError.httpError(httpResponse.statusCode)
        }

        let relayResponse: RelayResponse
        do {
            relayResponse = try JSONDecoder().decode(RelayResponse.self, from: data)
        } catch {
            throw ClaudeError.parseError
        }

        if relayResponse.text.isEmpty {
            print("[AISecretary] 警告: リレーレスポンスのテキストが空です")
        } else {
            print("[AISecretary] リレー応答受信: \(relayResponse.text.prefix(100))...")
        }
        return relayResponse.text
    }

    /// 旧API直接呼び出し（フォールバック用）
    private func sendDirectly(messages: [APIMessage], apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ClaudeError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let body = LegacyAPIRequest(
            model: "claude-sonnet-4-20250514",
            max_tokens: 2048,
            system: systemPrompt,
            messages: messages
        )
        request.httpBody = try JSONEncoder().encode(body)

        print("[AISecretary] API直接呼び出し（フォールバック）")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let apiError = try? JSONDecoder().decode(LegacyAPIError.self, from: data) {
                throw ClaudeError.apiError(apiError.error.message)
            }
            throw ClaudeError.httpError(httpResponse.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(LegacyAPIResponse.self, from: data)
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
