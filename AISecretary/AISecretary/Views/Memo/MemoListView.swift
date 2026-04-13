import SwiftUI
import SwiftData

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]
    @StateObject private var speechService = SpeechService()
    @State private var showAddSheet = false
    @State private var showVoiceMemo = false
    @State private var isAnalyzing = false
    @State private var searchText = ""
    @State private var promiseCandidates: [PromiseCandidate] = []
    @State private var showPromiseCandidates = false
    @State private var lastMemoTitle = ""

    var filteredMemos: [Memo] {
        if searchText.isEmpty { return memos }
        return memos.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if memos.isEmpty {
                    ContentUnavailableView(
                        "メモなし",
                        systemImage: "note.text",
                        description: Text("右上の+ボタンまたはマイクボタンでメモを追加")
                    )
                } else {
                    List {
                        ForEach(filteredMemos, id: \.id) { memo in
                            NavigationLink(destination: MemoDetailView(memo: memo)) {
                                MemoRow(memo: memo)
                            }
                        }
                        .onDelete(perform: deleteMemos)
                    }
                    .searchable(text: $searchText, prompt: "メモを検索")
                }
            }
            .navigationTitle("メモ")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showVoiceMemo = true
                    } label: {
                        Image(systemName: "mic.fill")
                    }
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddMemoView()
            }
            .sheet(isPresented: $showVoiceMemo) {
                VoiceMemoView(speechService: speechService) { transcription in
                    saveMemo(from: transcription)
                }
            }
            .sheet(isPresented: $showPromiseCandidates) {
                PromiseCandidateView(
                    candidates: promiseCandidates,
                    memoTitle: lastMemoTitle
                )
            }
        }
    }

    private func deleteMemos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredMemos[index])
        }
    }

    private func saveMemo(from transcription: String) {
        let memo = Memo(content: transcription, isVoiceMemo: true)
        modelContext.insert(memo)

        if appState.isRelayConfigured || appState.isAPIKeySet {
            Task {
                let service: ClaudeAPIService
                if appState.isRelayConfigured {
                    service = ClaudeAPIService(serverURL: appState.relayServerURL, authToken: appState.relayAuthToken)
                } else {
                    service = ClaudeAPIService(apiKey: appState.apiKey)
                }

                // 分析と約束抽出を並行実行
                async let analysisResult = service.analyzeVoiceMemo(transcription: transcription)
                async let promisesResult = service.extractPromises(transcription: transcription)

                if let analysis = try? await analysisResult {
                    memo.priority = analysis.priority
                    memo.title = analysis.summary.prefix(50).description
                    try? modelContext.save()
                }

                if let promises = try? await promisesResult, !promises.isEmpty {
                    lastMemoTitle = memo.title
                    promiseCandidates = promises
                    showPromiseCandidates = true
                }
            }
        }
    }
}

struct MemoRow: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if memo.isVoiceMemo {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }
                Text(memo.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text(memo.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(memo.createdAt.relativeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(memo.priority.label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor.opacity(0.15))
                    .foregroundStyle(priorityColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private var priorityColor: Color {
        switch memo.priority {
        case .low: .gray
        case .normal: .blue
        case .high: .orange
        case .urgent: .red
        }
    }
}

struct MemoDetailView: View {
    @Bindable var memo: Memo
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section("タイトル") {
                TextField("タイトル", text: $memo.title)
            }

            Section("内容") {
                TextEditor(text: $memo.content)
                    .frame(minHeight: 200)
            }

            Section("設定") {
                Picker("優先度", selection: $memo.priority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
            }

            Section("情報") {
                LabeledContent("作成日") {
                    Text(memo.createdAt.dateTimeString)
                }
                LabeledContent("更新日") {
                    Text(memo.updatedAt.dateTimeString)
                }
                if memo.isVoiceMemo {
                    LabeledContent("種類") {
                        Label("ボイスメモ", systemImage: "mic.fill")
                    }
                }
            }
        }
        .navigationTitle("メモ詳細")
        .onChange(of: memo.content) { _, _ in
            memo.updatedAt = Date()
        }
    }
}

struct AddMemoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var priority: Priority = .normal

    var body: some View {
        NavigationStack {
            Form {
                TextField("タイトル", text: $title)
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
                Picker("優先度", selection: $priority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
            }
            .navigationTitle("メモを追加")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let memo = Memo(content: content, title: title, priority: priority)
                        modelContext.insert(memo)
                        dismiss()
                    }
                    .disabled(content.isEmpty)
                }
            }
        }
    }
}

struct VoiceMemoView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var speechService: SpeechService
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(speechService.transcribedText.isEmpty ? "マイクボタンを押して話してください" : speechService.transcribedText)
                    .font(.body)
                    .foregroundStyle(speechService.transcribedText.isEmpty ? .secondary : .primary)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    if speechService.isRecording {
                        speechService.stopRecording()
                    } else {
                        Task { await speechService.startRecording() }
                    }
                } label: {
                    Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(speechService.isRecording ? .red : .indigo)
                        .symbolEffect(.pulse, isActive: speechService.isRecording)
                }

                if speechService.isRecording {
                    Text("録音中...")
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("ボイスメモ")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        speechService.stopRecording()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        speechService.stopRecording()
                        onSave(speechService.transcribedText)
                        dismiss()
                    }
                    .disabled(speechService.transcribedText.isEmpty)
                }
            }
        }
    }
}
