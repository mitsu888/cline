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

                Section("通知") {
                    Toggle("通知を有効にする", isOn: $notificationEnabled)
                        .onChange(of: notificationEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    notificationEnabled = await NotificationService.shared.requestPermission()
                                }
                            }
                        }
                }

                Section("アプリについて") {
                    LabeledContent("バージョン") {
                        Text("1.0.0")
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
