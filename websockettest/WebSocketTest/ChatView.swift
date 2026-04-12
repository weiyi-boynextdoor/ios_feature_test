import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    enum Sender {
        case user
        case bot
        case system
    }

    let id = UUID()
    let sender: Sender
    let text: String
    let timestamp = Date()
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(sender: .system, text: "Connected. Say hello to the chatbot here.")
    ]
    @Published var draft = ""
    @Published var connectionStatus = "Online"

    private let service: WebSocketService
    private var receiveTask: Task<Void, Never>?

    init(service: WebSocketService) {
        self.service = service
        startReceiving()
    }

    func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(sender: .user, text: text))
        draft = ""

        Task {
            do {
                try await service.send(text)
            } catch {
                messages.append(ChatMessage(sender: .system, text: error.localizedDescription))
                connectionStatus = "Offline"
            }
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        service.disconnect()
        connectionStatus = "Offline"
    }

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    let text = try await service.receive()
                    guard !text.isEmpty else { continue }

                    messages.append(ChatMessage(sender: .bot, text: text))
                } catch {
                    if !Task.isCancelled {
                        messages.append(ChatMessage(sender: .system, text: error.localizedDescription))
                        connectionStatus = "Offline"
                    }
                    break
                }
            }
        }
    }
}

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatViewModel
    let endpoint: String

    init(service: WebSocketService, endpoint: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(service: service))
        self.endpoint = endpoint
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground))
                .onChange(of: viewModel.messages) { _, messages in
                    guard let lastID = messages.last?.id else { return }

                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }

            composer
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    viewModel.disconnect()
                    dismiss()
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Chatbot")
                .font(.headline)

            Text("\(viewModel.connectionStatus) - \(endpoint)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                viewModel.sendMessage()
            } label: {
                Text("Send")
                    .fontWeight(.semibold)
                    .frame(minWidth: 56, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .user {
                Spacer(minLength: 42)
            } else if message.sender == .bot {
                avatar("C", color: .green)
            }

            Text(message.text)
                .font(.body)
                .foregroundStyle(message.sender == .user ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: 280, alignment: message.sender == .user ? .trailing : .leading)

            if message.sender == .bot {
                Spacer(minLength: 42)
            } else if message.sender == .user {
                avatar("Me", color: .blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch message.sender {
        case .user:
            return .trailing
        case .bot, .system:
            return .leading
        }
    }

    private var backgroundColor: Color {
        switch message.sender {
        case .user:
            return Color.green
        case .bot:
            return Color(.systemBackground)
        case .system:
            return Color(.tertiarySystemGroupedBackground)
        }
    }

    private func avatar(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
