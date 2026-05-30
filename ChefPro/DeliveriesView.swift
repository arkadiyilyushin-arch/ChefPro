import SwiftUI

// MARK: - Deliveries

struct DeliveriesView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAddDelivery = false

    // Group deliveries by supplier+date (same day)
    private var groupedDeliveries: [(key: String, items: [Delivery])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: store.deliveries.reversed()) { d in
            "\(d.supplier)|\(cal.startOfDay(for: d.date).timeIntervalSince1970)"
        }
        return grouped
            .sorted { a, b in
                let aDate = a.value.first?.date ?? Date.distantPast
                let bDate = b.value.first?.date ?? Date.distantPast
                return aDate > bDate
            }
            .map { (key: $0.key, items: $0.value) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                InfoCard(
                    title: "Сумма приемок",
                    value: "\(Int(store.totalDeliverySum)) ₽",
                    subtitle: "за весь период",
                    icon: "tray.and.arrow.down.fill"
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

                if store.deliveries.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "Приемок пока нет",
                        subtitle: "Добавь первую приемку товара."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedDeliveries, id: \.key) { group in
                            let totalSum = group.items.reduce(0) { $0 + $1.price }
                            Section {
                                ForEach(group.items) { delivery in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(delivery.productName)
                                                .font(.subheadline.bold())
                                            if !delivery.notes.isEmpty {
                                                Text(delivery.notes)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .italic()
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(delivery.quantity, specifier: "%.1f") \(delivery.unit)")
                                                .font(.subheadline)
                                            Text("\(delivery.price, specifier: "%.2f") ₽")
                                                .font(.caption.bold())
                                                .foregroundStyle(.chefAccent)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            store.deliveries.removeAll { $0.id == delivery.id }
                                        } label: { Label("Удалить", systemImage: "trash") }
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(group.items.first?.supplier ?? "")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        Text(group.items.first?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text("\(group.items.count) поз.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(Int(totalSum)) ₽")
                                            .font(.caption.bold())
                                            .foregroundStyle(.chefAccent)
                                    }
                                }
                                .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .background(Color.chefBackground)
                }
            }
            .background(Color.chefBackground)
            .navigationTitle("Приемка")
            .toolbar {
                Button { showAddDelivery = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
            }
            .sheet(isPresented: $showAddDelivery) {
                AddDeliveryView { deliveries in
                    deliveries.forEach { store.addDelivery($0) }
                }
                .environmentObject(store)
            }
        }
    }
}

// MARK: - Line Item (draft before saving)

private struct DeliveryLineItem: Identifiable {
    var id        = UUID()
    var productName: String
    var category:   String
    var quantity:   Double
    var unit:       String
    var price:      Double
}

// MARK: - Add Delivery (bulk)

