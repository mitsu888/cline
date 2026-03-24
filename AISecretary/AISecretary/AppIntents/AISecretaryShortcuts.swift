import AppIntents

/// Siriショートカットで利用できるフレーズを登録
struct AISecretaryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DailyBriefingIntent(),
            phrases: [
                "今日のブリーフィング \(.applicationName)",
                "\(.applicationName) で今日の報告",
                "\(.applicationName) の朝の報告",
                "\(.applicationName) で今日のまとめ",
            ],
            shortTitle: "今日のブリーフィング",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: TodayScheduleIntent(),
            phrases: [
                "今日の予定 \(.applicationName)",
                "\(.applicationName) で今日のスケジュール",
                "\(.applicationName) の予定を教えて",
            ],
            shortTitle: "今日の予定",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: AddVoiceMemoIntent(),
            phrases: [
                "\(.applicationName) にメモ",
                "\(.applicationName) でメモを追加",
            ],
            shortTitle: "メモを追加",
            systemImageName: "note.text"
        )
    }
}
