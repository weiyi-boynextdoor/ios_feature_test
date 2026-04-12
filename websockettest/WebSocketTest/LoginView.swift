import SwiftUI

struct LoginView: View {
    var onConnected: (WebSocketService, String) -> Void

    @State private var ip: String
    @State private var port: String
    @State private var isConnecting = false
    @State private var errorMessage = ""

    init(onConnected: @escaping (WebSocketService, String) -> Void) {
        self.onConnected = onConnected

        let defaults = UserDefaults.standard
        _ip = State(initialValue: defaults.string(forKey: StorageKeys.hostIP) ?? "127.0.0.1")
        _port = State(initialValue: defaults.string(forKey: StorageKeys.port) ?? "8024")
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Chat Login")
                    .font(.largeTitle.bold())

                Text("Connect to your WebSocket chat server.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                LabeledTextField(title: "IP", placeholder: "127.0.0.1", text: $ip)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.decimalPad)

                LabeledTextField(title: "PORT", placeholder: "8080", text: $port)
                    .keyboardType(.numberPad)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                connect()
            } label: {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(isConnecting ? "Connecting" : "Connect")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConnecting)

            Spacer()
            Spacer()
        }
        .padding(24)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Login")
    }

    private func connect() {
        isConnecting = true
        errorMessage = ""

        Task {
            let service = WebSocketService()

            do {
                let endpoint = try await service.connect(ip: ip, port: port)
                let connectedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                let connectedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    UserDefaults.standard.set(connectedIP, forKey: StorageKeys.hostIP)
                    UserDefaults.standard.set(connectedPort, forKey: StorageKeys.port)
                    ip = connectedIP
                    port = connectedPort
                    isConnecting = false
                    onConnected(service, endpoint)
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private enum StorageKeys {
    static let hostIP = "webSocketTest.hostIP"
    static let port = "webSocketTest.port"
}

private struct LabeledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
