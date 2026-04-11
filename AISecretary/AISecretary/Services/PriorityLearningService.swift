import Foundation
import SwiftData
import Combine

/// 自動優先度学習サービス
/// ユーザーのタスク完了パターンを分析し、新しいタスクの優先度を提案
final class PriorityLearningService: ObservableObject {
    @Published var isLearningEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLearningEnabled, forKey: "priority_learning_enabled")
        }
    }
    @Published var totalRecords: Int = 0

    init() {
        self.isLearningEnabled = UserDefaults.standard.object(forKey: "priority_learning_enabled") as? Bool ?? true
    }

    // MARK: - 学習データ記録

    /// タスク完了時に学習データを記録
    func recordTaskCompletion(task: TaskItem, context: ModelContext) {
        guard isLearningEnabled else { return }

        let calendar = Calendar.current
        let keywords = extractKeywords(from: task.title)

        let completionTime: Double?
        if let completedAt = task.completedAt {
            completionTime = completedAt.timeIntervalSince(task.createdAt) / 3600.0
        } else {
            completionTime = nil
        }

        for keyword in keywords {
            let record = PriorityLearningRecord(
                keyword: keyword,
                assignedPriority: task.priority,
                wasCompleted: task.isCompleted,
                completionTimeHours: completionTime,
                dayOfWeek: calendar.component(.weekday, from: task.createdAt),
                hourCreated: calendar.component(.hour, from: task.createdAt)
            )
            context.insert(record)
        }
    }

    // MARK: - 優先度提案

    /// タスク名から優先度を提案
    func suggestPriority(for title: String, context: ModelContext) -> PrioritySuggestion? {
        guard isLearningEnabled, !title.isEmpty else { return nil }

        let keywords = extractKeywords(from: title)
        guard !keywords.isEmpty else { return nil }

        // キーワードマッチングで過去の記録を検索
        let allRecords = fetchRecords(context: context)
        guard !allRecords.isEmpty else { return nil }

        var matchedRecords: [PriorityLearningRecord] = []
        for record in allRecords {
            if keywords.contains(record.keyword) {
                matchedRecords.append(record)
            }
        }

        guard matchedRecords.count >= 2 else { return nil }

        // 優先度の加重平均を計算（新しい記録ほど重み大）
        let now = Date()
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        for record in matchedRecords {
            let daysSinceRecord = now.timeIntervalSince(record.createdAt) / 86400.0
            let weight = max(0.1, 1.0 - (daysSinceRecord / 90.0)) // 90日で減衰
            weightedSum += Double(record.assignedPriority) * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }

        let averagePriority = weightedSum / totalWeight
        let suggestedRaw = Int(averagePriority.rounded())
        let clampedRaw = max(0, min(3, suggestedRaw))

        guard let suggested = Priority(rawValue: clampedRaw) else { return nil }

        // 信頼度を計算（マッチ数と一貫性に基づく）
        let consistency = calculateConsistency(records: matchedRecords)
        let countFactor = min(1.0, Double(matchedRecords.count) / 10.0)
        let confidence = (consistency + countFactor) / 2.0

        // 時間帯パターンも考慮
        let timeBoost = timeBasedBoost(records: matchedRecords)

        return PrioritySuggestion(
            priority: suggested,
            confidence: min(1.0, confidence + timeBoost),
            reason: generateReason(
                keyword: keywords.first ?? title,
                matchCount: matchedRecords.count,
                suggested: suggested
            )
        )
    }

    // MARK: - 統計情報

    /// 学習統計を取得
    func getStatistics(context: ModelContext) -> LearningStatistics {
        let records = fetchRecords(context: context)
        totalRecords = records.count

        guard !records.isEmpty else {
            return LearningStatistics(totalRecords: 0, topKeywords: [], accuracyRate: 0)
        }

        // キーワード頻度
        var keywordCounts: [String: Int] = [:]
        for record in records {
            keywordCounts[record.keyword, default: 0] += 1
        }
        let topKeywords = keywordCounts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { KeywordStat(keyword: $0.key, count: $0.value) }

        // 完了率
        let completedCount = records.filter { $0.wasCompleted }.count
        let accuracyRate = Double(completedCount) / Double(records.count)

        return LearningStatistics(
            totalRecords: records.count,
            topKeywords: Array(topKeywords),
            accuracyRate: accuracyRate
        )
    }

    /// 学習データをリセット
    func resetLearningData(context: ModelContext) {
        let records = fetchRecords(context: context)
        for record in records {
            context.delete(record)
        }
        totalRecords = 0
    }

    // MARK: - Private

    private func fetchRecords(context: ModelContext) -> [PriorityLearningRecord] {
        let descriptor = FetchDescriptor<PriorityLearningRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func extractKeywords(from title: String) -> [String] {
        let stopWords: Set<String> = ["の", "を", "に", "が", "は", "で", "と", "も", "から", "まで",
                                       "する", "した", "して", "a", "the", "to", "for", "and", "or"]
        return title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted.union(.whitespaces))
            .filter { $0.count >= 2 && !stopWords.contains($0) }
    }

    private func calculateConsistency(records: [PriorityLearningRecord]) -> Double {
        guard records.count >= 2 else { return 0.5 }
        let priorities = records.map { Double($0.assignedPriority) }
        let mean = priorities.reduce(0, +) / Double(priorities.count)
        let variance = priorities.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(priorities.count)
        // 分散が小さいほど一貫性が高い (最大分散は約2.25)
        return max(0, 1.0 - (variance / 2.25))
    }

    private func timeBasedBoost(records: [PriorityLearningRecord]) -> Double {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        let currentDayOfWeek = calendar.component(.weekday, from: Date())

        let timeMatches = records.filter { record in
            abs(record.hourCreated - currentHour) <= 2 || record.dayOfWeek == currentDayOfWeek
        }

        return timeMatches.isEmpty ? 0 : min(0.15, Double(timeMatches.count) / Double(records.count) * 0.15)
    }

    private func generateReason(keyword: String, matchCount: Int, suggested: Priority) -> String {
        if matchCount >= 5 {
            return "「\(keyword)」関連のタスクは過去に\(matchCount)回\(suggested.label)で処理されています"
        } else {
            return "過去のパターンから\(suggested.label)を提案します"
        }
    }
}

// MARK: - Data Types

struct PrioritySuggestion {
    let priority: Priority
    let confidence: Double  // 0.0 ~ 1.0
    let reason: String

    var confidenceLabel: String {
        switch confidence {
        case 0.8...: "高い確信度"
        case 0.5..<0.8: "中程度の確信度"
        default: "参考情報"
        }
    }
}

struct LearningStatistics {
    let totalRecords: Int
    let topKeywords: [KeywordStat]
    let accuracyRate: Double

    var accuracyPercentage: String {
        "\(Int(accuracyRate * 100))%"
    }
}

struct KeywordStat: Identifiable {
    var id: String { keyword }
    let keyword: String
    let count: Int
}
