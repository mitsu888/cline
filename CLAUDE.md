@.clinerules/general.md
@.clinerules/network.md
@.clinerules/cli.md

# Cline コードベースガイド

本ドキュメントは、AIアシスタントがこのコードベースで効率的に作業するための包括的なガイドです。

## プロジェクト概要

Cline は、ファイルの作成・編集、コマンド実行、ブラウザ操作、ターミナル操作を人間の承認のもとで自律的に行う AI コーディングエージェントです。VS Code 拡張機能、スタンドアロン CLI、デスクトップアプリとして提供されています。

- **リポジトリ:** `cline/cline`
- **言語:** TypeScript
- **ライセンス:** Apache-2.0
- **VS Code 最小バージョン:** 1.84.0

## ディレクトリ構成

```
cline/
├── src/                    # メイン拡張機能ソースコード
│   ├── core/               # コアビジネスロジック
│   │   ├── api/            # AIプロバイダーアダプター（45以上）
│   │   ├── controller/     # メインコントローラー（オーケストレーション）
│   │   ├── task/           # タスク実行エンジン・ツールハンドラー
│   │   ├── prompts/        # システムプロンプト（テンプレート・バリアント）
│   │   ├── context/        # コンテキスト管理
│   │   ├── slash-commands/  # スラッシュコマンド処理
│   │   ├── storage/        # 状態永続化
│   │   ├── workspace/      # ワークスペース管理
│   │   ├── hooks/          # フックシステム
│   │   ├── ignore/         # .clineignore 処理
│   │   ├── locks/          # タスクロック機構
│   │   ├── mentions/       # @メンション処理
│   │   ├── permissions/    # 権限管理
│   │   ├── webview/        # Webview プロバイダー
│   │   └── assistant-message/ # アシスタントメッセージ解析
│   ├── services/           # プラットフォーム非依存サービス
│   │   ├── account/        # アカウントサービス
│   │   ├── auth/           # 認証（Anthropic, OCA）
│   │   ├── browser/        # ブラウザ自動化
│   │   ├── feature-flags/  # フィーチャーフラグ
│   │   ├── mcp/            # MCP ハブ管理
│   │   ├── telemetry/      # テレメトリ（PostHog）
│   │   └── tree-sitter/    # 構文解析
│   ├── hosts/              # ホスト固有実装
│   │   ├── vscode/         # VS Code 拡張ホスト
│   │   └── external/       # 外部ホスト実装
│   ├── integrations/       # 機能統合
│   │   ├── checkpoints/    # チェックポイント
│   │   ├── editor/         # ファイル編集
│   │   └── terminal/       # ターミナル統合
│   ├── shared/             # 共有型・ユーティリティ
│   │   ├── proto-conversions/ # Proto 変換レイヤー
│   │   ├── storage/        # 状態キー定義
│   │   └── proto/          # 生成された Proto 型
│   ├── utils/              # 汎用ユーティリティ
│   ├── extension.ts        # 拡張エントリーポイント
│   ├── common.ts           # 共通初期化（クロスプラットフォーム）
│   └── config.ts           # 設定管理
├── webview-ui/             # React ベースのフロントエンド UI
│   ├── src/
│   │   ├── components/     # React コンポーネント
│   │   ├── context/        # React Context プロバイダー
│   │   ├── hooks/          # カスタム React フック
│   │   ├── services/       # フロントエンドサービス
│   │   └── utils/          # フロントエンドユーティリティ
│   ├── vite.config.ts      # Vite バンドラー設定
│   └── tailwind.config.mjs # Tailwind CSS 設定
├── cli/                    # スタンドアロン CLI（React Ink）
│   ├── src/
│   │   ├── index.ts        # CLI エントリーポイント
│   │   ├── vscode-shim.ts  # VS Code API シム
│   │   ├── components/     # Ink コンポーネント（TUI）
│   │   └── acp/            # Agent Client Protocol モード
│   └── package.json
├── proto/                  # Protocol Buffer 定義
│   ├── cline/              # Cline サービス定義（17ファイル）
│   └── host/               # ホスト固有定義
├── tests/                  # テスト設定
├── evals/                  # 評価スイート
├── scripts/                # ビルド・自動化スクリプト
├── locales/                # i18n 翻訳
├── .github/workflows/      # CI/CD パイプライン
└── .clinerules/            # Cline 固有ルール
```

## ビルド・開発コマンド

