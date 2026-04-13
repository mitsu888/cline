import SwiftUI
import SwiftData

/// AI秘書 - iOS & macOS対応のAIアシスタントアプリ
/// Claude APIを使用した音声メモ、チャット、スケジュール管理、通知機能を提供
/// iCloud同期対応 - CloudKit経由で全デバイス間でデータ同期
@main
struct AISecretaryApp: App {
    @StateObject private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
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
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer作成に失敗: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(sharedModelContainer)
                .onAppear {
                    setupEveningReminder()
                    setupManagerNotifications()
                }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)
        #endif
    }

    private func setupManagerNotifications() {
        guard appState.managerModeEnabled else { return }

        let context = sharedModelContainer.mainContext
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = #Predicate<ScheduleItem> {
            $0.startDate >= today && $0.startDate < tomorrow
        }

        guard let schedules = try? context.fetch(
            FetchDescriptor<ScheduleItem>(predicate: predicate, sortBy: [SortDescriptor(\.startDate)])
        ) else { return }

        let managerService = ManagerNotificationService()
        Task { @MainActor in
            managerService.setupAlertsForTodaySchedules(
                schedules: schedules,
                prepTimeMinutes: appState.prepTimeMinutes
            )
        }
    }

    private func setupEveningReminder() {
        guard appState.eveningReminderEnabled else { return }

        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = appState.eveningReminderHour
        components.minute = 0

        if let reminderDate = calendar.date(from: components), reminderDate > now {
            NotificationService.shared.scheduleNotification(
                id: "evening-reflection",
                title: "今日の振り返りの時間です",
                body: "1日の感動や学びを記録しましょう。",
                date: reminderDate
            )
        }
    }
}
