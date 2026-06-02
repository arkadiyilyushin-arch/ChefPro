import SwiftUI
import Speech
import AVFoundation

// MARK: - Voice Input Helper

@MainActor
final class VoiceInputController: ObservableObject {
    @Published var isRecording = false
    @Published var transcript  = ""
    @Published var error: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    func toggle(locale: Locale = Locale(identifier: "ru-RU")) {
        isRecording ? stop() : start(locale: locale)
    }

    private func start(locale: Locale) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self, status == .authorized else {
                Task { @MainActor in self?.error = "Нет разрешения на распознавание речи" }
                return
            }
            Task { @MainActor in self.beginSession(locale: locale) }
        }
    }

    private func beginSession(locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
        request    = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let node   = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
            request.append(buf)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            try engine.start()
        } catch {
            self.error = error.localizedDescription; return
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, err in
            guard let self else { return }
            if let result { Task { @MainActor in self.transcript = result.bestTranscription.formattedString } }
            if err != nil { Task { @MainActor in self.stop() } }
        }
        isRecording = true
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil; task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Write Offs

struct WriteOffsView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAddWriteOff = false

    var body: some View {
        Group {
            if store.writeOffs.isEmpty {
                ScrollView {
                    EmptyStateView(icon: "trash", title: "Списаний пока нет", subtitle: "Добавь первое списание продукта.")
                        .padding(.vertical)
                }
            } else {
                List {
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
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.writeOffs.removeAll { $0.id == item.id }
                            } label: { Label("Удалить", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color.chefBackground)
            }
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
                .environmentObject(store)
        }
    }
}

