import SwiftUI
import SwiftData

struct ScheduleView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduleItem.startDate) private var schedules: [ScheduleItem]
    @StateObject private var travelTimeService = TravelTimeService()
    @State private var showAddSheet = false
    @State private var selectedDate = Date()
    @State private var travelTimes: [UUID: TravelTimeResult] = [:]

    var filteredSchedules: [ScheduleItem] {
        schedules.filter { schedule in
            Calendar.current.isDate(schedule.startDate, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("日付", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                Divider()

                if filteredSchedules.isEmpty {
                    ContentUnavailableView(
                        "予定なし",
                        systemImage: "calendar.badge.plus",
                        description: Text("\(selectedDate.shortDateString)の予定はありません")
                    )
                } else {
                    List {
                        ForEach(filteredSchedules, id: \.id) { schedule in
                            ScheduleRow(
                                schedule: schedule,
                                travelTime: travelTimes[schedule.id]
                            )
                        }
                        .onDelete(perform: deleteSchedules)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("スケジュール")
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
                AddScheduleView(selectedDate: selectedDate)
            }
            .onChange(of: selectedDate) { _, _ in
                Task { await calculateTravelTimes() }
            }
            .task {
                await calculateTravelTimes()
            }
        }
    }

    private func deleteSchedules(at offsets: IndexSet) {
        for index in offsets {
            let schedule = filteredSchedules[index]
            NotificationService.shared.cancelNotification(id: "schedule-\(schedule.id)")
            NotificationService.shared.cancelNotification(id: "travel-\(schedule.id)")
            modelContext.delete(schedule)
        }
    }

    private func calculateTravelTimes() async {
        let schedulesWithLocation = filteredSchedules.filter { !$0.location.isEmpty }
        guard !schedulesWithLocation.isEmpty else { return }

        travelTimes = await travelTimeService.calculateTravelTimesForToday(schedules: filteredSchedules)

        // 出発通知も設定
        for schedule in schedulesWithLocation {
            _ = await travelTimeService.calculateAndNotify(
                currentLocation: appState.defaultLocation,
                nextSchedule: schedule
            )
        }
    }
}

struct ScheduleRow: View {
    let schedule: ScheduleItem
    var travelTime: TravelTimeResult?

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(priorityColor)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.title)
                    .font(.headline)
                    .strikethrough(schedule.isCompleted)

                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(schedule.startDate.shortTimeString) - \(schedule.endDate.shortTimeString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !schedule.location.isEmpty {
                    HStack {
                        Image(systemName: "mappin")
                            .font(.caption)
                        Text(schedule.location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 移動時間表示
                if let travel = travelTime {
                    HStack(spacing: 4) {
                        Image(systemName: travel.transportIcon)
                            .font(.caption)
                            .foregroundStyle(.cyan)
                        Text(travel.summary)
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                }
            }

            Spacer()

            Text(schedule.priority.label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(priorityColor.opacity(0.15))
                .foregroundStyle(priorityColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch schedule.priority {
        case .low: .gray
        case .normal: .blue
        case .high: .orange
        case .urgent: .red
        }
    }
}

struct AddScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let selectedDate: Date

    @State private var title = ""
    @State private var detail = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var priority: Priority = .normal
    @State private var location = ""
    @State private var reminderEnabled = true

    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: start.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("タイトル", text: $title)
                    TextField("詳細", text: $detail, axis: .vertical)
                        .lineLimit(3)
                    TextField("場所", text: $location)
                }

                Section("日時") {
                    Toggle("終日", isOn: $isAllDay)
                    if isAllDay {
                        DatePicker("日付", selection: $startDate, displayedComponents: .date)
                    } else {
                        DatePicker("開始", selection: $startDate)
                        DatePicker("終了", selection: $endDate)
                    }
                }

                Section("設定") {
                    Picker("優先度", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    Toggle("リマインダー", isOn: $reminderEnabled)
                }
            }
            .navigationTitle("予定を追加")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        save()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func save() {
        let schedule = ScheduleItem(
            title: title,
            detail: detail,
            startDate: startDate,
            endDate: isAllDay ? startDate : endDate,
            isAllDay: isAllDay,
            priority: priority,
            location: location,
            reminderMinutesBefore: reminderEnabled ? 15 : nil
        )
        modelContext.insert(schedule)
        if reminderEnabled {
            NotificationService.shared.scheduleReminder(for: schedule)
        }
    }
}
