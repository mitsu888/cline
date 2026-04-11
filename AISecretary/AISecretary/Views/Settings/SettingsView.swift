import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeyInput = ""
    @State private var showAPIKey = false
    @State private var notificationEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ユーザー設定") {
                    TextField("お名前", text: $appState.userName)
                    TextField("自宅/職場の住所（移動時間計算用）", text: $appState.defaultLocation)
                }

                Section("Claude API") {
                    HStack {
                        if showAPIKey {
                            TextField("APIキー", text: $apiKeyInput)
                                .textContentType(.password)
                        } else {
                            SecureField("APIキー", text: $apiKeyInput)
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                    }

                    Button("APIキーを保存") {
                        appState.updateAPIKey(apiKeyInput)
                    }
                    .disabled(apiKeyInput.isEmpty)

                    if appState.isAPIKeySet {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("APIキーが設定されています")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("APIキーを削除", role: .destructive) {
                        apiKeyInput = ""
                        appState.updateAPIKey("")
                        KeychainHelper.delete(key: "claude_api_key")
                    }
                    .disabled(!appState.isAPIKeySet)
                }

                // エネルギープロファイル
                Section("エネルギープロファイル") {
                    NavigationLink {
                        EnergySettingsView()
                    } label: {
                        HStack {
                            Image(systemName: appState.energyProfile.chronotype.icon)
                                .foregroundStyle(.indigo)
                            Text(appState.energyProfile.chronotype.label)
                        }
                    }
                }

                // カレンダー連携
                Section("カレンダー連携") {
                    NavigationLink {
                        CalendarSyncView()
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.purple)
                            Text("Google / Apple カレンダー同期")
                        }
                    }
                    Text("iOSのカレンダーアカウント設定でGoogleアカウントを追加すると、Google Calendarの予定も表示されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // AI優先度学習
                Section("AI優先度学習") {
                    NavigationLink {
                        PriorityLearningSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundStyle(.indigo)
                            Text("自動優先度学習設定")
                        }
                    }
                }

                // マネージャーモード
                Section("マネージャーモード") {
                    Toggle("マネージャーモードを有効にする", isOn: $appState.managerModeEnabled)

                    if appState.managerModeEnabled {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.indigo)
                            Text("芸能人のマネージャーのように、出発時刻を逆算して段階的にお知らせします。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Stepper("準備時間: \(appState.prepTimeMinutes)分", value: $appState.prepTimeMinutes, in: 5...60, step: 5)

                        Picker("交通手段", selection: $appState.preferredTransport) {
                            ForEach(TransportMode.allCases, id: \.self) { mode in
                                Label(mode.label, systemImage: mode.icon).tag(mode)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("通知の流れ:")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("1. 準備開始 → 出発\(appState.prepTimeMinutes)分前")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("2. 出発催促 → 移動時間+余裕10分から逆算")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("3. 急ぎ通知 → 出発時刻5分経過時")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("通知") {
                    Toggle("通知を有効にする", isOn: $notificationEnabled)
                        .onChange(of: notificationEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    notificationEnabled = await NotificationService.shared.requestPermission()
                                }
                            }
                        }

                    Toggle("夜の振り返りリマインダー", isOn: $appState.eveningReminderEnabled)

                    if appState.eveningReminderEnabled {
                        Stepper("リマインダー時刻: \(appState.eveningReminderHour)時", value: $appState.eveningReminderHour, in: 18...23)
                    }
                }

                Section("iCloud同期") {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.blue)
                        Text("iCloud同期が有効です")
                            .font(.subheadline)
                    }
                    Text("すべてのデータはiCloud経由で自動同期されます。メモ、タスク、スケジュール、習慣、振り返りがすべてのデバイスで共有されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("アプリについて") {
                    LabeledContent("バージョン") {
                        Text("2.0.0")
                    }
                    LabeledContent("AIモデル") {
                        Text("Claude Sonnet 4")
                    }
                }
            }
            .navigationTitle("設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                apiKeyInput = appState.apiKey
            }
        }
    }
}
