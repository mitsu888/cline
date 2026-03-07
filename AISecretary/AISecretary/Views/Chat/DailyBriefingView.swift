import SwiftUI
import SwiftData

struct DailyBriefingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduleItem.startDate) private var schedules: [ScheduleItem]
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @StateObject private var briefingService = DailyBriefingService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if briefingService.isGenerating {
                        generatingView
                    } else if let briefing = briefingService.todaysBriefing {
                        briefingContent(briefing)
                    } else {
                        emptyView
                    }
                }
                .padding()
            }
            .navigationTitle("秘書からの報告")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await generateBriefing() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(briefingService.isGenerating)
                }
            }
            .task {
                if briefingService.todaysBriefing == nil {
                    await generateBriefing()
                }
            }
        }
    }

    private var generatingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("秘書が今日の報告を準備しています...")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("APIキーを設定すると日次報告を受けられます")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    @ViewBuilder
    private func briefingContent(_ briefing: DailyBriefing) -> some View {
        // 挨拶
        Text(briefing.greeting)
            .font(.title3)
            .fontWeight(.medium)

        Divider()

        // スケジュール概要
        sectionCard(title: "今日のスケジュール", icon: "calendar", color: .blue) {
            Text(briefing.scheduleSummary)
        }

        // タスク概要
        sectionCard(title: "タスク状況", icon: "checklist", color: .indigo) {
            Text(briefing.taskSummary)
        }

        // オーバーロード警告
        if briefing.overloadDetected {
            sectionCard(title: "負荷警告", icon: "exclamationmark.triangle.fill", color: .red) {
                Text("本日のタスク量が多すぎると判断しました。以下の調整を提案します。")
                    .foregroundStyle(.red)
            }
        }

        // 提案
        if !briefing.recommendations.isEmpty {
            sectionCard(title: "秘書からの提案", icon: "lightbulb.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(briefing.recommendations, id: \.self) { rec in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(rec)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }

        // アーカイブ提案
        if !briefing.tasksToArchive.isEmpty {
            sectionCard(title: "箱にしまう提案", icon: "archivebox.fill", color: .purple) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("以下のタスクは今は優先度が低いため、一旦保留にすることを提案します：")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(briefing.tasksToArchive, id: \.title) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                    .font(.subheadline)
                                Text(item.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("保留にする") {
                                archiveTask(title: item.title)
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }

        // 優先度調整提案
        if !briefing.priorityAdjustments.isEmpty {
            sectionCard(title: "優先度の調整提案", icon: "arrow.up.arrow.down", color: .teal) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(briefing.priorityAdjustments, id: \.title) { adj in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(adj.title)
                                    .font(.subheadline)
                                Text("\(adj.reason) → 優先度: \(adj.newPriority)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("適用") {
                                adjustPriority(title: adj.title, newPriority: adj.newPriority)
                            }
                            .buttonStyle(.bordered)
                            .tint(.teal)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }

        // 励まし
        if !briefing.motivationalNote.isEmpty {
            Text(briefing.motivationalNote)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func generateBriefing() async {
        briefingService.setup(apiKey: appState.apiKey)
        _ = try? await briefingService.generateDailyBriefing(
            schedules: schedules,
            tasks: tasks,
            userName: appState.userName
        )
    }

    private func archiveTask(title: String) {
        if let task = tasks.first(where: { $0.title == title && !$0.isCompleted }) {
            task.priority = .low
            task.detail += "\n[秘書により保留: \(Date().shortDateString)]"
            try? modelContext.save()
        }
    }

    private func adjustPriority(title: String, newPriority: String) {
        if let task = tasks.first(where: { $0.title == title && !$0.isCompleted }) {
            task.priority = Priority(fromString: newPriority)
            try? modelContext.save()
        }
    }
}
