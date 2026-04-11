import SwiftUI

/// エネルギーレベル設定画面
/// 体内時計タイプを選択し、時間帯ごとのエネルギーレベルを可視化・カスタマイズ
struct EnergySettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                // 体内時計タイプ選択
                Section("あなたのタイプ") {
                    ForEach(Chronotype.allCases, id: \.self) { type in
                        Button {
                            appState.energyProfile = EnergyProfile(chronotype: type)
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(appState.energyProfile.chronotype == type ? .indigo : .secondary)
                                    .frame(width: 30)

                                VStack(alignment: .leading) {
                                    Text(type.label)
                                        .foregroundStyle(.primary)
                                    Text(typeDescription(type))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if appState.energyProfile.chronotype == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.indigo)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // エネルギーレベルの可視化
                Section("時間帯別エネルギー") {
                    ForEach(appState.energyProfile.timeSlotEnergies) { slot in
                        HStack {
                            Text("\(slot.startHour):00")
                                .font(.caption)
                                .frame(width: 40)

                            Rectangle()
                                .fill(energyColor(slot.energy))
                                .frame(height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            Text("\(slot.endHour):00")
                                .font(.caption)
                                .frame(width: 40)

                            Image(systemName: slot.energy.icon)
                                .foregroundStyle(energyColor(slot.energy))
                                .frame(width: 30)

                            Text(slot.energy.label)
                                .font(.caption)
                                .frame(width: 40)
                        }
                    }
                }

                // タスク配置の推奨
                Section("タスク配置の推奨") {
                    ForEach(Priority.allCases, id: \.self) { priority in
                        HStack {
                            Circle()
                                .fill(priorityColor(priority))
                                .frame(width: 8)
                            Text("\(priority.label)タスク")
                                .font(.subheadline)
                            Spacer()
                            Text(appState.energyProfile.recommendedTimeSlot(for: priority))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // ピーク時間帯の説明
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("使い方", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text("エネルギーレベルに基づいて、AIが重要なタスクをピーク時間帯に自動配置します。日次報告にもエネルギーを考慮した提案が含まれます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("エネルギー設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func typeDescription(_ type: Chronotype) -> String {
        switch type {
        case .earlyBird: "5時〜8時がピーク。早起きが得意"
        case .morning: "9時〜12時がピーク。標準的な朝型"
        case .evening: "16時〜20時がピーク。午後から調子が出る"
        case .nightOwl: "17時〜21時がピーク。夜に集中力が高い"
        }
    }

    private func energyColor(_ level: EnergyLevel) -> Color {
        switch level {
        case .low: .gray
        case .medium: .blue
        case .high: .orange
        case .peak: .red
        }
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low: .gray
        case .normal: .blue
        case .high: .orange
        case .urgent: .red
        }
    }
}
