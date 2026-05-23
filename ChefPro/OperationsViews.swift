import SwiftUI

// MARK: - Write Offs

struct WriteOffsView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAddWriteOff = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if store.writeOffs.isEmpty {
                    EmptyStateView(icon: "trash", title: "Списаний пока нет", subtitle: "Добавь первое списание продукта.")
                } else {
                    ForEach(store.writeOffs.reversed()) { item in
                        BigCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.productName).font(.title3).bold()
                                    Spacer()
                                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Причина: \(item.reason)")
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text("\(item.quantity, specifier: "%.1f") \(item.unit)")
                                        .font(.headline)
                                    Spacer()
                                    Text(item.employee)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.chefBackground)
        .navigationTitle("Списания")
        .toolbar {
            Button { showAddWriteOff = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
        }
        .sheet(isPresented: $showAddWriteOff) {
            AddWriteOffView { store.addWriteOff($0) }
        }
    }
}

struct AddWriteOffView: View {
    @Environment(\.dismiss) var dismiss
    @State private var productName = ""
    @State private var quantity = ""
    @State private var unit = "кг"
    @State private var reason = "Порча"
    @State private var employee = ""

    var onSave: (WriteOff) -> Void
    let units = ["кг", "г", "л", "мл", "шт"]
    let reasons = ["Порча", "Истек срок", "Ошибка приготовления", "Брак", "Другое"]

    private var canSave: Bool {
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        parsePositiveDouble(quantity) != nil &&
        !employee.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Продукт") {
                    TextField("Название продукта", text: $productName)
                    TextField("Количество", text: $quantity).keyboardType(.decimalPad)
                    Picker("Единица", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                }

                Section("Причина") {
                    Picker("Причина списания", selection: $reason) {
                        ForEach(reasons, id: \.self) { Text($0) }
                    }
                }

                Section("Сотрудник") {
                    TextField("Кто списал", text: $employee)
                }
            }
            .navigationTitle("Новое списание")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        let writeOff = WriteOff(
                            productName: productName,
                            quantity: parsePositiveDouble(quantity) ?? 0,
                            unit: unit,
                            reason: reason,
                            employee: employee,
                            date: Date()
                        )
                        onSave(writeOff)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Global Search

struct GlobalSearchView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var query = ""

