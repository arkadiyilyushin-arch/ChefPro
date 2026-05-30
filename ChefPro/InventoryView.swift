import SwiftUI
import Charts

// MARK: - Inventory Sort Order

enum InventorySortOrder: String, CaseIterable {
    case name     = "Название"
    case quantity = "Количество"
    case price    = "Цена"
    case lowStock = "Критические"
}

// MARK: - Inventory

struct InventoryView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAddItem  = false
    @State private var showAudit    = false
    @State private var searchText = ""
    @State private var selectedCategory = "Все"
    @State private var showOnlyLowStock = false
    @State private var sortOrder: InventorySortOrder = .name

    var categories: [String] {
        ["Все"] + store.inventoryCategories
    }

    var filteredItems: [InventoryItem] {
        var items = store.inventoryItems
        if selectedCategory != "Все" { items = items.filter { $0.category == selectedCategory } }
        if showOnlyLowStock { items = items.filter { $0.isLowStock } }
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .name:     items.sort { $0.name < $1.name }
        case .quantity: items.sort { $0.quantity < $1.quantity }
        case .price:    items.sort { $0.pricePerUnit > $1.pricePerUnit }
        case .lowStock: items.sort {
            let a = $0.minQuantity > 0 && $0.quantity <= $0.minQuantity
            let b = $1.minQuantity > 0 && $1.quantity <= $1.minQuantity
            return a && !b
        }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button { selectedCategory = cat } label: {
                                Text(cat)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == cat ? Color.chefAccent : Color(.systemGray5))
                                    .foregroundStyle(selectedCategory == cat ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                Toggle(isOn: $showOnlyLowStock) {
                    Label("Только заканчивается", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                }
                .padding()
                .background(Color.chefCard)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)
                .padding(.bottom, 8)

                if filteredItems.isEmpty {
                    if store.inventoryItems.isEmpty {
                        EmptyStateView(
                            icon: "shippingbox",
                            title: "Склад пуст",
                            subtitle: "Добавьте товары для учёта остатков"
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyStateView(icon: "shippingbox", title: "Ничего не найдено", subtitle: "Попробуй изменить поиск или фильтр.")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                InventoryDetailView(item: item)
                                    .environmentObject(store)
                            } label: {
                                BigCard {
                                    HStack(spacing: 14) {
                                        Image(systemName: item.isLowStock ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(item.isLowStock ? .orange : .green)
                                            .frame(width: 46, height: 46)
                                            .background((item.isLowStock ? Color.orange : Color.green).opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))

                                        VStack(alignment: .leading, spacing: 7) {
                                            Text(item.name)
                                                .font(.title3)
                                                .bold()
                                                .foregroundStyle(.primary)
                                            Text(item.category)
                                                .foregroundStyle(.secondary)
                                            Text("Цена: \(item.pricePerUnit, specifier: "%.2f") / \(item.unit)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text("\(item.quantity, specifier: "%.1f")")
                                                .font(.title2)
                                                .bold()
                                                .foregroundStyle(.primary)
                                            Text(item.unit)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    let deletedItem = item
                                    store.inventoryItems.removeAll { $0.id == item.id }
                                    withAnimation {
                                        store.undoItem = UndoableItem(
                                            type: .inventoryItem,
                                            description: deletedItem.name
                                        ) {
                                            store.inventoryItems.append(deletedItem)
                                        }
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                        if store.undoItem?.description == deletedItem.name {
                                            withAnimation { store.undoItem = nil }
                                        }
                                    }
                                } label: { Label("Удалить", systemImage: "trash") }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.chefBackground)
                }
            }
            .background(Color.chefBackground)
            .searchable(text: $searchText, prompt: "Поиск продукта")
            .navigationTitle("Склад")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(InventorySortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Сортировка", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Button { showAudit = true } label: {
                            Image(systemName: "list.clipboard.fill")
                                .font(.title3)
                        }
                        Button { showAddItem = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddInventoryItemView { store.inventoryItems.append($0) }
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAudit) {
                NavigationStack {
                    InventoryAuditView().environmentObject(store)
                }
            }
        }
    }
}

struct InventoryDetailView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss

    let item: InventoryItem
    @State private var showEdit         = false
    @State private var showDeleteAlert  = false
    @State private var showQuickWriteOff = false

    var currentItem: InventoryItem {
        store.inventoryItems.first(where: { $0.id == item.id }) ?? item
    }

    private var itemStillExists: Bool {
        store.inventoryItems.contains(where: { $0.id == item.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BigCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(currentItem.name)
                                .font(.largeTitle)
                                .bold()
                            Spacer()
                            Image(systemName: currentItem.isLowStock ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(currentItem.isLowStock ? .orange : .green)
                        }

                        Text(currentItem.category)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .bottom) {
                            Text("\(currentItem.quantity, specifier: "%.1f")")
                                .font(.system(size: 48, weight: .bold))
                            Text(currentItem.unit)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        Text("Цена: \(currentItem.pricePerUnit, specifier: "%.2f") за \(currentItem.unit)")
                            .font(.headline)
                            .foregroundStyle(.chefAccent)
                    }
                }

                BigCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Минимальный остаток")
                            .font(.headline)
                        Text("\(currentItem.minQuantity, specifier: "%.1f") \(currentItem.unit)")
                            .font(.title2)
                            .bold()
                        Text(currentItem.isLowStock ? "Нужно заказать" : "Остаток в норме")
                            .foregroundStyle(currentItem.isLowStock ? .orange : .green)
                    }
                }

                // История цен
                if currentItem.priceHistory.count >= 2 {
                    BigCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("История цен", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.headline)
                            Chart(currentItem.priceHistory) { point in
                                LineMark(
                                    x: .value("Дата",  point.date),
                                    y: .value("Цена",  point.price)
                                )
                                .foregroundStyle(Color.chefAccent)
                                PointMark(
                                    x: .value("Дата",  point.date),
                                    y: .value("Цена",  point.price)
                                )
                                .foregroundStyle(Color.chefAccent)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                            .chartYAxisLabel("/ \(currentItem.unit)")
                            .frame(height: 120)
                        }
                    }
                }

                BigActionButton(title: "Списать", icon: "minus.circle.fill") {
                    showQuickWriteOff = true
                }

                BigActionButton(title: "Редактировать продукт", icon: "pencil") {
                    showEdit = true
                }

                NavigationLink {
                    StockMovementsView(filterItemName: currentItem.name).environmentObject(store)
                } label: {
                    Label("История движений", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 56)
                        .padding(.horizontal, 18)
                        .background(Color.chefCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Удалить продукт", systemImage: "trash")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Продукт")
        .onChange(of: itemStillExists) { _, exists in
            if !exists { dismiss() }
        }
        .sheet(isPresented: $showEdit) {
            EditInventoryItemView(item: currentItem) { updatedItem in
                store.updateInventoryItem(updatedItem)
            }
        }
        .alert("Удалить продукт?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                store.deleteInventoryItem(currentItem)
                dismiss()
            }
        } message: {
            Text("Продукт будет удален со склада.")
        }
        .sheet(isPresented: $showQuickWriteOff) {
            QuickWriteOffView(item: currentItem).environmentObject(store)
        }
    }
}

