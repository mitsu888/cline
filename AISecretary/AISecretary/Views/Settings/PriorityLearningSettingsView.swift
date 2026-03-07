import SwiftUI
import SwiftData

/// AI優先度学習の設定・統計画面
struct PriorityLearningSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var learningService = PriorityLearningService()
    @State private var statistics: LearningStatistics?
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            // 有効/無効
            Section {
                Toggle("AI優先度学習を有効にする", isOn: $learningService.isLearningEnabled)
            } header: {
                Text("設定")
            } footer: {
                Text("有効にすると、タスクの完了パターンを学習し、新しいタスクの優先度を自動で提案します。")
            }

            if learningService.isLearningEnabled {
                // 統計情報
                Section("学習状況") {
                    if let stats = statistics {
                        LabeledContent("学習レコード数") {
                            Text("\(stats.totalRecords)件")
                        }

                        LabeledContent("タスク完了率") {
                            Text(stats.accuracyPercentage)
                        }

                        if !stats.topKeywords.isEmpty {
                            DisclosureGroup("よく使うキーワード") {
                                ForEach(stats.topKeywords) { keyword in
                                    HStack {
                                        Text(keyword.keyword)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(keyword.count)回")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("統計データを読み込み中...")
                            .foregroundStyle(.secondary)
                    }
                }

                // 仕組みの説明
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        featureRow(icon: "text.magnifyingglass", text: "タスク名のキーワードを分析")
                        featureRow(icon: "clock.arrow.circlepath", text: "完了パターンから傾向を学習")
                        featureRow(icon: "calendar.day.timeline.left", text: "曜日・時間帯の傾向も考慮")
                        featureRow(icon: "chart.line.uptrend.xyaxis", text: "新しいデータほど重視（90日で減衰）")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("学習の仕組み")
                }

                // リセット
                Section {
                    Button("学習データをリセット", role: .destructive) {
                        showResetConfirm = true
                    }
                } footer: {
                    Text("すべての学習データが削除されます。設定は維持されます。")
                }
            }
        }
        .navigationTitle("AI優先度学習")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            statistics = learningService.getStatistics(context: modelContext)
        }
        .alert("学習データをリセット", isPresented: $showResetConfirm) {
            Button("リセット", role: .destructive) {
                learningService.resetLearningData(context: modelContext)
                statistics = learningService.getStatistics(context: modelContext)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべての学習データが削除されます。この操作は取り消せません。")
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.indigo)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
