import SwiftUI

// MARK: - Profile

struct ProfileView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showEditProfile = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 64, height: 64)
                        Text(String(store.profile.name.prefix(1)).uppercased())
                            .font(.title.bold())
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.profile.name).font(.title2).bold()
                        Text(store.profile.position).foregroundStyle(.secondary)
                        Text(store.profile.phone).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Права доступа") {
                ForEach(store.profile.permissions, id: \.self) { permission in
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text(permission)
                    }
                }
            }

            Section("Действия") {
                Button("Редактировать профиль") {
                    showEditProfile = true
                }

                Button("Выйти из аккаунта", role: .destructive) {
                    store.logout()
                }
            }
        }
        .navigationTitle("Профиль")
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(profile: store.profile) { updatedProfile in
                store.profile = updatedProfile
            }
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var position: String
    @State private var phone: String

    @State private var canTechCards: Bool
    @State private var canInventory: Bool
    @State private var canDeliveries: Bool
    @State private var canWriteOffs: Bool
    @State private var canReports: Bool
    @State private var canSettings: Bool

    var onSave: (UserProfile) -> Void

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _position = State(initialValue: profile.position)
        _phone = State(initialValue: profile.phone)
        _canTechCards = State(initialValue: profile.permissions.contains("Техкарты"))
        _canInventory = State(initialValue: profile.permissions.contains("Склад"))
        _canDeliveries = State(initialValue: profile.permissions.contains("Приемка"))
        _canWriteOffs = State(initialValue: profile.permissions.contains("Списания"))
        _canReports = State(initialValue: profile.permissions.contains("Отчеты"))
        _canSettings = State(initialValue: profile.permissions.contains("Настройки"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Данные профиля") {
                    TextField("Имя", text: $name)
                    TextField("Должность", text: $position)
                    TextField("Телефон", text: $phone).keyboardType(.phonePad)
                }

                Section("Права доступа") {
                    Toggle("Техкарты", isOn: $canTechCards)
                    Toggle("Склад", isOn: $canInventory)
                    Toggle("Приемка", isOn: $canDeliveries)
                    Toggle("Списания", isOn: $canWriteOffs)
                    Toggle("Отчеты", isOn: $canReports)
                    Toggle("Настройки", isOn: $canSettings)
                }
            }
            .navigationTitle("Редактировать профиль")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        var permissions: [String] = []
                        if canTechCards { permissions.append("Техкарты") }
                        if canInventory { permissions.append("Склад") }
                        if canDeliveries { permissions.append("Приемка") }
                        if canWriteOffs { permissions.append("Списания") }
                        if canReports { permissions.append("Отчеты") }
                        if canSettings { permissions.append("Настройки") }

                        onSave(UserProfile(name: name, position: position, phone: phone, permissions: permissions))
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showResetAlert = false
    @State private var restaurantNameInput = ""

    var body: some View {
        Form {
            Section("Ресторан") {
                HStack {
                    Text("Название")
                    Spacer()
                    TextField("Название ресторана", text: $restaurantNameInput)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .onSubmit { store.restaurantName = restaurantNameInput.trimmingCharacters(in: .whitespaces).isEmpty ? "Demo Restaurant" : restaurantNameInput }
                }
                Text("Приложение: ChefPro")
                Text("Версия: 1.0 MVP")
            }
            .onAppear { restaurantNameInput = store.restaurantName }

            Section("Текущий пользователь") {
                Text("Имя: \(store.profile.name)")
                Text("Должность: \(store.profile.position)")
                Text("Телефон: \(store.profile.phone)")
            }

            Section("Права") {
                ForEach(store.profile.permissions, id: \.self) { permission in
                    Text(permission)
                }
            }

            Section("Облачная синхронизация") {
                if store.isSyncing {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Синхронизация…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if let date = store.lastSyncDate {
                        Label(
                            "Синхронизировано: \(date.formatted(date: .abbreviated, time: .shortened))",
                            systemImage: "checkmark.icloud"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Label("Нет данных в облаке", systemImage: "icloud.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let err = store.syncError {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await store.syncToCloud() }
                    } label: {
                        Label("Выгрузить в облако", systemImage: "icloud.and.arrow.up")
                    }

                    Button {
                        Task { await store.syncFromCloud() }
                    } label: {
                        Label("Загрузить из облака", systemImage: "icloud.and.arrow.down")
                    }
                }
            }

            Section("Внешний вид") {
                Picker("Тема оформления", selection: $store.appColorScheme) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Язык / Language", selection: $store.appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                if store.appLanguage == .english {
                    Text("English mode: main navigation labels switch to English. Full localization coming soon.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Уведомления") {
                Toggle(isOn: Binding(
                    get: { store.notificationsEnabled },
                    set: { on in
                        if on { store.requestNotificationPermission() }
                        else  { store.notificationsEnabled = false }
                    }
                )) {
                    Label("Уведомления о низких остатках", systemImage: "bell.badge.fill")
                }

                if store.notificationsEnabled {
                    Toggle(isOn: $store.dailyDigestEnabled) {
                        Label("Утренний дайджест (8:00)", systemImage: "sun.max.fill")
                    }

                    Stepper("Предупреждение о сроке: \(store.expiryWarningDays) дн.",
                            value: $store.expiryWarningDays, in: 1...30)

                    if !store.lowStockItems.isEmpty || !store.expiringItems.isEmpty {
                        Button {
                            store.scheduleNotificationsForLowStock()
                        } label: {
                            Label("Отправить уведомления сейчас", systemImage: "bell.and.waves.left.and.right")
                        }
                    }

                    Divider()
                    Toggle(isOn: $store.haccpRemindersEnabled) {
                        Label("HACCP: напоминания о температуре", systemImage: "thermometer.medium")
                    }
                    if store.haccpRemindersEnabled {
                        Stepper("Интервал: \(store.haccpIntervalHours) ч",
                                value: $store.haccpIntervalHours, in: 1...12)
                    }
                }
            }

            Section("Бюджет закупок") {
                HStack {
                    Text("Бюджет в месяц")
                    Spacer()
                    TextField("0", value: $store.purchaseBudget, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                if store.purchaseBudget > 0 {
                    let spent = store.deliveries.filter {
                        Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
                    }.reduce(0.0) { $0 + $1.price }
                    let pct = min(spent / store.purchaseBudget, 1.0)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Потрачено: \(String(format: "%.2f", spent))")
                            Spacer()
                            Text("\(Int(pct * 100))%").foregroundStyle(pct > 0.9 ? .red : pct > 0.7 ? .orange : .green)
                        }
                        .font(.caption)
                        ProgressView(value: pct).tint(pct > 0.9 ? .red : pct > 0.7 ? .orange : .chefAccent)
                    }
                }
            }

            Section("Food Cost") {
                HStack {
                    Text("Порог Food Cost")
                    Spacer()
                    Text("\(Int(store.foodCostThreshold))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $store.foodCostThreshold, in: 10...60, step: 1)
                    .tint(.chefAccent)
                Text("Блюда с FC выше \(Int(store.foodCostThreshold))% отмечаются красным.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Данные") {
                Button("Сбросить демо-данные", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .navigationTitle("Настройки")
        .alert("Сбросить данные?", isPresented: $showResetAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) {
                store.resetDemoData()
            }
        } message: {
            Text("Все текущие данные будут заменены демо-данными.")
        }
    }
}
