import SwiftUI
import Charts
import UniformTypeIdentifiers

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
    @State private var showAddItem      = false
    @State private var showAudit        = false
    @State private var showCSVImport    = false
    @State private var csvImportResult  = ""
    @State private var showCSVResult    = false
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
                // Combined filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { showOnlyLowStock.toggle() } label: {
                            Label("На исходе", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(showOnlyLowStock ? Color.orange : Color(.systemGray5))
                                .foregroundStyle(showOnlyLowStock ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        Rectangle().fill(Color(.separator)).frame(width: 1, height: 22)
                        ForEach(categories, id: \.self) { cat in
                            Button { selectedCategory = cat } label: {
                                Text(cat)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(selectedCategory == cat ? Color.chefAccent : Color(.systemGray5))
                                    .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

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
                                InventoryItemRow(item: item)
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
                        Button { showCSVImport = true } label: {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.title3)
                        }
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
            .sheet(isPresented: $showCSVImport) {
                CSVPriceImportView { result in
                    csvImportResult = result
                    showCSVResult = true
                    store.applyCSVPriceImport(result)
                }
            }
            .alert("Импорт цен", isPresented: $showCSVResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(csvImportResult)
            }
        }
    }
}

private struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill((item.isLowStock ? Color.orange : Color.green).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: item.isLowStock ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(item.isLowStock ? .orange : .green)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(item.category + " · " + String(format: "%.2f", item.pricePerUnit) + " / " + item.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(item.quantity.truncatingRemainder(dividingBy: 1) == 0
                     ? String(format: "%.0f", item.quantity)
                     : String(format: "%.1f", item.quantity))
                    .font(.headline.bold())
                    .foregroundStyle(item.isLowStock ? .orange : .primary)
                Text(item.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - CSV Price Import

struct CSVPriceImportView: View {
    @Environment(\.dismiss) var dismiss
    var onImport: (String) -> Void

    @State private var showPicker = false
    @State private var previewLines: [String] = []
    @State private var fileURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                BigCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Формат CSV", systemImage: "doc.text").font(.headline)
                        Text("Файл должен содержать две колонки через запятую или точку с запятой:")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Название продукта,Цена за единицу")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("Например:\nМука пшеничная,45.50\nМасло сливочное,380")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                if !previewLines.isEmpty {
                    BigCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Предпросмотр (\(previewLines.count) строк)", systemImage: "eye")
                                .font(.headline)
                            ForEach(previewLines.prefix(5), id: \.self) { line in
                                Text(line).font(.caption).foregroundStyle(.secondary)
                            }
                            if previewLines.count > 5 {
                                Text("…и ещё \(previewLines.count - 5) строк").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button {
                    showPicker = true
                } label: {
                    Label(fileURL == nil ? "Выбрать CSV файл" : "Выбрать другой файл", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.chefAccent.opacity(0.15))
                        .foregroundStyle(.chefAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                if fileURL != nil {
                    Button {
                        onImport(previewLines.joined(separator: "\n"))
                        dismiss()
                    } label: {
                        Label("Применить цены", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Импорт прайс-листа")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
            }
            .fileImporter(isPresented: $showPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                guard let url = try? result.get() else { return }
                fileURL = url
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    previewLines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                } else if let text = try? String(contentsOf: url, encoding: .windowsCP1251) {
                    previewLines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
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
            VStack(spacing: 14) {
                // ── Hero header ──────────────────────────────────────
                ZStack(alignment: .bottomLeading) {
                    let statusColor: Color = currentItem.isLowStock ? .orange : .green
                    LinearGradient(
                        colors: [statusColor.opacity(0.7), statusColor.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(maxWidth: .infinity).frame(height: 140)
                    .overlay(
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 48)).foregroundStyle(.white.opacity(0.25))
                    )
                    LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentItem.name)
                            .font(.title2.bold()).foregroundStyle(.white).lineLimit(2)
                        Text(currentItem.category)
                            .font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(16)
                }

                // ── Stat chips ───────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        inventoryChip(icon: "scalemass.fill", label: "Остаток",
                                      value: String(format: "%.1f \(currentItem.unit)", currentItem.quantity),
                                      color: currentItem.isLowStock ? .orange : .green)
                        inventoryChip(icon: "tag.fill",        label: "Цена/\(currentItem.unit)",
                                      value: String(format: "%.2f", currentItem.pricePerUnit),
                                      color: .blue)
                        inventoryChip(icon: "arrow.down.circle.fill", label: "Мин. остаток",
                                      value: String(format: "%.1f \(currentItem.unit)", currentItem.minQuantity),
                                      color: .secondary)
                        let totalVal = currentItem.quantity * currentItem.pricePerUnit
                        inventoryChip(icon: "creditcard.fill", label: "Стоимость",
                                      value: String(format: "%.2f", totalVal),
                                      color: .purple)
                    }
                    .padding(.horizontal, 16)
                }

                // ── Status banner ────────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: currentItem.isLowStock ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(currentItem.isLowStock ? .orange : .green)
                    Text(currentItem.isLowStock ? "На исходе — нужно заказать" : "Остаток в норме")
                        .font(.subheadline.bold())
                        .foregroundStyle(currentItem.isLowStock ? .orange : .green)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background((currentItem.isLowStock ? Color.orange : Color.green).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)

                // ── Price history chart ──────────────────────────────
                if currentItem.priceHistory.count >= 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("История цен", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.bold()).foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                        Chart(currentItem.priceHistory) { point in
                            LineMark(x: .value("Дата", point.date), y: .value("Цена", point.price))
                                .foregroundStyle(Color.chefAccent)
                            PointMark(x: .value("Дата", point.date), y: .value("Цена", point.price))
                                .foregroundStyle(Color.chefAccent)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxisLabel("/ \(currentItem.unit)")
                        .frame(height: 110)
                        .padding(.horizontal, 14).padding(.bottom, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                }

                // ── Actions grid ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Действия").font(.subheadline.bold()).foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        inventoryActionCell(icon: "minus.circle.fill", label: "Списать",     color: .orange) { showQuickWriteOff = true }
                        inventoryActionCell(icon: "pencil",            label: "Редактировать", color: .blue)  { showEdit = true }
                        NavigationLink {
                            StockMovementsView(filterItemName: currentItem.name).environmentObject(store)
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.teal.opacity(0.15)).frame(width: 34, height: 34)
                                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 14, weight: .semibold)).foregroundStyle(.teal)
                                }
                                Text("История").font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 11)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }

                // ── Delete ───────────────────────────────────────────
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Удалить продукт", systemImage: "trash")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity).frame(height: 46)
                }
                .buttonStyle(.bordered).tint(.red)
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
            .padding(.vertical, 0)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentItem.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private func inventoryChip(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2).foregroundStyle(color)
                Text(value).font(.subheadline.bold()).foregroundStyle(.primary)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func inventoryActionCell(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 34, height: 34)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
                }
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
