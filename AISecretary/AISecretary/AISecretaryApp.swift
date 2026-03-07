import SwiftUI
import SwiftData

/// AI秘書 - iOS & macOS対応のAIアシスタントアプリ
/// Claude APIを使用した音声メモ、チャット、スケジュール管理、通知機能を提供
@main
struct AISecretaryApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(for: [
                    Memo.self,
                    ScheduleItem.self,
                    TaskItem.self,
                    ChatMessage.self,
                    Conversation.self
                ])
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
        #endif
    }
}
