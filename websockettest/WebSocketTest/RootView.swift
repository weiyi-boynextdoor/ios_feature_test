import SwiftUI

struct RootView: View {
    @State private var service: WebSocketService?
    @State private var isConnected = false
    @State private var connectedEndpoint = ""

    var body: some View {
        NavigationStack {
            LoginView { connectedService, endpoint in
                service = connectedService
                connectedEndpoint = endpoint
                isConnected = true
            }
            .navigationDestination(isPresented: $isConnected) {
                if let service {
                    ChatView(service: service, endpoint: connectedEndpoint)
                }
            }
        }
    }
}
