import SwiftUI

// MARK: - App Root

struct ContentView: View {
    @StateObject private var store = ChefProStore()

    var body: some View {
        Group {
            if store.isLoggedIn {
                MainAppView()
                    .environmentObject(store)
            } else {
                LoginView()
                    .environmentObject(store)
            }
        }
        .tint(.chefAccent)
        .preferredColorScheme(store.appColorScheme.colorScheme)
    }
}

struct MainAppView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            DashboardView()
                .environmentObject(store)
                .tabItem { Label(store.appLanguage == .english ? "Home" : "Главная", systemImage: "house.fill") }

            PermissionGate(permission: "Техкарты") {
                TechCardsView()
            }
            .environmentObject(store)
            .tabItem { Label(store.appLanguage == .english ? "Recipes" : "Техкарты", systemImage: "book.fill") }

            PermissionGate(permission: "Склад") {
                InventoryView()
            }
            .environmentObject(store)
            .tabItem { Label(store.appLanguage == .english ? "Inventory" : "Склад", systemImage: "shippingbox.fill") }

            PermissionGate(permission: "Приемка") {
                DeliveriesView()
            }
            .environmentObject(store)
            .tabItem { Label(store.appLanguage == .english ? "Deliveries" : "Приемка", systemImage: "tray.and.arrow.down.fill") }

            MoreView()
                .environmentObject(store)
                .tabItem { Label(store.appLanguage == .english ? "More" : "Еще", systemImage: "ellipsis.circle.fill") }
        }
        .onAppear {
            if !store.hasSeenOnboarding { showOnboarding = true }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onFinish: {
                store.hasSeenOnboarding = true
                showOnboarding = false
            })
            .environmentObject(store)
        }
    }
}

struct PermissionGate<Content: View>: View {
    @EnvironmentObject var store: ChefProStore
    let permission: String
    let content: () -> Content

    var body: some View {
        if store.hasPermission(permission) {
            content()
        } else {
            NoAccessView(permission: permission)
        }
    }
}

struct NoAccessView: View {
    let permission: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                Text("Нет доступа")
                    .font(.largeTitle)
                    .bold()
                Text("Для раздела \"\(permission)\" нужно выдать право доступа.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(permission)
        }
    }
}

#Preview {
    ContentView()
}
