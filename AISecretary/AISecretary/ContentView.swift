import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .chat
    @State private var showDailyBriefing = false

    var body: some View {
        ZStack {
            #if os(iOS)
            TabView(selection: $selectedTab) {
                ChatView()
                    .tabItem {
                        Label("秘書", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .tag(AppTab.chat)

                MemoListView()
                    .tabItem {
                        Label("メモ", systemImage: "note.text")
                    }
                    .tag(AppTab.memo)

                ScheduleView()
                    .tabItem {
                        Label("スケジュール", systemImage: "calendar")
                    }
                    .tag(AppTab.schedule)

                TaskListView()
                    .tabItem {
                        Label("タスク", systemImage: "checklist")
                    }
                    .tag(AppTab.tasks)

                SettingsView()
                    .tabItem {
                        Label("設定", systemImage: "gear")
                    }
                    .tag(AppTab.settings)
            }
            .tint(.indigo)
            #else
            NavigationSplitView {
                List(selection: $selectedTab) {
                    Label("秘書", systemImage: "bubble.left.and.bubble.right.fill")
                        .tag(AppTab.chat)
                    Label("日次報告", systemImage: "sun.max.fill")
                        .tag(AppTab.briefing)
                    Label("メモ", systemImage: "note.text")
                        .tag(AppTab.memo)
                    Label("スケジュール", systemImage: "calendar")
                        .tag(AppTab.schedule)
                    Label("タスク", systemImage: "checklist")
                        .tag(AppTab.tasks)
                    Label("設定", systemImage: "gear")
                        .tag(AppTab.settings)
                }
                .navigationTitle("AI秘書")
                .listStyle(.sidebar)
            } detail: {
                switch selectedTab {
                case .chat:
                    ChatView()
                case .briefing:
                    DailyBriefingView()
                case .memo:
                    MemoListView()
                case .schedule:
                    ScheduleView()
                case .tasks:
                    TaskListView()
                case .settings:
                    SettingsView()
                }
            }
            #endif

            // 日次報告フローティングボタン (iOS)
            #if os(iOS)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showDailyBriefing = true
                    } label: {
                        Image(systemName: "sun.max.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .indigo.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                }
                Spacer()
            }
            #endif
        }
        .sheet(isPresented: $showDailyBriefing) {
            DailyBriefingView()
        }
    }
}

enum AppTab: Hashable {
    case chat, briefing, memo, schedule, tasks, settings
}
