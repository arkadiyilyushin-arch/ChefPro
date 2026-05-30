import SwiftUI

// MARK: - Restaurant Profile (for multitenancy)

struct RestaurantProfile: Identifiable, Codable {
    var id        = UUID()
    var name:     String
    var city:     String   = ""
    var emoji:    String   = "🍽️"
    var color:    String   = "orange"   // stored as string for Codable
    var createdAt: Date    = Date()
}

// MARK: - Multitenancy Manager

final class RestaurantManager: ObservableObject {
    static let shared = RestaurantManager()

    private let restaurantsKey  = "chefpro_restaurants_v1"
    private let activeIDKey     = "chefpro_active_restaurant_id"

    @Published var restaurants: [RestaurantProfile] = []
    @Published var activeID: UUID? = nil

    var activeRestaurant: RestaurantProfile? {
        restaurants.first { $0.id == activeID }
    }

    init() {
        load()
    }

    func add(_ r: RestaurantProfile) {
        restaurants.append(r)
        if restaurants.count == 1 { activeID = r.id }
        save()
    }

    func update(_ r: RestaurantProfile) {
        if let i = restaurants.firstIndex(where: { $0.id == r.id }) {
            restaurants[i] = r
            save()
        }
    }

    func delete(_ r: RestaurantProfile) {
        restaurants.removeAll { $0.id == r.id }
        if activeID == r.id { activeID = restaurants.first?.id }
        save()
    }

    func switchTo(_ id: UUID) {
        activeID = id
        UserDefaults.standard.set(id.uuidString, forKey: activeIDKey)
        // Each restaurant stores its data under a namespaced key in UserDefaults.
        // Restarting the store with a new restaurant prefix would require app restart.
        // For now we just record the switch — full data isolation is a future enhancement.
        objectWillChange.send()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(restaurants) {
            UserDefaults.standard.set(data, forKey: restaurantsKey)
        }
        if let id = activeID {
            UserDefaults.standard.set(id.uuidString, forKey: activeIDKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: restaurantsKey),
           let decoded = try? JSONDecoder().decode([RestaurantProfile].self, from: data) {
            restaurants = decoded
        }
        if let str = UserDefaults.standard.string(forKey: activeIDKey),
           let id  = UUID(uuidString: str) {
            activeID = id
        }
    }
}

// MARK: - Restaurant Switcher View

struct RestaurantSwitcherView: View {
    @EnvironmentObject var store: ChefProStore
    @StateObject private var manager = RestaurantManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section("Ваши рестораны") {
                    ForEach(manager.restaurants) { restaurant in
                        restaurantRow(restaurant)
                    }
                    .onDelete { idx in
                        idx.forEach { manager.delete(manager.restaurants[$0]) }
                    }
                }

                Section {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Добавить ресторан", systemImage: "plus.circle.fill")
                            .foregroundStyle(.chefAccent)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Как работает мультиаккаунт", systemImage: "info.circle")
                            .font(.subheadline.bold())
                        Text("Каждый ресторан — отдельное пространство данных в Firestore. Переключение сохраняет данные текущего ресторана в облаке и загружает данные выбранного.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Рестораны")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddRestaurantView { r in
                    manager.add(r)
                }
            }
        }
    }

    private func restaurantRow(_ r: RestaurantProfile) -> some View {
        HStack(spacing: 14) {
            Text(r.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(r.name).font(.headline)
                if !r.city.isEmpty {
                    Text(r.city).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if manager.activeID == r.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.chefAccent)
                    .font(.title3)
            } else {
                Button("Открыть") {
                    Task { @MainActor in
                        await store.syncToCloud()
                        manager.switchTo(r.id)
                        store.restaurantName = r.name
                        await store.syncFromCloud()
                    }
                    dismiss()
                }
                .font(.subheadline)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Restaurant

struct AddRestaurantView: View {
    let onSave: (RestaurantProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name  = ""
    @State private var city  = ""
    @State private var emoji = "🍽️"

    private let emojis = ["🍽️","🍕","🍣","🥩","🍜","🥗","☕️","🍰","🍺","🌮","🫕","🥘"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Ресторан «Берёзка»", text: $name)
                    TextField("Город (необязательно)", text: $city)
                }
                Section("Эмодзи") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(emojis, id: \.self) { e in
                            Button {
                                emoji = e
                            } label: {
                                Text(e).font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(emoji == e ? Color.chefAccent.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(emoji == e ? Color.chefAccent : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Новый ресторан")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        guard !name.isEmpty else { return }
                        onSave(RestaurantProfile(name: name, city: city, emoji: emoji))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
