import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .chat
    @State private var showDailyBriefing = false
    @State private var showDeclineSuggestion = false
    @State private var showReflection = false

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

                HabitTrackerView()
                    .tabItem {
                        Label("習慣", systemImage: "flame.fill")
                    }
                    .tag(AppTab.habits)

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

                    Section("管理") {
                        Label("日次報告", systemImage: "sun.max.fill")
                            .tag(AppTab.briefing)
                        Label("スケジュール", systemImage: "calendar")
                            .tag(AppTab.schedule)
                        Label("タスク", systemImage: "checklist")
                            .tag(AppTab.tasks)
                        Label("メモ", systemImage: "note.text")
                            .tag(AppTab.memo)
                    }

                    Section("ライフ") {
                        Label("習慣", systemImage: "flame.fill")
                            .tag(AppTab.habits)
                        Label("振り返り", systemImage: "moon.stars.fill")
                            .tag(AppTab.reflection)
                        Label("エネルギー", systemImage: "battery.75")
                            .tag(AppTab.energy)
                    }

                    Section {
                        Label("設定", systemImage: "gear")
                            .tag(AppTab.settings)
                    }
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
                case .habits:
                    HabitTrackerView()
                case .reflection:
                    DailyReflectionView()
                case .energy:
                    EnergySettingsView()
                case .settings:
                    SettingsView()
                }
            }
            #endif

            // フローティングボタン群 (iOS)
            #if os(iOS)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 日次報告ボタン
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

                        // 断る提案ボタン
                        Button {
                            showDeclineSuggestion = true
                        } label: {
                            Image(systemName: "hand.raised.fill")
                                .font(.body)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .shadow(color: .orange.opacity(0.3), radius: 6, y: 3)
                        }

                        // 振り返りボタン
                        Button {
                            showReflection = true
                        } label: {
                            Image(systemName: "moon.stars.fill")
                                .font(.body)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.indigo.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(color: .indigo.opacity(0.3), radius: 6, y: 3)
                        }
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
        .sheet(isPresented: $showDeclineSuggestion) {
            DeclineSuggestionView()
        }
        .sheet(isPresented: $showReflection) {
            DailyReflectionView()
        }
    }
}

enum AppTab: Hashable {
    case chat, briefing, memo, schedule, tasks, habits, reflection, energy, settings
}
