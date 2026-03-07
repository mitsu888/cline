# AI秘書 (AI Secretary)

iOS & macOS対応のプロアクティブAI秘書アプリ。Claude APIを活用し、音声メモの瞬時キャプチャ、スケジュール管理、タスクの優先度自動調整、日次報告など、完全な秘書機能を提供します。

## 主な機能

### AI秘書チャット
- Claude APIによる自然な会話
- スケジュール・タスク・メモの自動作成（会話中にAIが判断して追加）
- 音声入力対応

### ボイスメモ（瞬時メモ）
- ワンタップで音声録音→テキスト変換
- AIが内容を分析し、自動で優先度を判断
- スケジュールやタスクへの自動振り分け提案

### 日次報告（プロアクティブ秘書機能）
- 毎日の朝にAI秘書からスケジュール報告
- タスク量の過負荷検知
- 低優先度タスクの「箱入れ」（アーカイブ）提案
- 優先度の自動調整提案
- 励ましのメッセージ

### スケジュール管理
- カレンダービューでの予定管理
- リマインダー通知
- AIによるスケジュール調整提案

### タスク管理
- 優先度別のタスク表示（緊急/高/普通/低）
- 期限管理と通知
- 完了/未完了のフィルタリング

## 技術スタック

- **UI**: SwiftUI (iOS 17+ / macOS 14+)
- **データ永続化**: SwiftData
- **AI**: Claude API (Anthropic)
- **音声認識**: Speech Framework
- **通知**: UserNotifications
- **セキュリティ**: Keychain (APIキー保存)

## セットアップ

1. Xcodeでプロジェクトを開く
2. 設定画面からClaude APIキーを入力
3. 音声認識とプッシュ通知の権限を許可

## プロジェクト構造

```
AISecretary/
├── AISecretaryApp.swift          # アプリエントリポイント
├── ContentView.swift             # メインナビゲーション
├── Models/
│   ├── AppState.swift            # アプリ全体の状態管理
│   ├── Memo.swift                # メモモデル
│   ├── ScheduleItem.swift        # スケジュールモデル
│   ├── TaskItem.swift            # タスクモデル
│   └── ChatMessage.swift         # チャット・会話モデル
├── Views/
│   ├── Chat/
│   │   ├── ChatView.swift        # AI秘書チャット画面
│   │   └── DailyBriefingView.swift # 日次報告画面
│   ├── Memo/
│   │   ├── MemoListView.swift    # メモ一覧・詳細・ボイスメモ
│   │   └── TaskListView.swift    # タスク管理画面
│   ├── Schedule/
│   │   └── ScheduleView.swift    # スケジュール管理画面
│   └── Settings/
│       └── SettingsView.swift    # 設定画面
├── ViewModels/
│   └── ChatViewModel.swift       # チャットのビジネスロジック
├── Services/
│   ├── ClaudeAPIService.swift    # Claude API通信
│   ├── SpeechService.swift       # 音声認識サービス
│   ├── NotificationService.swift # 通知管理
│   └── DailyBriefingService.swift # 日次報告・プロアクティブ機能
└── Utilities/
    ├── KeychainHelper.swift      # Keychain操作
    └── DateFormatters.swift      # 日付フォーマット
```