struct QuickWriteOffView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss
    let item: InventoryItem

    @State private var quantity = ""
    @State private var reason   = "Порча"
    let reasons = ["Порча", "Истек срок", "Ошибка приготовления", "Брак", "Другое"]

    private var canSave: Bool { parsePositiveDouble(quantity) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Продукт") {
                    HStack { Text("Название"); Spacer(); Text(item.name).foregroundStyle(.secondary) }
                    HStack { Text("Остаток");  Spacer(); Text("\(item.quantity, specifier: "%.2f") \(item.unit)").foregroundStyle(.secondary) }
                }
                Section("Списание") {
                    HStack {
                        TextField("Количество", text: $quantity).keyboardType(.decimalPad)
                        Text(item.unit).foregroundStyle(.secondary)
                    }
                    Picker("Причина", selection: $reason) {
                        ForEach(reasons, id: \.self) { Text($0) }
                    }
                }
            }
            .navigationTitle("Списать: \(item.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Списать") {
                        let wo = WriteOff(productName: item.name,
                                         quantity: parsePositiveDouble(quantity) ?? 0,
                                         unit: item.unit, reason: reason,
                                         employee: store.profile.name, date: Date())
                        store.addWriteOff(wo)
                        dismiss()
                    }.disabled(!canSave)
                }
            }
        }
    }
}

