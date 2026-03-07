import SwiftUI

/// カレンダー同期設定・管理画面
struct CalendarSyncView: View {
    @StateObject private var syncService = CalendarSyncService.shared

    var body: some View {
        NavigationStack {
            Form {
                // 権限セクション
                authorizationSection

                // 同期されたカレンダー選択
                if syncService.authorizationStatus == .fullAccess {
                    calendarSelectionSection
                    syncSettingsSection
                    syncStatusSection
                }
            }
            .navigationTitle("カレンダー連携")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    // MARK: - Sections

    private var authorizationSection: some View {
        Section {
            switch syncService.authorizationStatus {
            case .fullAccess:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("カレンダーへのアクセスが許可されています")
                        .font(.subheadline)
                }

            case .denied, .restricted:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("カレンダーへのアクセスが拒否されています")
                            .font(.subheadline)
                    }
                    Text("設定アプリ → AI秘書 → カレンダー から許可してください")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .notDetermined, .writeOnly:
                Button {
                    Task { await syncService.requestAccess() }
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(.indigo)
                        Text("カレンダーへのアクセスを許可する")
                    }
                }

            @unknown default:
                EmptyView()
            }
        } header: {
            Text("アクセス権限")
        } footer: {
            Text("iOSの「設定 → カレンダー → アカウント」でGoogleアカウントを追加すると、Google Calendarも自動的に表示されます。")
        }
    }

    private var calendarSelectionSection: some View {
        Section {
            if syncService.availableCalendars.isEmpty {
                Button("カレンダー一覧を読み込む") {
                    syncService.loadAvailableCalendars()
                }
            } else {
                ForEach(groupedCalendars, id: \.0) { sourceName, calendars in
                    DisclosureGroup {
                        ForEach(calendars) { calendar in
                            calendarRow(calendar)
                        }
                    } label: {
                        HStack {
                            Image(systemName: calendars.first?.sourceIcon ?? "calendar")
                                .foregroundStyle(.indigo)
                            Text(sourceName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        } header: {
            Text("同期するカレンダー")
        } footer: {
            Text("選択したカレンダーの予定がスケジュール画面に表示されます。")
        }
    }

    private var syncSettingsSection: some View {
        Section("同期設定") {
            Toggle("自動同期（5分ごと）", isOn: $syncService.autoSyncEnabled)
                .onChange(of: syncService.autoSyncEnabled) { _, enabled in
                    if enabled {
                        syncService.startAutoSync()
                    } else {
                        syncService.stopAutoSync()
                    }
                }

            Button {
                Task { await syncService.syncWeekEvents() }
            } label: {
                HStack {
                    if syncService.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("今すぐ同期")
                }
            }
            .disabled(syncService.isSyncing || syncService.selectedCalendarIDs.isEmpty)
        }
    }

    private var syncStatusSection: some View {
        Section("同期状態") {
            LabeledContent("同期済みイベント数") {
                Text("\(syncService.syncedEvents.count)件")
            }

            if let lastSync = syncService.lastSyncDate {
                LabeledContent("最終同期") {
                    Text(lastSync.relativeString)
                }
            }

            if !syncService.syncedEvents.isEmpty {
                NavigationLink {
                    syncedEventsList
                } label: {
                    Text("同期済みイベント一覧")
                }
            }
        }
    }

    // MARK: - Components

    private func calendarRow(_ calendar: CalendarInfo) -> some View {
        Button {
            syncService.toggleCalendar(calendar.id)
        } label: {
            HStack {
                Circle()
                    .fill(calendarColor(calendar))
                    .frame(width: 12, height: 12)

                Text(calendar.title)
                    .foregroundStyle(.primary)

                Spacer()

                if syncService.selectedCalendarIDs.contains(calendar.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.indigo)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var syncedEventsList: some View {
        List {
            ForEach(syncService.syncedEvents) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)

                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(event.timeRange)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let location = event.location, !location.isEmpty {
                        HStack {
                            Image(systemName: "mappin")
                                .font(.caption)
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Image(systemName: event.sourceIcon)
                            .font(.caption2)
                        Text(event.calendarName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("同期済みイベント")
    }

    // MARK: - Helpers

    private var groupedCalendars: [(String, [CalendarInfo])] {
        let grouped = Dictionary(grouping: syncService.availableCalendars) { $0.sourceName }
        return grouped.sorted { $0.key < $1.key }
    }

    private func calendarColor(_ calendar: CalendarInfo) -> Color {
        if let cgColor = calendar.color {
            #if os(iOS)
            return Color(UIColor(cgColor: cgColor))
            #else
            return Color(NSColor(cgColor: cgColor) ?? .blue)
            #endif
        }
        return .blue
    }
}
