import Foundation

enum WebSocketError: LocalizedError {
    case invalidEndpoint
    case missingConnection
    case disconnected

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Enter a valid IP and port."
        case .missingConnection:
            return "Connect to the chat server first."
        case .disconnected:
            return "The chat server disconnected."
        }
    }
}

final class WebSocketService: NSObject, ObservableObject {
    private var task: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    func connect(ip: String, port: String) async throws -> String {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedIP.isEmpty,
              !trimmedPort.isEmpty,
              var components = URLComponents(string: "ws://\(trimmedIP):\(trimmedPort)/ws")
        else {
            throw WebSocketError.invalidEndpoint
        }

        components.path = components.path.isEmpty ? "/" : components.path

        guard let url = components.url else {
            throw WebSocketError.invalidEndpoint
        }

        disconnect()

        let nextTask = session.webSocketTask(with: url)
        task = nextTask
        nextTask.resume()

        return url.absoluteString
    }

    func send(_ text: String) async throws {
        guard let task else {
            throw WebSocketError.missingConnection
        }

        try await task.send(.string(text))
    }

    func receive() async throws -> String {
        guard let task else {
            throw WebSocketError.missingConnection
        }

        let message = try await task.receive()
        switch message {
        case .string(let text):
            return text
        case .data(let data):
            return String(decoding: data, as: UTF8.self)
        @unknown default:
            return ""
        }
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    deinit {
        disconnect()
        session.invalidateAndCancel()
    }
}

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        if task === webSocketTask {
            task = nil
        }
    }
}
