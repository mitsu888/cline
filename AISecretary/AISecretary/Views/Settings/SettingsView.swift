import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeyInput = ""
    @State private var showAPIKey = false
    @State private var notificationEnabled = false
    @State private var serverURLInput = ""
    @State private var authTokenInput = ""
    @State private var showAuthToken = false
    @State private var showServerTestResult = false
    @State private var serverTestSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ユーザー設定") {
                    TextField("お名前", text: $appState.userName)
                    TextField("自宅/職場の住所（表示用）", text: $appState.defaultLocation)
                }

                // --- リレーサーバー設定（推奨） ---
                Section {
                    TextField("サーバーURL", text: $serverURLInput)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif

                    HStack {
                        if showAuthToken {
                            TextField("認証トークン", text: $authTokenInput)
                                .autocapitalization(.none)
                        } else {
                            SecureField("認証トークン", text: $authTokenInput)
                        }
                        Button {
                            showAuthToken.toggle()
                        } label: {
                            Image(systemName: showAuthToken ? "eye.slash" : "eye")
                        }
                    }

                    Button("サーバー設定を保存") {
                        appState.updateRelayConfig(url: serverURLInput, token: authTokenInput)
                        testServerConnection()
                    }
                    .disabled(serverURLInput.isEmpty || authTokenInput.isEmpty)

                    if appState.isRelayConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("リレーサーバーが設定されています")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showServerTestResult {
                        HStack {
                            Image(systemName: serverTestSuccess ? "wifi" : "wifi.slash")
                                .foregroundStyle(serverTestSuccess ? .green : .red)
                            Text(serverTestSuccess ? "サーバー接続OK" : "サーバーに接続できません")
                                .font(.caption)
                                .foregroundStyle(serverTestSuccess ? .green : .red)
                        }
                    }
                } header: {
                    Text("APIリレーサーバー（推奨）")
                } footer: {
                    Text("APIキーをサーバー側で管理します。クライアントにAPIキーを保存する必要がありません。")
                        .font(.caption)
                }

                // --- 旧API直接接続（フォールバック） ---
                Section {
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

                    if appState.isAPIKeySet && !appState.isRelayConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("APIキーが設定されています（直接接続モード）")
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
                } header: {
                    Text("Claude API直接接続（フォールバック）")
                } footer: {
                    Text("リレーサーバーが未設定の場合にのみ使用されます。APIキーがクライアントに保存されます。")
                        .font(.caption)
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

                // --- マネージャーモード ---
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

                        Stepper("デフォルト移動時間: \(appState.defaultTravelMinutes)分", value: $appState.defaultTravelMinutes, in: 5...120, step: 5)

                        Picker("主な交通手段", selection: $appState.preferredTransport) {
                            ForEach(TransportMode.allCases, id: \.self) { mode in
                                Label(mode.label, systemImage: mode.icon).tag(mode)
                            }
                        }

                        NavigationLink {
                            TravelTimePresetsView()
                        } label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(.blue)
                                Text("場所別の移動時間を設定")
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
                        Text("3.0.0")
                    }
                    LabeledContent("AIモデル") {
                        Text("Claude Sonnet 4")
                    }
                    LabeledContent("接続モード") {
                        Text(appState.isRelayConfigured ? "リレーサーバー" : "直接接続")
                            .foregroundStyle(appState.isRelayConfigured ? .green : .orange)
                    }
                }
            }
            .navigationTitle("設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                apiKeyInput = appState.apiKey
                serverURLInput = appState.relayServerURL
                authTokenInput = appState.relayAuthToken
            }
        }
    }

    private func testServerConnection() {
        guard !serverURLInput.isEmpty else { return }

        let urlString = serverURLInput.hasSuffix("/")
            ? "\(serverURLInput)health"
            : "\(serverURLInput)/health"

        guard let url = URL(string: urlString) else {
            showServerTestResult = true
            serverTestSuccess = false
            return
        }

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse {
                    serverTestSuccess = httpResponse.statusCode == 200
                } else {
                    serverTestSuccess = false
                }
            } catch {
                serverTestSuccess = false
            }
            showServerTestResult = true
        }
    }
}
