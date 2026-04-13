import SwiftUI

/// 場所別の移動時間を管理する画面
/// ユーザーがよく行く場所と移動時間を手動で登録
struct TravelTimePresetsView: View {
    @StateObject private var travelTimeService = TravelTimeService()
    @State private var newDestination = ""
    @State private var newMinutes = 30
    @State private var presets: [String: Int] = [:]

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("よく行く場所の移動時間を登録しておくと、スケジュールの場所名と自動でマッチして出発通知の精度が上がります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 新規追加
            Section("場所を追加") {
                TextField("場所名（例: 渋谷オフィス）", text: $newDestination)

                Stepper("移動時間: \(newMinutes)分", value: $newMinutes, in: 5...180, step: 5)

                Button {
                    addPreset()
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                }
                .disabled(newDestination.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // 登録済みプリセット一覧
            Section("登録済みの場所") {
                if presets.isEmpty {
                    HStack {
                        Image(systemName: "mappin.slash")
                            .foregroundStyle(.secondary)
                        Text("まだ場所が登録されていません")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(sortedPresets, id: \.key) { destination, minutes in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(destination)
                                    .font(.body)
                                Text("移動時間: \(minutes)分")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "clock")
                                .foregroundStyle(.blue)
                            Text("\(minutes)分")
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                    .onDelete(perform: deletePresets)
                }
            }

            // よく使うプリセットの提案
            Section {
                Text("よく使う場所の例")
                    .font(.caption)
                    .fontWeight(.medium)

                ForEach(suggestedPresets, id: \.name) { suggestion in
                    if presets[suggestion.name] == nil {
                        Button {
                            newDestination = suggestion.name
                            newMinutes = suggestion.minutes
                        } label: {
                            HStack {
                                Image(systemName: suggestion.icon)
                                    .foregroundStyle(.indigo)
                                    .frame(width: 24)
                                Text(suggestion.name)
                                Spacer()
                                Text("\(suggestion.minutes)分")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }
            } header: {
                Text("候補から追加")
            }
        }
        .navigationTitle("移動時間プリセット")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            presets = travelTimeService.savedTravelTimes
        }
    }

    private var sortedPresets: [(key: String, value: Int)] {
        presets.sorted { $0.key < $1.key }
    }

    private func addPreset() {
        let name = newDestination.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        travelTimeService.saveTravelTime(destination: name, minutes: newMinutes)
        presets = travelTimeService.savedTravelTimes
        newDestination = ""
        newMinutes = 30
    }

    private func deletePresets(at offsets: IndexSet) {
        let sorted = sortedPresets
        for index in offsets {
            let key = sorted[index].key
            travelTimeService.removeTravelTime(destination: key)
        }
        presets = travelTimeService.savedTravelTimes
    }

    private var suggestedPresets: [PresetSuggestion] {
        [
            PresetSuggestion(name: "会社", minutes: 40, icon: "building.2"),
            PresetSuggestion(name: "駅前", minutes: 15, icon: "tram"),
            PresetSuggestion(name: "病院", minutes: 25, icon: "cross.case"),
            PresetSuggestion(name: "ジム", minutes: 20, icon: "dumbbell"),
            PresetSuggestion(name: "学校", minutes: 30, icon: "book"),
            PresetSuggestion(name: "空港", minutes: 90, icon: "airplane"),
        ]
    }
}

private struct PresetSuggestion {
    let name: String
    let minutes: Int
    let icon: String
}
