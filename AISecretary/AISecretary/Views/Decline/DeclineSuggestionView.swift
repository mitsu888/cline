import SwiftUI
import SwiftData

/// 「断る」提案画面
/// 過負荷時にAIが断る・延期すべき予定を提案し、メッセージの下書きを生成
struct DeclineSuggestionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduleItem.startDate) private var schedules: [ScheduleItem]
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @StateObject private var declineService = DeclineSuggestionService()
    @Environment(\.dismiss) private var dismiss

    @State private var copiedId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if declineService.isGenerating {
                        generatingView
                    } else if declineService.suggestions.isEmpty {
                        emptyView
                    } else {
                        suggestionsContent
                    }
                }
                .padding()
            }
            .navigationTitle("断る提案")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await generateSuggestions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(declineService.isGenerating)
                }
            }
            .task {
                if declineService.suggestions.isEmpty {
                    await generateSuggestions()
                }
            }
        }
    }

    private var generatingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("スケジュールを分析しています...")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("今日のスケジュールは問題ありません")
                .font(.headline)
            Text("特に断る必要のある予定はありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var suggestionsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 警告ヘッダー
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("今日は予定が過密です")
                    .font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("以下の項目について、断る・延期することを提案します：")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 提案カード
            ForEach(declineService.suggestions) { suggestion in
                SuggestionCard(suggestion: suggestion, copiedId: $copiedId)
            }
        }
    }

    private func generateSuggestions() async {
        declineService.setup(appState: appState)
        try? await declineService.generateDeclineSuggestions(
            schedules: schedules,
            tasks: tasks,
            energyProfile: appState.energyProfile
        )
    }
}

struct SuggestionCard: View {
    let suggestion: DeclineSuggestion
    @Binding var copiedId: UUID?

    private var typeColor: Color {
        switch suggestion.type {
        case .decline: .red
        case .postpone: .orange
        case .delegate: .blue
        case .shorten: .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Image(systemName: suggestion.type.icon)
                    .foregroundStyle(typeColor)
                Text(suggestion.targetTitle)
                    .font(.headline)
                Spacer()
                Text(suggestion.type.label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())
            }

            // 理由
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // メッセージ下書き
            if !suggestion.draftMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("メッセージ下書き", systemImage: "envelope.fill")
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(suggestion.draftMessage)
                        .font(.caption)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = suggestion.draftMessage
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(suggestion.draftMessage, forType: .string)
                        #endif
                        copiedId = suggestion.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if copiedId == suggestion.id {
                                copiedId = nil
                            }
                        }
                    } label: {
                        Label(
                            copiedId == suggestion.id ? "コピーしました" : "メッセージをコピー",
                            systemImage: copiedId == suggestion.id ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedId == suggestion.id ? .green : .indigo)
                    .controlSize(.small)
                }
            }

            // 代替案
            if !suggestion.alternative.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("代替案: \(suggestion.alternative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(typeColor.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(typeColor.opacity(0.2))
        )
    }
}