```bash
# 依存関係インストール
npm install

# 開発（Proto 生成 + ウォッチ）
npm run dev

# Webview 開発サーバー（ホットリロード）
npm run dev:webview

# CLI 開発
npm run cli:dev

# ビルド（型チェック + リント + esbuild）
npm run compile

# Webview ビルド
npm run build:webview

# CLI ビルド
npm run cli:build

# Proto 生成（proto/ 変更後に必須）
npm run protos

# テスト
npm run test              # 全テスト
npm run test:unit         # ユニットテスト（Mocha + Chai）
npm run test:integration  # 統合テスト
npm run test:e2e          # E2E テスト（Playwright）
npm run cli:test          # CLI テスト（Vitest）

# コード品質
npm run lint              # リントチェック
npm run format            # フォーマットチェック
npm run format:fix        # フォーマット自動修正
npm run check-types       # 型チェック
npm run fix:all           # 全問題修正
```

**重要:** `npm run build` は存在しません。ビルドには `npm run compile` を使用してください。

## アーキテクチャ概要

### 通信モデル

拡張機能と Webview は gRPC ライクなプロトコルで VS Code メッセージパッシング上で通信します。

```
Webview (React) ←→ gRPC over postMessage ←→ Extension Host (Node.js)
                                                    ↕
                                              AI Provider APIs
                                                    ↕
                                              MCP Servers
```

### タスク実行フロー

```
ユーザー入力 → parseSlashCommands() → buildApiHandler()
→ createMessage(systemPrompt, messages, tools) → ApiStream
→ parseAssistantMessage() → ToolUse[]
→ ToolExecutor.executeTool() → 結果を ClineStorageMessage に保存
→ 次のイテレーション or タスク完了
```

### 主要コンポーネント

| コンポーネント | ファイル | 役割 |
|---|---|---|
| Controller | `src/core/controller/index.ts` | 拡張ライフサイクル管理、認証、MCP 連携 |
| Task | `src/core/task/index.ts` | タスク実行エンジン（メッセージ→API→ツールループ） |
| ToolExecutor | `src/core/task/ToolExecutor.ts` | ツール実行の調整・権限チェック |
| PromptRegistry | `src/core/prompts/system-prompt/registry/PromptRegistry.ts` | プロンプトバリアント・コンポーネント管理 |
| StateManager | `src/shared/storage/StateManager.ts` | インメモリキャッシュ + 非同期ディスク永続化 |
| ApiHandler | `src/core/api/index.ts` | 45以上のプロバイダーのファクトリー・ストリーミング |

## テスト

- **ユニットテスト:** Mocha + Chai（`src/**/__tests__/*.ts`）
- **統合テスト:** VS Code 拡張テスト CLI
- **E2Eテスト:** Playwright（`src/test/e2e/**/*.test.ts`）
- **CLI テスト:** Vitest（`cli/src/**/__tests__`）
- **スナップショット:** `UPDATE_SNAPSHOTS=true npm run test:unit` で再生成

### テスト設定

- `test-setup.js` — tsconfig-paths エイリアス解決
- `.mocharc.json` — Mocha 設定
- `playwright.config.ts` — E2E 設定
- `webview-ui/vitest.config.ts` — Webview テスト

## コード品質

- **Biome** (`biome.jsonc`) — フォーマッター + リンター
  - インデント: タブ（幅4）
  - 行幅: 130
  - 改行: LF

## 主要な開発パターン

### ホスト抽象化

`HostProvider`（`src/hosts/host-provider.ts`）が VS Code API を抽象化し、CLI やスタンドアロンでも同じコアロジックが動作可能にしています。

### APIストリーム

```typescript
// すべてのプロバイダーで統一されたストリームインターフェース
type ApiStream = AsyncGenerator<ApiStreamChunk>
type ApiStreamChunk =
  | ApiStreamTextChunk      // テキストコンテンツ
  | ApiStreamThinkingChunk  // 推論/思考
  | ApiStreamUsageChunk     // トークン数
  | ApiStreamToolCallsChunk // ツール呼び出し
```

### ツールハンドラーパターン

```typescript
// src/core/task/tools/handlers/ に25以上のハンドラー
interface IToolHandler {
  readonly name: ClineDefaultTool
  execute(config: TaskConfig, block: ToolUse): Promise<ToolResponse>
  getDescription(block: ToolUse): string
}
```

### タスク状態保護

タスクは単一の mutex（`this.stateMutex`）で全状態変更を保護し、TOCTOU レースコンディションを防止します。

## 変更セット（Changeset）

ユーザー向けの重要な変更には `npm run changeset` で **パッチ** 変更セットを作成してください。マイナー・メジャーバンプは行わないでください。軽微な修正やリファクタリングにはスキップしてください。

## フィーチャーフラグ

新しいフィーチャーフラグを追加する場合は、[PR #7566](https://github.com/cline/cline/pull/7566) を参考にしてください。
