import AppIntents
import SwiftData

/// AppIntents用の共有ModelContainer
enum AppIntentModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            Memo.self,
            ScheduleItem.self,
            TaskItem.self,
            ChatMessage.self,
            Conversation.self,
            HabitItem.self,
            HabitLog.self,
            DailyReflection.self,
            PriorityLearningRecord.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }()
}

/// 「Hey Siri、今日のブリーフィング」でAI秘書の朝の報告を取得するショートカット
struct DailyBriefingIntent: AppIntent {
    static var title: LocalizedStringResource = "今日のブリーフィング"
    static var description = IntentDescription(
        "AI秘書から今日のスケジュールとタスクの報告を受け取ります",
        categoryName: "AI秘書"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let apiKey = KeychainHelper.load(key: "claude_api_key") ?? ""
        guard !apiKey.isEmpty else {
            return .result(dialog: "APIキーが設定されていません。AI秘書アプリを開いて設定してください。")
        }

        let container = AppIntentModelContainer.shared
        let context = ModelContext(container)

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 2, to: today)!

        let schedulePredicate = #Predicate<ScheduleItem> { $0.startDate >= today && $0.startDate < tomorrow }
        let scheduleDescriptor = FetchDescriptor<ScheduleItem>(predicate: schedulePredicate, sortBy: [SortDescriptor(\.startDate)])
        let schedules = (try? context.fetch(scheduleDescriptor)) ?? []

        let taskDescriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isCompleted }, sortBy: [SortDescriptor(\.createdAt)])
        let tasks = (try? context.fetch(taskDescriptor)) ?? []

        let briefingService = DailyBriefingService()
        await briefingService.setup(apiKey: apiKey)

        let habitDescriptor = FetchDescriptor<HabitItem>(sortBy: [SortDescriptor(\.createdAt)])
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        let habitLogDescriptor = FetchDescriptor<HabitLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let habitLogs = (try? context.fetch(habitLogDescriptor)) ?? []

        let userName = UserDefaults.standard.string(forKey: "user_name") ?? ""

        do {
            let briefing = try await briefingService.generateDailyBriefing(
                schedules: schedules,
                tasks: tasks,
                habits: habits,
                habitLogs: habitLogs,
                energyProfile: nil,
                travelTimes: [:],
                userName: userName
            )

            let spokenText = buildSpokenBriefing(briefing)
            return .result(dialog: IntentDialog(stringLiteral: spokenText))
        } catch {
            return .result(dialog: "ブリーフィングの生成に失敗しました。ネットワーク接続を確認してください。")
        }
    }

    private func buildSpokenBriefing(_ briefing: DailyBriefing) -> String {
        var parts: [String] = []

        parts.append(briefing.greeting)

        if !briefing.scheduleSummary.isEmpty {
            parts.append(briefing.scheduleSummary)
        }

        if !briefing.taskSummary.isEmpty {
            parts.append(briefing.taskSummary)
        }

        if !briefing.travelWarnings.isEmpty {
            parts.append("移動時間の注意: " + briefing.travelWarnings.joined(separator: "。"))
        }

        if briefing.overloadDetected {
            parts.append("本日はタスクが多めです。優先度の低いものは後回しにすることをお勧めします。")
        }

        if !briefing.motivationalNote.isEmpty {
            parts.append(briefing.motivationalNote)
        }

        return parts.joined(separator: "\n")
    }
}

/// 今日のスケジュールだけを簡潔に読み上げるショートカット
struct TodayScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "今日の予定"
    static var description = IntentDescription(
        "今日のスケジュール一覧を読み上げます",
        categoryName: "AI秘書"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = AppIntentModelContainer.shared
        let context = ModelContext(container)

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = #Predicate<ScheduleItem> { $0.startDate >= today && $0.startDate < tomorrow }
        let descriptor = FetchDescriptor<ScheduleItem>(predicate: predicate, sortBy: [SortDescriptor(\.startDate)])

        let schedules = (try? context.fetch(descriptor)) ?? []

        if schedules.isEmpty {
            return .result(dialog: "今日の予定はありません。ゆっくり過ごしましょう。")
        }

        let list = schedules.map { schedule in
            var text = "\(schedule.startDate.shortTimeString) \(schedule.title)"
            if !schedule.location.isEmpty {
                text += "、場所は\(schedule.location)"
            }
            return text
        }.joined(separator: "。")

        return .result(dialog: IntentDialog(stringLiteral: "今日の予定は\(schedules.count)件です。\(list)。"))
    }
}

/// ボイスメモを追加するショートカット
struct AddVoiceMemoIntent: AppIntent {
    static var title: LocalizedStringResource = "メモを追加"
    static var description = IntentDescription(
        "AI秘書にメモを追加します",
        categoryName: "AI秘書"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "メモの内容")
    var content: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = AppIntentModelContainer.shared
        let context = ModelContext(container)

        let memo = Memo(content: content, isVoiceMemo: false)
        context.insert(memo)
        try context.save()

        return .result(dialog: IntentDialog(stringLiteral: "メモを保存しました: \(content.prefix(30))"))
    }
}
