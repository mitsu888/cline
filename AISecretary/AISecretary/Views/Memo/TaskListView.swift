import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @StateObject private var learningService = PriorityLearningService()
    @State private var showAddSheet = false
    @State private var filterCompleted = false

    var filteredTasks: [TaskItem] {
        if filterCompleted {
            return tasks.filter { !$0.isCompleted }
        }
        return tasks
    }

    var groupedTasks: [(Priority, [TaskItem])] {
        let grouped = Dictionary(grouping: filteredTasks) { $0.priority }
        return [Priority.urgent, .high, .normal, .low].compactMap { priority in
            guard let items = grouped[priority], !items.isEmpty else { return nil }
            return (priority, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "タスクなし",
                        systemImage: "checklist",
                        description: Text("右上の+ボタンまたはAI秘書に依頼してタスクを追加")
                    )
                } else {
                    List {
                        ForEach(groupedTasks, id: \.0) { priority, items in
                            Section(priority.label) {
                                ForEach(items, id: \.id) { task in
                                    TaskRow(task: task, learningService: learningService)
                                }
                                .onDelete { offsets in
                                    deleteTasks(items: items, at: offsets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("タスク")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Toggle("未完了のみ", isOn: $filterCompleted)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddTaskView(learningService: learningService)
            }
        }
    }

    private func deleteTasks(items: [TaskItem], at offsets: IndexSet) {
        for index in offsets {
            let task = items[index]
            NotificationService.shared.cancelNotification(id: "task-\(task.id)")
            modelContext.delete(task)
        }
    }
}

struct TaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    var learningService: PriorityLearningService?

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    task.toggleComplete()
                    // 完了時に学習データを記録
                    if task.isCompleted, let service = learningService {
                        service.recordTaskCompletion(task: task, context: modelContext)
                    }
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    // AI提案バッジ
                    if task.isPrioritySuggested {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                    }
                }

                if !task.detail.isEmpty {
                    Text(task.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(dueDate.shortDateString)
                    }
                    .font(.caption2)
                    .foregroundStyle(dueDate < Date() && !task.isCompleted ? .red : .tertiary)
                }
            }
        }
    }
}

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var priority: Priority = .normal
    @State private var suggestion: PrioritySuggestion?
    @State private var usedSuggestion = false

    var learningService: PriorityLearningService?

    var body: some View {
        NavigationStack {
            Form {
                TextField("タスク名", text: $title)
                    .onChange(of: title) { _, newTitle in
                        updateSuggestion(for: newTitle)
                    }
                TextField("詳細", text: $detail, axis: .vertical)
                    .lineLimit(3)

                // AI優先度提案
                if let suggestion = suggestion {
                    Section {
                        Button {
                            priority = suggestion.priority
                            usedSuggestion = true
                        } label: {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundStyle(.indigo)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("提案: \(suggestion.priority.label)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(suggestion.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(suggestion.confidenceLabel)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.indigo.opacity(0.1))
                                    .foregroundStyle(.indigo)
                                    .clipShape(Capsule())
                            }
                        }
                        .tint(.primary)
                    } header: {
                        Text("AI優先度提案")
                    }
                }

                Section {
                    Toggle("期限を設定", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("期限", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Picker("優先度", selection: $priority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
            }
            .navigationTitle("タスクを追加")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let task = TaskItem(
                            title: title,
                            detail: detail,
                            dueDate: hasDueDate ? dueDate : nil,
                            priority: priority,
                            isPrioritySuggested: usedSuggestion,
                            priorityConfidence: usedSuggestion ? (suggestion?.confidence ?? 0) : 0
                        )
                        modelContext.insert(task)
                        if hasDueDate {
                            NotificationService.shared.scheduleTaskReminder(for: task)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func updateSuggestion(for newTitle: String) {
        guard let service = learningService, newTitle.count >= 3 else {
            suggestion = nil
            return
        }
        suggestion = service.suggestPriority(for: newTitle, context: modelContext)
    }
}
