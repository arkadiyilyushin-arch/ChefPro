import SwiftUI

// MARK: - Deliveries

struct DeliveriesView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAddDelivery = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                InfoCard(title: "Сумма приемок", value: "\(Int(store.totalDeliverySum))", subtitle: "за весь период", icon: "tray.and.arrow.down.fill")
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                if store.deliveries.isEmpty {
                    EmptyStateView(icon: "tray", title: "Приемок пока нет", subtitle: "Добавь первую приемку товара.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.deliveries.reversed()) { delivery in
                            BigCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(delivery.productName)
                                            .font(.title3)
                                            .bold()
                                        Spacer()
                                        Text(delivery.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Поставщик: \(delivery.supplier)")
                                        .foregroundStyle(.secondary)
                                    Text("Принял: \(delivery.acceptedBy)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !delivery.notes.isEmpty {
                                        Text(delivery.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                    HStack {
                                        Text("\(delivery.quantity, specifier: "%.1f") \(delivery.unit)")
                                            .font(.headline)
                                        Spacer()
                                        Text("\(delivery.price, specifier: "%.2f")")
                                            .font(.headline)
                                            .foregroundStyle(.chefAccent)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deliveries.removeAll { $0.id == delivery.id }
                                } label: { Label("Удалить", systemImage: "trash") }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.chefBackground)
                }
            }
            .background(Color.chefBackground)
            .navigationTitle("Приемка")
            .toolbar {
                Button { showAddDelivery = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .sheet(isPresented: $showAddDelivery) {
                AddDeliveryView { store.addDelivery($0) }
                    .environmentObject(store)
            }
        }
    }
}

struct AddDeliveryView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss
    @State private var supplierPickerID: UUID? = nil
    @State private var supplier     = ""
    @State private var productName  = ""
    @State private var category     = ""
    @State private var quantity     = ""
    @State private var unit         = "кг"
    @State private var price        = ""
    @State private var acceptedBy   = ""
    @State private var notes        = ""
    @State private var showScanner  = false
    @State private var showInvoiceScanner = false
    @State private var showCategoryPicker = false

    var onSave: (Delivery) -> Void
    let units = ["кг", "г", "л", "мл", "шт"]

    private var canSave: Bool {
        !supplier.trimmingCharacters(in: .whitespaces).isEmpty &&
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        parsePositiveDouble(quantity) != nil &&
        parseNonNegativeDouble(price) != nil &&
        !acceptedBy.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
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
                }

                Section("Товар") {
                    HStack {
                        TextField("Название продукта", text: $productName)
                            .onChange(of: productName) { _, name in
                                // Автозаполнение категории если товар есть на складе
                                if let item = store.inventoryItems.first(where: {
                                    $0.name.lowercased() == name.lowercased()
                                }) {
                                    if category.isEmpty { category = item.category }
                                    if unit == "кг"     { unit = item.unit }
                                }
                            }
                        Button { showScanner = true } label: {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(.chefAccent)
                        }
                        .buttonStyle(.plain)
                        Button { showInvoiceScanner = true } label: {
                            Image(systemName: "doc.text.viewfinder")
                                .foregroundStyle(.chefAccent)
                        }
                        .buttonStyle(.plain)
                    }

                    // Категория
                    if store.inventoryCategories.isEmpty {
                        TextField("Категория", text: $category)
                    } else {
                        HStack {
                            TextField("Категория", text: $category)
                            Menu {
                                ForEach(store.inventoryCategories, id: \.self) { cat in
                                    Button(cat) { category = cat }
                                }
                                Divider()
                                Button("Без категории") { category = "Без категории" }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.chefAccent)
                            }
                        }
                    }

                    TextField("Количество", text: $quantity).keyboardType(.decimalPad)
                    Picker("Единица", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                    TextField("Сумма", text: $price).keyboardType(.decimalPad)
                }

                Section("Кто принял") {
                    TextField("Имя сотрудника", text: $acceptedBy)
                }

                Section("Примечание") {
                    TextField("Комментарий к поставке…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Новая приемка")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        var delivery = Delivery(
                            supplier: supplier,
                            productName: productName,
                            category: category.trimmingCharacters(in: .whitespaces),
                            quantity: parsePositiveDouble(quantity) ?? 0,
                            unit: unit,
                            price: parseNonNegativeDouble(price) ?? 0,
                            date: Date(),
                            acceptedBy: acceptedBy
                        )
                        delivery.notes = notes.trimmingCharacters(in: .whitespaces)
                        onSave(delivery)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear { acceptedBy = store.profile.name }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet(isPresented: $showScanner) { code in
                // Look up inventory item by barcode; otherwise pre-fill with the scanned code
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
                if let qty = result.quantity { quantity = String(format: "%.1f", qty) }
                if !result.unit.isEmpty { unit = result.unit }
                if let price = result.price { self.price = String(format: "%.2f", price) }
            }
        }
    }
}
