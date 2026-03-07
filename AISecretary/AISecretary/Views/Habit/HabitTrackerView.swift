import SwiftUI
import SwiftData

/// 習慣トラッカー画面
/// 毎日の習慣を管理し、達成状況を可視化
struct HabitTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitItem.createdAt) private var habits: [HabitItem]
    @Query(sort: \HabitLog.date, order: .reverse) private var allLogs: [HabitLog]
    @State private var showAddSheet = false

    private var todayLogs: [HabitLog] {
        allLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayCompletionRate: Double {
        let activeHabits = habits.filter { $0.isActive }
        guard !activeHabits.isEmpty else { return 0 }
        let completed = activeHabits.filter { habit in
            todayLogs.contains { $0.habitId == habit.id && $0.isCompleted }
        }.count
        return Double(completed) / Double(activeHabits.count)
    }

    var body: some View {
        NavigationStack {
            List {
                // 今日の達成状況サマリー
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            Text("今日の達成率")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(todayCompletionRate * 100))%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(completionColor)
                        }

                        ProgressView(value: todayCompletionRate)
                            .tint(completionColor)
                            .scaleEffect(y: 2)

                        if todayCompletionRate >= 1.0 {
                            Text("全ての習慣を達成しました！素晴らしい！")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 習慣リスト
                Section("今日の習慣") {
                    ForEach(habits.filter { $0.isActive }) { habit in
                        HabitRow(
                            habit: habit,
                            isCompleted: isCompleted(habit),
                            streak: habit.currentStreak
                        ) {
                            toggleHabit(habit)
                        }
                    }
                    .onDelete(perform: deleteHabits)
                }

                // 非アクティブな習慣
                let inactiveHabits = habits.filter { !$0.isActive }
                if !inactiveHabits.isEmpty {
                    Section("休止中") {
                        ForEach(inactiveHabits) { habit in
                            HStack {
                                Image(systemName: habit.iconName)
                                    .foregroundStyle(.secondary)
                                Text(habit.title)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("再開") {
                                    habit.isActive = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                // 週間レポート
                Section("今週のストリーク") {
                    ForEach(habits.filter { $0.isActive }) { habit in
                        WeeklyStreakRow(habit: habit, logs: allLogs.filter { $0.habitId == habit.id })
                    }
                }
            }
            .navigationTitle("習慣トラッカー")
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
            }
            .sheet(isPresented: $showAddSheet) {
                AddHabitView()
            }
        }
    }

    private var completionColor: Color {
        switch todayCompletionRate {
        case 0.8...1.0: .green
        case 0.5..<0.8: .orange
        default: .red
        }
    }

    private func isCompleted(_ habit: HabitItem) -> Bool {
        todayLogs.contains { $0.habitId == habit.id && $0.isCompleted }
    }

    private func toggleHabit(_ habit: HabitItem) {
        if let existingLog = todayLogs.first(where: { $0.habitId == habit.id }) {
            existingLog.isCompleted.toggle()
            existingLog.completedAt = existingLog.isCompleted ? Date() : nil

            if existingLog.isCompleted {
                habit.currentStreak += 1
                habit.bestStreak = max(habit.bestStreak, habit.currentStreak)
            } else {
                habit.currentStreak = max(0, habit.currentStreak - 1)
            }
        } else {
            let log = HabitLog(habitId: habit.id)
            log.isCompleted = true
            log.completedAt = Date()
            modelContext.insert(log)

            habit.currentStreak += 1
            habit.bestStreak = max(habit.bestStreak, habit.currentStreak)
        }
        try? modelContext.save()
    }

    private func deleteHabits(at offsets: IndexSet) {
        let activeHabits = habits.filter { $0.isActive }
        for index in offsets {
            modelContext.delete(activeHabits[index])
        }
    }
}

struct HabitRow: View {
    let habit: HabitItem
    let isCompleted: Bool
    let streak: Int
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: habit.iconName)
                .foregroundStyle(isCompleted ? .green : .indigo)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                HStack(spacing: 8) {
                    Label("\(habit.durationMinutes)分", systemImage: "clock")
                    Label(habit.preferredTimeSlot.shortLabel, systemImage: habit.preferredTimeSlot.icon)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak)")
                        .fontWeight(.medium)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct WeeklyStreakRow: View {
    let habit: HabitItem
    let logs: [HabitLog]

    private var last7Days: [Date] {
        (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date())
        }.reversed()
    }

    var body: some View {
        HStack {
            Text(habit.title)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                ForEach(last7Days, id: \.self) { date in
                    let completed = logs.contains {
                        Calendar.current.isDate($0.date, inSameDayAs: date) && $0.isCompleted
                    }
                    Circle()
                        .fill(completed ? Color.green : Color(.systemGray5))
                        .frame(width: 20, height: 20)
                        .overlay {
                            if Calendar.current.isDateInToday(date) {
                                Circle()
                                    .strokeBorder(.indigo, lineWidth: 2)
                            }
                        }
                }
            }
        }
    }
}

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var durationMinutes = 30
    @State private var preferredTimeSlot: TimeSlot = .morning
    @State private var iconName = "star.fill"

    private let iconOptions = [
        "star.fill", "book.fill", "figure.run", "brain.head.profile",
        "cup.and.saucer.fill", "pencil", "music.note", "heart.fill",
        "leaf.fill", "paintbrush.fill", "dumbbell.fill", "bed.double.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("習慣の内容") {
                    TextField("習慣名", text: $title)
                    TextField("詳細（任意）", text: $detail, axis: .vertical)
                        .lineLimit(2)
                }

                Section("時間設定") {
                    Stepper("所要時間: \(durationMinutes)分", value: $durationMinutes, in: 5...180, step: 5)
                    Picker("希望時間帯", selection: $preferredTimeSlot) {
                        ForEach(TimeSlot.allCases, id: \.self) { slot in
                            Label(slot.label, systemImage: slot.icon)
                                .tag(slot)
                        }
                    }
                }

                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(iconName == icon ? Color.indigo.opacity(0.2) : Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(iconName == icon ? .indigo : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("習慣を追加")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let habit = HabitItem(
                            title: title,
                            detail: detail,
                            durationMinutes: durationMinutes,
                            preferredTimeSlot: preferredTimeSlot,
                            iconName: iconName
                        )
                        modelContext.insert(habit)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
