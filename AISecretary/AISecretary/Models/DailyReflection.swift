import Foundation
import SwiftData

/// 1日の終わりの振り返り・感動メモ
/// 声やチャットで記録し、感情や学びを保存する
@Model
final class DailyReflection {
    var id: UUID
    var date: Date
    /// テキスト内容
    var content: String
    /// AIによる要約
    var aiSummary: String
    /// 感情タグ
    var emotion: Emotion
    /// 感動度（1-5）
    var impressionLevel: Int
    /// 学んだこと
    var learnings: [String]
    /// 感謝すること
    var gratitudes: [String]
    /// 音声メモかどうか
    var isVoiceMemo: Bool
    /// 音声ファイルパス
    var audioFilePath: String?
    /// タグ
    var tags: [String]
    /// 作成日時
    var createdAt: Date

    init(
        content: String,
        emotion: Emotion = .neutral,
        impressionLevel: Int = 3,
        isVoiceMemo: Bool = false,
        audioFilePath: String? = nil
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: Date())
        self.content = content
        self.aiSummary = ""
        self.emotion = emotion
        self.impressionLevel = impressionLevel
        self.learnings = []
        self.gratitudes = []
        self.isVoiceMemo = isVoiceMemo
        self.audioFilePath = audioFilePath
        self.tags = []
        self.createdAt = Date()
    }
}

/// 感情タイプ
enum Emotion: Int, Codable, CaseIterable {
    case veryHappy = 4
    case happy = 3
    case neutral = 2
    case tired = 1
    case stressed = 0

    var label: String {
        switch self {
        case .veryHappy: "感動・最高"
        case .happy: "良い"
        case .neutral: "普通"
        case .tired: "疲れた"
        case .stressed: "ストレス"
        }
    }

    var emoji: String {
        switch self {
        case .veryHappy: "✨"
        case .happy: "😊"
        case .neutral: "😐"
        case .tired: "😴"
        case .stressed: "😰"
        }
    }

    var icon: String {
        switch self {
        case .veryHappy: "star.fill"
        case .happy: "face.smiling"
        case .neutral: "face.dashed"
        case .tired: "zzz"
        case .stressed: "bolt.heart"
        }
    }
}
