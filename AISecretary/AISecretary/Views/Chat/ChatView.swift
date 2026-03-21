import SwiftUI
import SwiftData

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var speechService = SpeechService()
    @State private var showVoiceInput = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !appState.isAPIKeySet {
                    apiKeyPrompt
                } else {
                    chatContent
                }
            }
            .navigationTitle("AI秘書")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.newConversation()
                    } label: {
                        Image(systemName: "plus.bubble")
                    }
                }
            }
            .onAppear {
                viewModel.setup(apiKey: appState.apiKey, modelContext: modelContext)
            }
            .onChange(of: appState.apiKey) { _, newValue in
                viewModel.setup(apiKey: newValue, modelContext: modelContext)
            }
        }
    }

    private var apiKeyPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Claude APIキーを設定してください")
                .font(.headline)
            Text("設定タブからAPIキーを入力してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let messages = viewModel.currentConversation?.messages
                            .sorted(by: { $0.timestamp < $1.timestamp }) {
                            ForEach(messages, id: \.id) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        if viewModel.isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.currentConversation?.messages.count) { _, _ in
                    withAnimation {
                        if viewModel.isLoading {
                            proxy.scrollTo("loading", anchor: .bottom)
                        } else if let lastMessage = viewModel.currentConversation?.messages
                            .sorted(by: { $0.timestamp < $1.timestamp }).last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("閉じる") {
                        viewModel.errorMessage = nil
                    }
                    .font(.caption)
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

            inputBar
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if showVoiceInput {
                voiceInputSection
            }

            HStack(spacing: 12) {
                Button {
                    showVoiceInput.toggle()
                } label: {
                    Image(systemName: showVoiceInput ? "keyboard" : "mic.fill")
                        .font(.title3)
                        .foregroundStyle(showVoiceInput ? .indigo : .secondary)
                }

                TextField("メッセージを入力...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(10)
                    #if os(macOS)
                    .background(Color(nsColor: .controlBackgroundColor))
                    #else
                    .background(Color(.systemGray6))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .indigo)
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private var voiceInputSection: some View {
        VStack(spacing: 8) {
            if !speechService.transcribedText.isEmpty {
                Text(speechService.transcribedText)
                    .font(.subheadline)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    #if os(macOS)
                    .background(Color(nsColor: .controlBackgroundColor))
                    #else
                    .background(Color(.systemGray6))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button {
                    if speechService.isRecording {
                        speechService.stopRecording()
                        if !speechService.transcribedText.isEmpty {
                            viewModel.inputText = speechService.transcribedText
                        }
                    } else {
                        Task { await speechService.startRecording() }
                    }
                } label: {
                    Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(speechService.isRecording ? .red : .indigo)
                        .symbolEffect(.pulse, isActive: speechService.isRecording)
                }

                if !speechService.transcribedText.isEmpty && !speechService.isRecording {
                    Button("送信") {
                        Task {
                            await viewModel.sendVoiceMessage(speechService.transcribedText)
                            speechService.transcribedText = ""
                            showVoiceInput = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
            }
            .padding(.vertical, 4)

            if let error = speechService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    private var bubbleBackground: Color {
        if isUser {
            return .indigo
        }
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(.systemGray5)
        #endif
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if message.content.isEmpty {
                    Text("（応答なし）")
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .background(bubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(bubbleBackground)
                        .foregroundStyle(isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text(message.timestamp.shortTimeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.indigo.opacity(index <= dotCount ? 1 : 0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}