    private var matchedDishes: [Dish] {
        guard !query.isEmpty else { return [] }
        return store.dishes.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query) ||
            $0.allergens.contains(where: { $0.localizedCaseInsensitiveContains(query) }) ||
            $0.ingredients.contains(where: { $0.productName.localizedCaseInsensitiveContains(query) })
        }
    }

    private var matchedItems: [InventoryItem] {
        guard !query.isEmpty else { return [] }
        return store.inventoryItems.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    private var matchedSuppliers: [Supplier] {
        guard !query.isEmpty else { return [] }
        return store.suppliers.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.phone.localizedCaseInsensitiveContains(query)
        }
    }

    private var matchedEmployees: [Employee] {
        guard !query.isEmpty else { return [] }
        return store.employees.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.position.localizedCaseInsensitiveContains(query)
        }
    }

    private var hasResults: Bool {
        !matchedDishes.isEmpty || !matchedItems.isEmpty || !matchedSuppliers.isEmpty || !matchedEmployees.isEmpty
    }

    var body: some View {
        List {
            if query.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "Поиск", subtitle: "Введите запрос для поиска по всем разделам.")
                    .listRowBackground(Color.clear)
            } else if !hasResults {
                EmptyStateView(icon: "questionmark.circle", title: "Ничего не найдено", subtitle: "Попробуйте другой запрос.")
                    .listRowBackground(Color.clear)
            } else {
                if !matchedDishes.isEmpty {
                    Section("Блюда (\(matchedDishes.count))") {
                        ForEach(matchedDishes) { dish in
                            NavigationLink {
                                DishDetailView(dish: dish).environmentObject(store)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(dish.name).font(.headline)
                                    Text(dish.category).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !matchedItems.isEmpty {
                    Section("Склад (\(matchedItems.count))") {
                        ForEach(matchedItems) { item in
                            NavigationLink {
                                InventoryDetailView(item: item).environmentObject(store)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name).font(.headline)
                                        Text(item.category).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(item.quantity, specifier: "%.1f") \(item.unit)")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !matchedSuppliers.isEmpty {
                    Section("Поставщики (\(matchedSuppliers.count))") {
                        ForEach(matchedSuppliers) { supplier in
                            NavigationLink {
                                SupplierDetailView(supplier: supplier).environmentObject(store)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(supplier.name).font(.headline)
                                    if !supplier.phone.isEmpty {
                                        Text(supplier.phone).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if !matchedEmployees.isEmpty {
                    Section("Сотрудники (\(matchedEmployees.count))") {
                        ForEach(matchedEmployees) { emp in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(emp.name).font(.headline)
                                    Text(emp.position).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if emp.id == store.currentEmployeeID {
                                    Text("Вы").font(.caption.bold()).foregroundStyle(.chefAccent)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Поиск")
        .searchable(text: $query, prompt: "Блюдо, продукт, поставщик…")
    }
}

// MARK: - Production Plan

struct ProductionPlanView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd = false
    @State private var showExecuteAlert = false
    @State private var executedCount = 0
    @State private var showExecutedBanner = false

    private var totalCost: Double {
        store.currentProductionPlan.reduce(0) { total, item in
            guard let dish = store.dishes.first(where: { $0.id == item.dishID }) else { return total }
            return total + store.calculateDishCost(dish) * Double(item.portions)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                BigCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("План производства", systemImage: "calendar.badge.clock").font(.headline)
                        Text("Сформируйте список блюд для производства. После выполнения ингредиенты спишутся со склада.")
                            .font(.caption).foregroundStyle(.secondary)
                        if !store.currentProductionPlan.isEmpty {
                            HStack {
                                Text("\(store.currentProductionPlan.count) позиций")
                                Spacer()
                                Text("~\(totalCost, specifier: "%.2f") себестоимость")
                                    .foregroundStyle(.chefAccent)
                            }
                            .font(.subheadline)
                        }
                    }
                }

                if showExecutedBanner {
                    BigCard {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
                            Text("Выполнено \(executedCount) из \(executedCount) позиций. Ингредиенты списаны.")
                                .font(.subheadline)
                        }
                    }
                }

                if store.currentProductionPlan.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "План пуст",
                        subtitle: "Добавьте блюда в план и нажмите «Выполнить»."
                    )
                } else {
                    ForEach(store.currentProductionPlan) { item in
                        BigCard {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.dishName).font(.headline)
                                    if let dish = store.dishes.first(where: { $0.id == item.dishID }) {
                                        Text("Себестоимость: \(store.calculateDishCost(dish) * Double(item.portions), specifier: "%.2f")")
                                            .font(.caption).foregroundStyle(.secondary)
                                        let canProduce = store.canProduce(dish: dish, portions: item.portions)
                                        Label(canProduce ? "Достаточно продуктов" : "Нехватка продуктов",
                                              systemImage: canProduce ? "checkmark.circle" : "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundStyle(canProduce ? Color.green : Color.orange)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("\(item.portions) порц.")
                                        .font(.title3.bold()).foregroundStyle(.chefAccent)
                                    Button {
                                        store.removePlanItem(item)
                                    } label: {
                                        Image(systemName: "trash").foregroundStyle(.red).font(.caption)
                                    }
                                }
                            }
                        }
                    }

                    BigActionButton(title: "Выполнить план", icon: "flame.fill") {
                        showExecuteAlert = true
                    }

                    Button(role: .destructive) {
                        store.clearProductionPlan()
                    } label: {
                        Label("Очистить план", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("План производства")
        .toolbar {
            Button { showAdd = true } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPlanItemView().environmentObject(store)
        }
        .alert("Выполнить план?", isPresented: $showExecuteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Выполнить") {
                executedCount = store.executeProductionPlan()
                withAnimation { showExecutedBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation { showExecutedBanner = false }
                }
            }
        } message: {
            Text("Ингредиенты всех блюд будут списаны со склада, производство записано.")
        }
    }
}

struct AddPlanItemView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDishID: UUID? = nil
    @State private var portions = 1

    private var canSave: Bool { selectedDishID != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Блюдо") {
                    Picker("Выберите блюдо", selection: $selectedDishID) {
                        Text("—").tag(Optional<UUID>.none)
                        ForEach(store.dishes) { dish in
                            Text(dish.name).tag(Optional(dish.id))
                        }
                    }
                }
                Section("Количество порций") {
                    Stepper("Порций: \(portions)", value: $portions, in: 1...999)
                }
                if let id = selectedDishID, let dish = store.dishes.first(where: { $0.id == id }) {
                    Section("Предварительно") {
                        Text("Себестоимость: \(store.calculateDishCost(dish) * Double(portions), specifier: "%.2f")")
                            .foregroundStyle(.chefAccent)
                        let ok = store.canProduce(dish: dish, portions: portions)
                        Label(ok ? "Продуктов достаточно" : "Нехватка продуктов",
                              systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(ok ? Color.green : Color.orange)
                    }
                }
            }
            .navigationTitle("В план")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        guard let id = selectedDishID,
                              let dish = store.dishes.first(where: { $0.id == id }) else { return }
                        store.addPlanItem(PlanItem(dishID: dish.id, dishName: dish.name, portions: portions))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Quick Produce

struct QuickProduceView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDishID: UUID? = nil
    @State private var portions = 1
    @State private var showError   = false
    @State private var showSuccess = false

    private var selectedDish: Dish? {
        store.dishes.first { $0.id == selectedDishID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Блюдо") {
                    Picker("Выберите блюдо", selection: $selectedDishID) {
                        Text("—").tag(Optional<UUID>.none)
                        ForEach(store.dishes.sorted { $0.isFavorite && !$1.isFavorite }) { dish in
                            HStack {
                                if dish.isFavorite { Text("⭐") }
                                Text(dish.name)
                            }.tag(Optional(dish.id))
                        }
                    }
                }

                if let dish = selectedDish {
                    Section("Количество") {
                        Stepper("Порций: \(portions)", value: $portions, in: 1...100)
                        Text("Себестоимость: \(store.calculateDishCost(dish) * Double(portions), specifier: "%.2f")")
                            .foregroundStyle(.chefAccent)
                    }

                    Section("Будет списано") {
                        ForEach(dish.ingredients) { ing in
                            HStack {
                                Text(ing.productName)
                                Spacer()
                                let needed = ing.quantity * Double(portions)
                                let hasStock = store.inventoryItems.first(where: {
                                    $0.name.lowercased() == ing.productName.lowercased()
                                }).map { store.convert(quantity: needed, from: ing.unit, to: $0.unit) <= $0.quantity } ?? false
                                Text("\(needed, specifier: "%.1f") \(ing.unit)")
                                    .foregroundStyle(hasStock ? Color.primary : Color.red)
                            }
                        }
                    }
                }

                if showError {
                    Section {
                        Label("Недостаточно продуктов на складе.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                if showSuccess {
                    Section {
                        Label("Готово! Ингредиенты списаны.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Быстрое производство")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Списать") {
                        guard let dish = selectedDish else { return }
                        let ok = store.produceDish(dish, portions: portions)
                        showError = !ok; showSuccess = ok
                        if ok { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() } }
                    }
                    .disabled(selectedDish == nil)
                }
            }
        }
    }
}

// MARK: - Temperature Log

struct TemperatureLogView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd = false

    private var locations: [String] {
        Array(Set(store.temperatureLogs.map { $0.location } + ["Холодильник 1", "Морозильник"])).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Dashboard cards per location
                if !store.temperatureLogs.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(locations, id: \.self) { loc in
                            if let latest = store.latestLog(for: loc) {
                                BigCard {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(loc).font(.caption).foregroundStyle(.secondary)
                                        Text("\(latest.temperature, specifier: "%.1f")°C")
                                            .font(.title2.bold())
                                            .foregroundStyle(latest.statusColor)
                                        Text(latest.statusLabel).font(.caption).foregroundStyle(latest.statusColor)
                                        Text(latest.recordedAt.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                SectionTitle(title: "История записей").padding(.horizontal)

                if store.temperatureLogs.isEmpty {
                    EmptyStateView(icon: "thermometer", title: "Нет записей",
                                   subtitle: "Добавьте первую запись температуры")
                        .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(store.temperatureLogs) { log in
                            BigCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(log.location).font(.headline)
                                        Text(log.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                        if !log.recordedBy.isEmpty {
                                            Text("Записал: \(log.recordedBy)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        if !log.notes.isEmpty {
                                            Text(log.notes).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(log.temperature, specifier: "%.1f")°C")
                                            .font(.title3.bold())
                                            .foregroundStyle(log.statusColor)
                                        Text(log.statusLabel)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(log.statusColor.opacity(0.15))
                                            .foregroundStyle(log.statusColor)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteTemperatureLog(log)
                                } label: { Label("Удалить", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.chefBackground)
        .navigationTitle("Температурный журнал")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTemperatureLogView().environmentObject(store)
        }
    }
}

struct AddTemperatureLogView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss
    @State private var location = "Холодильник 1"
    @State private var customLocation = ""
    @State private var useCustom = false
    @State private var temperature = ""
    @State private var notes = ""
    let presetLocations = ["Холодильник 1", "Холодильник 2", "Морозильник", "Холодильник для напитков"]

    var finalLocation: String { useCustom ? customLocation : location }

    var body: some View {
        NavigationStack {
            Form {
                Section("Место измерения") {
                    Toggle("Другое место", isOn: $useCustom)
                    if useCustom {
                        TextField("Название места", text: $customLocation)
                    } else {
                        Picker("Место", selection: $location) {
                            ForEach(presetLocations, id: \.self) { Text($0) }
                        }
                    }
                }
                Section("Температура") {
                    HStack {
                        TextField("Например: -18", text: $temperature)
                            .keyboardType(.numbersAndPunctuation)
                        Text("°C").foregroundStyle(.secondary)
                    }
                    if let t = Double(temperature.replacingOccurrences(of: ",", with: ".")) {
                        let fakeLog = TemperatureLog(location: "", temperature: t)
                        HStack {
                            Image(systemName: fakeLog.isCritical ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            Text(fakeLog.statusLabel)
                        }
                        .foregroundStyle(fakeLog.statusColor)
                        .font(.caption)
                    }
                }
                Section("Дополнительно") {
                    TextField("Заметка (опционально)", text: $notes)
                }
            }
            .navigationTitle("Новая запись")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        guard let t = Double(temperature.replacingOccurrences(of: ",", with: ".")),
                              !finalLocation.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let log = TemperatureLog(location: finalLocation, temperature: t,
                                                 recordedBy: store.profile.name, notes: notes)
                        store.addTemperatureLog(log)
                        if log.isCritical {
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.warning)
                        }
                        dismiss()
                    }
                    .disabled(Double(temperature.replacingOccurrences(of: ",", with: ".")) == nil ||
                              finalLocation.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