struct AddInventoryItemView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss
    @State private var name            = ""
    @State private var category        = ""
    @State private var quantity        = ""
    @State private var unit            = "кг"
    @State private var minQuantity     = ""
    @State private var pricePerUnit    = ""
    @State private var barcode         = ""
    @State private var hasExpiry       = false
    @State private var expiryDate      = Date()
    @State private var orderUnit       = ""
    @State private var orderUnitRatio  = ""
    @State private var showScanner     = false
    @State private var showSuggestions = false

    var onSave: (InventoryItem) -> Void
    let units = ["кг", "г", "л", "мл", "шт"]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        parseNonNegativeDouble(quantity) != nil &&
        parseNonNegativeDouble(minQuantity) != nil &&
        parseNonNegativeDouble(pricePerUnit) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Продукт") {
                    TextField("Название продукта", text: $name)
                        .onChange(of: name) { _, _ in
                            showSuggestions = !name.trimmingCharacters(in: .whitespaces).isEmpty
                        }
                    InventoryProductSuggestions(query: name, show: $showSuggestions) { item in
                        name         = item.name
                        category     = item.category
                        unit         = item.unit
                        if pricePerUnit.isEmpty && item.pricePerUnit > 0 {
                            pricePerUnit = String(format: "%.2f", item.pricePerUnit)
                        }
                        if minQuantity.isEmpty && item.minQuantity > 0 {
                            minQuantity = String(format: "%.1f", item.minQuantity)
                        }
                    }
                    TextField("Категория", text: $category)
                    Picker("Единица хранения", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                }
                Section("Остатки и цена") {
                    TextField("Количество", text: $quantity).keyboardType(.decimalPad)
                    TextField("Минимальный остаток", text: $minQuantity).keyboardType(.decimalPad)
                    TextField("Цена за единицу", text: $pricePerUnit).keyboardType(.decimalPad)
                }
                Section("Единица заказа") {
                    TextField("Ед. заказа (напр. пачка, ящик)", text: $orderUnit)
                    TextField("Кол-во \(unit) в 1 ед. заказа", text: $orderUnitRatio)
                        .keyboardType(.decimalPad)
                    if !orderUnit.isEmpty {
                        Text("Пример: 1 \(orderUnit) = \(orderUnitRatio.isEmpty ? "?" : orderUnitRatio) \(unit)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Срок годности") {
                    Toggle("Указать срок годности", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Срок годности", selection: $expiryDate, displayedComponents: .date)
                    }
                }
                Section("Штрихкод") {
                    HStack {
                        TextField("EAN, QR, или другой код", text: $barcode)
                            .textInputAutocapitalization(.never)
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(.chefAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Новый продукт")
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        var item = InventoryItem(name: name, category: category,
                                                quantity: parseNonNegativeDouble(quantity) ?? 0,
                                                unit: unit,
                                                minQuantity: parseNonNegativeDouble(minQuantity) ?? 0,
                                                pricePerUnit: parseNonNegativeDouble(pricePerUnit) ?? 0)
                        item.barcode        = barcode.trimmingCharacters(in: .whitespaces)
                        item.expiryDate     = hasExpiry ? expiryDate : nil
                        item.orderUnit      = orderUnit.trimmingCharacters(in: .whitespaces)
                        item.orderUnitRatio = parsePositiveDouble(orderUnitRatio) ?? 1
                        onSave(item)
                        dismiss()
                    }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerSheet(isPresented: $showScanner) { code in
                    barcode = code
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        name = code
                    }
                }
            }
        }
    }
}