struct AddWriteOffView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss
    @State private var productName     = ""
    @State private var quantity        = ""
    @State private var unit            = "кг"
    @State private var reason          = "Порча"
    @State private var employee        = ""
    @State private var showSuggestions = false
    @StateObject private var voice     = VoiceInputController()

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
                    HStack {
                        TextField("Название продукта", text: $productName)
                            .onChange(of: productName) { _, _ in
                                showSuggestions = !productName.trimmingCharacters(in: .whitespaces).isEmpty
                            }
                        Button {
                            voice.toggle()
                        } label: {
                            Image(systemName: voice.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title3)
                                .foregroundStyle(voice.isRecording ? .red : .chefAccent)
                        }
                        .buttonStyle(.plain)
                    }
                    .onChange(of: voice.transcript) { _, text in
                        guard !text.isEmpty else { return }
                        productName = text
                        showSuggestions = true
                        if !voice.isRecording { voice.transcript = "" }
                    }
                    if voice.isRecording {
                        Label("Говорите…", systemImage: "waveform")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    InventoryProductSuggestions(query: productName, show: $showSuggestions) { item in
                        productName = item.name
                        unit        = item.unit
                        // Pre-fill quantity with current stock so user can adjust
                        if quantity.isEmpty {
                            quantity = String(format: "%.1f", item.quantity)
                        }
                    }
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
        .onAppear { if employee.isEmpty { employee = store.profile.name } }
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
    @State private var editMode: EditMode = .inactive
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
                    List {
                        ForEach(store.currentProductionPlan) { item in
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
                                Text("\(item.portions) порц.")
                                    .font(.title3.bold()).foregroundStyle(.chefAccent)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.removePlanItem(item)
                                } label: { Label("Удалить", systemImage: "trash") }
                            }
                        }
                        .onMove { from, to in
                            store.currentProductionPlan.move(fromOffsets: from, toOffset: to)
                        }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: CGFloat(store.currentProductionPlan.count) * 72)
                    .environment(\.editMode, $editMode)
                    .onAppear { editMode = .active }

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
    @State private var actualWeight = ""
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
                        HStack {
                            Label("Фактический выход", systemImage: "scalemass")
                                .font(.subheadline)
                            Spacer()
                            TextField("0", text: $actualWeight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("г").foregroundStyle(.secondary)
                        }
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
                        if ok {
                            if let w = Double(actualWeight.replacingOccurrences(of: ",", with: ".")), w > 0 {
                                if let idx = store.productions.indices.last {
                                    store.productions[idx].actualPortionWeight = w
                                }
                            }
                        }
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

    private func haccpViolation(log: TemperatureLog) -> Bool {
        let loc = log.location.lowercased()
        if loc.contains("холод") { return log.temperature > 8 }
        if loc.contains("горяч") { return log.temperature < 60 }
        if loc.contains("морозил") { return log.temperature > -15 }
        return false
    }

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
                            let isHACCP = haccpViolation(log: log)
                            BigCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            if isHACCP {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundStyle(.red)
                                                    .font(.caption)
                                            }
                                            Text(log.location).font(.headline)
                                        }
                                        Text(log.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                        if !log.recordedBy.isEmpty {
                                            Text("Записал: \(log.recordedBy)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        if !log.notes.isEmpty {
                                            Text(log.notes).font(.caption).foregroundStyle(.secondary)
                                        }
                                        if isHACCP {
                                            Text("⚠ Нарушение ХАССП")
                                                .font(.caption.bold())
                                                .foregroundStyle(.red)
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
                            .background(isHACCP ? Color.red.opacity(0.05) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
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
    @State private var showViolationAlert = false
    @State private var pendingLog: TemperatureLog? = nil
    @State private var showShareSheet = false
    @State private var haccpPDFURL: URL? = nil
    let presetLocations = ["Холодильник 1", "Холодильник 2", "Морозильник", "Горячее хранение", "Холодильник для напитков"]

    var finalLocation: String { useCustom ? customLocation : location }

    func isHACCPViolation(location: String, temperature: Double) -> Bool {
        let loc = location.lowercased()
        if loc.contains("холод") { return temperature > 8 }
        if loc.contains("горяч") { return temperature < 60 }
        if loc.contains("морозил") { return temperature > -15 }
        return false
    }

    func allowedRangeDescription(location: String) -> String {
        let loc = location.lowercased()
        if loc.contains("холод") { return "0°C … +8°C" }
        if loc.contains("горяч") { return "+60°C … +75°C" }
        if loc.contains("морозил") { return "-25°C … -15°C" }
        return "согласно норме"
    }

    func generateHACCPAct(log: TemperatureLog) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let fileName = "HACCP_Act_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y: CGFloat = 40

                func drawText(_ text: String, size: CGFloat = 12, bold: Bool = false, x: CGFloat = 40, color: UIColor = .black) {
                    let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                    let maxWidth: CGFloat = 515
                    _ = CGRect(x: x, y: y, width: maxWidth, height: 400)
                    let str = NSString(string: text)
                    let boundingSize = str.boundingRect(with: CGSize(width: maxWidth, height: 400),
                                                        options: .usesLineFragmentOrigin,
                                                        attributes: attrs, context: nil).size
                    str.draw(in: CGRect(x: x, y: y, width: maxWidth, height: boundingSize.height + 4), withAttributes: attrs)
                    y += boundingSize.height + 6
                }

                func drawLine() {
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: 40, y: y))
                    path.addLine(to: CGPoint(x: 555, y: y))
                    UIColor.lightGray.setStroke()
                    path.lineWidth = 0.5
                    path.stroke()
                    y += 10
                }

                drawText("АКТ ХАССП — Нарушение температурного режима", size: 18, bold: true)
                y += 4
                drawLine()
                drawText(store.restaurantName, size: 13, bold: true)
                y += 8

                drawText("Дата составления: \(log.recordedAt.formatted(date: .long, time: .omitted))", size: 12)
                drawText("Время фиксации: \(log.recordedAt.formatted(date: .omitted, time: .shortened))", size: 12)
                drawText("Место хранения: \(log.location)", size: 12)
                drawText("Измеренная температура: \(String(format: "%.1f", log.temperature))°C", size: 13, bold: true, color: .systemRed)
                drawText("Допустимый диапазон: \(allowedRangeDescription(location: log.location))", size: 12)
                drawText("Ответственный сотрудник: \(log.recordedBy.isEmpty ? store.profile.name : log.recordedBy)", size: 12)
                if !log.notes.isEmpty {
                    drawText("Примечание: \(log.notes)", size: 12)
                }
                y += 10
                drawLine()

                drawText("Продукты, подлежащие списанию:", size: 14, bold: true)
                y += 4

                let locationLower = log.location.lowercased()
                let categoryKeyword: String
                if locationLower.contains("морозил") {
                    categoryKeyword = "заморо"
                } else if locationLower.contains("горяч") {
                    categoryKeyword = "горяч"
                } else {
                    categoryKeyword = ""
                }

                let suggestedItems = categoryKeyword.isEmpty ? [] : store.inventoryItems.filter {
                    $0.category.lowercased().contains(categoryKeyword) || $0.name.lowercased().contains(categoryKeyword)
                }

                if suggestedItems.isEmpty {
                    for _ in 0..<6 {
                        drawText("_______________________________________________________   количество: ____________", size: 11)
                        y += 2
                    }
                } else {
                    for item in suggestedItems.prefix(8) {
                        drawText("• \(item.name)   (\(String(format: "%.2f", item.quantity)) \(item.unit))  → кол-во к списанию: ____________", size: 11)
                        y += 2
                    }
                    for _ in suggestedItems.count..<max(suggestedItems.count, 3) {
                        drawText("_______________________________________________________   количество: ____________", size: 11)
                        y += 2
                    }
                }

                y += 12
                drawLine()
                drawText("Ответственный: ___________________________________________", size: 12)
                y += 8
                drawText("Подпись: _______________    Дата: _______________", size: 12)
                y += 20
                drawText("Акт составлен автоматически системой ChefPro", size: 10, color: .gray)
            }
            return url
        } catch {
            return nil
        }
    }

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
                        if isHACCPViolation(location: finalLocation, temperature: t) {
                            pendingLog = log
                            showViolationAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(Double(temperature.replacingOccurrences(of: ",", with: ".")) == nil ||
                              finalLocation.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Нарушение температурного режима!", isPresented: $showViolationAlert) {
                Button("Создать акт списания") {
                    if let log = pendingLog, let url = generateHACCPAct(log: log) {
                        haccpPDFURL = url
                        showShareSheet = true
                    } else {
                        dismiss()
                    }
                }
                Button("Пропустить", role: .cancel) { dismiss() }
            } message: {
                if let log = pendingLog {
                    Text("Температура \(String(format: "%.1f", log.temperature))°C в «\(log.location)» выходит за допустимые пределы (\(allowedRangeDescription(location: log.location))). Создать акт ХАССП для списания продуктов?")
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { dismiss() }) {
                if let url = haccpPDFURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}
