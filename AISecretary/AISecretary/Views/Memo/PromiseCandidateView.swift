import SwiftUI
import SwiftData

/// ボイスメモから抽出された「約束」候補を表示し、カレンダーイベントとして追加できるビュー
struct PromiseCandidateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let candidates: [PromiseCandidate]
    let memoTitle: String

    @State private var addedIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("ボイスメモ「\(memoTitle)」から以下の約束・予定が見つかりました。追加したい項目を選んでください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(candidates) { candidate in
                    PromiseCandidateRow(
                        candidate: candidate,
                        isAdded: addedIds.contains(candidate.id)
                    ) {
                        addSchedule(from: candidate)
                    }
                }
            }
            .navigationTitle("約束の抽出")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private func addSchedule(from candidate: PromiseCandidate) {
        let detail = [
            candidate.person.isEmpty ? nil : "相手: \(candidate.person)",
            candidate.detail.isEmpty ? nil : candidate.detail,
        ].compactMap { $0 }.joined(separator: "\n")

        let schedule = ScheduleItem(
            title: candidate.title,
            detail: detail,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            location: candidate.location
        )
        modelContext.insert(schedule)
        try? modelContext.save()
        addedIds.insert(candidate.id)
    }
}

struct PromiseCandidateRow: View {
    let candidate: PromiseCandidate
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(candidate.title)
                    .font(.headline)
                Spacer()
                Text(candidate.confidenceLabel)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(confidenceColor.opacity(0.15))
                    .foregroundStyle(confidenceColor)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                if !candidate.person.isEmpty {
                    Label(candidate.person, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Label(candidate.startDate.dateTimeString, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !candidate.location.isEmpty {
                Label(candidate.location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !candidate.detail.isEmpty {
                Text(candidate.detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            HStack {
                Spacer()
                if isAdded {
                    Label("追加済み", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button {
                        onAdd()
                    } label: {
                        Label("スケジュールに追加", systemImage: "calendar.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.indigo)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var confidenceColor: Color {
        if candidate.confidence >= 0.8 { return .green }
        if candidate.confidence >= 0.5 { return .orange }
        return .gray
    }
}