struct EditInventoryItemView: View {
    @Environment(\.dismiss) var dismiss
    let item: InventoryItem

    @State private var name:           String
    @State private var category:       String
    @State private var quantity:       String
    @State private var unit:           String
    @State private var minQuantity:    String
    @State private var pricePerUnit:   String
    @State private var barcode:        String
    @State private var hasExpiry:      Bool
    @State private var expiryDate:     Date
    @State private var orderUnit:      String
    @State private var orderUnitRatio: String

    var onSave: (InventoryItem) -> Void
    let units = ["кг", "г", "л", "мл", "шт"]

    init(item: InventoryItem, onSave: @escaping (InventoryItem) -> Void) {
        self.item   = item
        self.onSave = onSave
        _name           = State(initialValue: item.name)
        _category       = State(initialValue: item.category)
        _quantity       = State(initialValue: String(item.quantity))
        _unit           = State(initialValue: item.unit)
        _minQuantity    = State(initialValue: String(item.minQuantity))
        _pricePerUnit   = State(initialValue: String(item.pricePerUnit))
        _barcode        = State(initialValue: item.barcode)
        _hasExpiry      = State(initialValue: item.expiryDate != nil)
        _expiryDate     = State(initialValue: item.expiryDate ?? Date())
        _orderUnit      = State(initialValue: item.orderUnit)
        _orderUnitRatio = State(initialValue: item.orderUnitRatio == 1 ? "" : String(item.orderUnitRatio))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        parseNonNegativeDouble(quantity) != nil &&
        parseNonNegativeDouble(minQuantity) != nil &&
        parseNonNegativeDouble(pricePerUnit) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Продукт") {
                    TextField("Название продукта", text: $name)
                    TextField("Категория", text: $category)
                    Picker("Единица хранения", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                }
                Section("Остатки и цена") {
                    TextField("Количество", text: $quantity).keyboardType(.decimalPad)
                    TextField("Минимальный остаток", text: $minQuantity).keyboardType(.decimalPad)
                    TextField("Цена за единицу", text: $pricePerUnit).keyboardType(.decimalPad)
                }
                Section("Единица заказа") {
                    TextField("Ед. заказа (напр. пачка, ящик)", text: $orderUnit)
                    TextField("Кол-во \(unit) в 1 ед. заказа", text: $orderUnitRatio)
                        .keyboardType(.decimalPad)
                    if !orderUnit.isEmpty {
                        Text("Пример: 1 \(orderUnit) = \(orderUnitRatio.isEmpty ? "?" : orderUnitRatio) \(unit)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Срок годности") {
                    Toggle("Указать срок годности", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Срок годности", selection: $expiryDate, displayedComponents: .date)
                    }
                }
                Section("Штрихкод") {
                    TextField("EAN, QR, или другой код", text: $barcode)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Редактировать")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        var updated = InventoryItem(
                            id: item.id, name: name, category: category,
                            quantity: parseNonNegativeDouble(quantity) ?? 0,
                            unit: unit,
                            minQuantity: parseNonNegativeDouble(minQuantity) ?? 0,
                            pricePerUnit: parseNonNegativeDouble(pricePerUnit) ?? 0)
                        updated.barcode        = barcode.trimmingCharacters(in: .whitespaces)
                        updated.priceHistory   = item.priceHistory
                        updated.expiryDate     = hasExpiry ? expiryDate : nil
                        updated.orderUnit      = orderUnit.trimmingCharacters(in: .whitespaces)
                        updated.orderUnitRatio = parsePositiveDouble(orderUnitRatio) ?? 1
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Inventory Audit

struct AuditEntry: Identifiable {
    let id      = UUID()
    let item:   InventoryItem
    var actual: String = ""

    var actualDouble: Double? {
        Double(actual.replacingOccurrences(of: ",", with: "."))
    }
    var difference: Double? {
        guard let a = actualDouble else { return nil }
        return a - item.quantity
    }
    var hasDiscrepancy: Bool {
        guard let d = difference else { return false }
        return abs(d) > 0.001
    }
}

struct InventoryAuditView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [AuditEntry] = []
    @State private var showApplyAlert = false
    @State private var auditDate = Date()
    @State private var auditor = ""

    private var filledCount: Int { entries.filter { $0.actualDouble != nil }.count }
    private var discrepancyCount: Int { entries.filter { $0.hasDiscrepancy }.count }

    // Entries grouped by category
    private var categories: [String] {
        let cats = store.inventoryCategories
        return cats.isEmpty ? ["Общее"] : cats
    }

    private func entries(for category: String) -> [Int] {
        entries.indices.filter { entries[$0].item.category == category }
    }

    var body: some View {
        Form {
            Section("Инвентаризация") {
                DatePicker("Дата", selection: $auditDate, displayedComponents: .date)
                TextField("Ответственный", text: $auditor)
                HStack {
                    Text("Заполнено")
                    Spacer()
                    Text("\(filledCount) / \(entries.count)").foregroundStyle(.secondary)
                }
                if discrepancyCount > 0 {
                    Label("\(discrepancyCount) расхождений", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline).foregroundStyle(.orange)
                }
            }

            ForEach(categories, id: \.self) { category in
                let indices = entries(for: category)
                if !indices.isEmpty {
                    Section(category) {
                        ForEach(indices, id: \.self) { idx in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entries[idx].item.name).font(.subheadline)
                                    Text("По системе: \(entries[idx].item.quantity, specifier: "%.2f") \(entries[idx].item.unit)")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let diff = entries[idx].difference, entries[idx].actualDouble != nil {
                                        Text(diff >= 0 ? "+\(String(format: "%.2f", diff))" : "\(String(format: "%.2f", diff))")
                                            .font(.caption.bold())
                                            .foregroundStyle(diff >= 0 ? .green : .red)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    TextField("Факт", text: $entries[idx].actual)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                    Text(entries[idx].item.unit).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if discrepancyCount > 0 {
                Section("Расхождения (\(discrepancyCount))") {
                    ForEach(entries.filter { $0.hasDiscrepancy }) { entry in
                        HStack {
                            Text(entry.item.name)
                            Spacer()
                            if let diff = entry.difference {
                                Text(diff >= 0 ? "+\(String(format: "%.2f", diff))" : "\(String(format: "%.2f", diff))")
                                    .fontWeight(.medium)
                                    .foregroundStyle(diff >= 0 ? .green : .red)
                                Text(entry.item.unit).foregroundStyle(.secondary).font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Инвентаризация")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Провести") { showApplyAlert = true }
                    .disabled(discrepancyCount == 0)
            }
        }
        .onAppear {
            if entries.isEmpty {
                entries = store.inventoryItems.map { AuditEntry(item: $0) }
            }
            if auditor.isEmpty { auditor = store.profile.name }
        }
        .confirmationDialog(
            "Провести инвентаризацию?",
            isPresented: $showApplyAlert,
            titleVisibility: .visible
        ) {
            Button("Провести и скорректировать остатки", role: .destructive) {
                applyAudit()
                dismiss()
            }
        } message: {
            Text("Будет создано \(discrepancyCount) записей корректировки")
        }
    }

    private func applyAudit() {
        let df = DateFormatter()
        df.dateStyle = .short
        let dateStr = df.string(from: auditDate)
        for entry in entries {
            guard let actual = entry.actualDouble, entry.hasDiscrepancy,
                  let idx = store.inventoryItems.firstIndex(where: { $0.id == entry.item.id }) else { continue }
            let diff = actual - entry.item.quantity
            if diff < 0 {
                let wo = WriteOff(productName: entry.item.name,
                                  quantity: abs(diff),
                                  unit: entry.item.unit,
                                  reason: "Инвентаризация \(dateStr)",
                                  employee: auditor.isEmpty ? store.profile.name : auditor,
                                  date: auditDate)
                store.writeOffs.append(wo)
            }
            store.inventoryItems[idx].quantity = actual
        }
        entries = store.inventoryItems.map { AuditEntry(item: $0) }
    }
}
