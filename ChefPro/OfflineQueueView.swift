import SwiftUI

// MARK: - Offline Queue View (shows pending sync items)

struct OfflineStatusBanner: View {
    @EnvironmentObject var store: ChefProStore

    var body: some View {
        Group {
            if store.isOffline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                    Text("Офлайн — данные сохранятся при подключении")
                        .font(.caption)
                    Spacer()
                    if store.pendingSyncCount > 0 {
                        Text("\(store.pendingSyncCount) в очереди")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange)
                .foregroundStyle(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.isOffline)
    }
}

// MARK: - Network Monitor

import Network

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "chefpro.network")

    @Published var isConnected = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let connected = path.status == .satisfied
                self?.isConnected = connected
                NotificationCenter.default.post(name: .init("chefpro.networkChanged"), object: connected)
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