struct AddDeliveryView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss

    var onSave: ([Delivery]) -> Void

    // ── Header fields ──────────────────────────────────
    @State private var supplierPickerID: UUID? = nil
    @State private var supplier    = ""
    @State private var acceptedBy  = ""
    @State private var notes       = ""
    @State private var date        = Date()

    // ── Item draft ─────────────────────────────────────
    @State private var productName = ""
    @State private var category    = ""
    @State private var quantity    = ""
    @State private var unit        = "кг"
    @State private var price       = ""
    @State private var showSuggestions = false

    // ── Added items ────────────────────────────────────
    @State private var items: [DeliveryLineItem] = []

    // ── Misc ───────────────────────────────────────────
    @State private var showScanner         = false
    @State private var showInvoiceScanner  = false
    @FocusState private var focusedField: Field?

    enum Field { case product, qty, price }

    let units = ["кг", "г", "л", "мл", "шт"]

    private var canAddItem: Bool {
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        parsePositiveDouble(quantity) != nil &&
        parseNonNegativeDouble(price) != nil
    }

    private var canSave: Bool {
        !items.isEmpty &&
        !supplier.trimmingCharacters(in: .whitespaces).isEmpty &&
        !acceptedBy.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var totalSum: Double { items.reduce(0) { $0 + $1.price } }

    private var suggestions: [InventoryItem] {
        guard !productName.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return store.inventoryItems
            .filter { $0.name.localizedCaseInsensitiveContains(productName) }
            .prefix(5).map { $0 }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                // ── Поставщик ──────────────────────────
                Section("Поставщик") {
                    if !store.suppliers.isEmpty {
                        Picker("Из справочника", selection: $supplierPickerID) {
                            Text("— выбрать —").tag(UUID?.none)
                            ForEach(store.suppliers) { s in
                                Text(s.name).tag(Optional(s.id))
                            }
                        }
                        .onChange(of: supplierPickerID) { _, id in
                            if let id, let s = store.suppliers.first(where: { $0.id == id }) {
                                supplier = s.name
                            }
                        }
                    }
                    TextField("Название поставщика", text: $supplier)
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }

                // ── Добавить позицию ────────────────────
                Section {
                    // Product name + scanner buttons
                    HStack(spacing: 8) {
                        TextField("Название продукта", text: $productName)
                            .focused($focusedField, equals: .product)
                            .onChange(of: productName) { _, name in
                                showSuggestions = !suggestions.isEmpty
                                if let item = store.inventoryItems.first(where: {
                                    $0.name.lowercased() == name.lowercased()
                                }) {
                                    if category.isEmpty { category = item.category }
                                    unit = item.unit
                                }
                            }
                        Button { showScanner = true } label: {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(.chefAccent)
                        }.buttonStyle(.plain)
                        Button { showInvoiceScanner = true } label: {
                            Image(systemName: "doc.text.viewfinder")
                                .foregroundStyle(.chefAccent)
                        }.buttonStyle(.plain)
                    }

                    // Autocomplete suggestions
                    if showSuggestions {
                        ForEach(suggestions) { item in
                            Button {
                                productName = item.name
                                unit = item.unit
                                category = item.category
                                showSuggestions = false
                                focusedField = .qty
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.chefAccent)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.name).foregroundStyle(.primary)
                                        Text("\(item.quantity, specifier: "%.1f") \(item.unit) · \(item.category)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Category
                    HStack {
                        TextField("Категория", text: $category)
                        if !store.inventoryCategories.isEmpty {
                            Menu {
                                ForEach(store.inventoryCategories, id: \.self) { cat in
                                    Button(cat) { category = cat }
                                }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.chefAccent)
                            }
                        }
                    }

                    // Quantity + unit + price row
                    HStack(spacing: 8) {
                        TextField("Кол-во", text: $quantity)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .qty)
                            .frame(minWidth: 60)
                        Picker("", selection: $unit) {
                            ForEach(units, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 60)
                        Divider()
                        TextField("Сумма ₽", text: $price)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .price)
                            .multilineTextAlignment(.trailing)
                    }

                    // Add button
                    Button {
                        addItem()
                    } label: {
                        Label("Добавить позицию", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(canAddItem ? .chefAccent : .secondary)
                    }
                    .disabled(!canAddItem)

                } header: {
                    Text("Добавить позицию")
                }

                // ── Список позиций ──────────────────────
                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.productName).font(.subheadline.bold())
                                    Text(item.category).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(item.quantity, specifier: "%.1f") \(item.unit)")
                                        .font(.subheadline)
                                    Text("\(item.price, specifier: "%.2f") ₽")
                                        .font(.caption.bold())
                                        .foregroundStyle(.chefAccent)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    items.removeAll { $0.id == item.id }
                                } label: { Label("Удалить", systemImage: "trash") }
                            }
                        }

                        HStack {
                            Text("Итого: \(items.count) поз.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(totalSum, specifier: "%.2f") ₽")
                                .font(.subheadline.bold())
                                .foregroundStyle(.chefAccent)
                        }
                        .listRowBackground(Color.chefAccent.opacity(0.06))

                    } header: {
                        Text("Позиции (\(items.count))")
                    }
                }

                // ── Кто принял ──────────────────────────
                Section("Кто принял") {
                    TextField("Имя сотрудника", text: $acceptedBy)
                }

                Section("Примечание к поставке") {
                    TextField("Комментарий…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Новая приемка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAll()
                    } label: {
                        if items.isEmpty {
                            Text("Сохранить")
                        } else {
                            Text("Сохранить (\(items.count))")
                                .bold()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear { acceptedBy = store.profile.name }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet(isPresented: $showScanner) { code in
                if let matched = store.inventoryItem(forBarcode: code) {
                    productName = matched.name
                    unit = matched.unit
                    category = matched.category
                } else {
                    productName = code
                }
            }
        }
        .sheet(isPresented: $showInvoiceScanner) {
            InvoiceScannerView { result in
                if !result.productName.isEmpty { productName = result.productName }
                if let qty  = result.quantity  { quantity = String(format: "%.1f", qty) }
                if !result.unit.isEmpty         { unit = result.unit }
                if let p    = result.price      { price = String(format: "%.2f", p) }
            }
        }
    }

    // MARK: - Actions

    private func addItem() {
        guard let qty = parsePositiveDouble(quantity),
              let prc = parseNonNegativeDouble(price) else { return }

        let cat = category.trimmingCharacters(in: .whitespaces)
        items.append(DeliveryLineItem(
            productName: productName.trimmingCharacters(in: .whitespaces),
            category:    cat.isEmpty ? "Без категории" : cat,
            quantity:    qty,
            unit:        unit,
            price:       prc
        ))

        // Reset draft fields, keep supplier/unit for fast repeated entry
        productName = ""
        category    = ""
        quantity    = ""
        price       = ""
        showSuggestions = false
        focusedField = .product   // jump back to product field
    }

    private func saveAll() {
        let deliveries = items.map { item in
            var d = Delivery(
                supplier:    supplier.trimmingCharacters(in: .whitespaces),
                productName: item.productName,
                category:    item.category,
                quantity:    item.quantity,
                unit:        item.unit,
                price:       item.price,
                date:        date,
                acceptedBy:  acceptedBy.trimmingCharacters(in: .whitespaces)
            )
            d.notes = notes.trimmingCharacters(in: .whitespaces)
            return d
        }
        onSave(deliveries)
        dismiss()
    }
}
