import SwiftUI

// MARK: - Suppliers

struct SuppliersView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd = false

    var body: some View {
        List {
            if store.suppliers.isEmpty {
                EmptyStateView(icon: "truck.box", title: "Поставщиков пока нет", subtitle: "Добавьте первого поставщика.")
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(store.suppliers) { supplier in
                    NavigationLink {
                        SupplierDetailView(supplier: supplier).environmentObject(store)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(supplier.name).font(.headline)
                            if !supplier.phone.isEmpty {
                                Label(supplier.phone, systemImage: "phone.fill")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            let deliveryCount = store.deliveries.filter { $0.supplier == supplier.name }.count
                            if deliveryCount > 0 {
                                Label("\(deliveryCount) приёмок", systemImage: "tray.fill")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    offsets.map { store.suppliers[$0] }.forEach { store.deleteSupplier($0) }
                }
            }
        }
        .navigationTitle("Поставщики")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditSupplierView(supplier: nil).environmentObject(store)
        }
    }
}

struct SupplierDetailView: View {
    @EnvironmentObject var store: ChefProStore
    let supplier: Supplier
    @State private var showEdit = false

    private var deliveries: [Delivery] {
        store.deliveries.filter { $0.supplier == supplier.name }.sorted { $0.date > $1.date }
    }
    private var totalSpend: Double { deliveries.reduce(0) { $0 + $1.price } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BigCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(supplier.name).font(.largeTitle.bold())
                        if !supplier.phone.isEmpty { Label(supplier.phone, systemImage: "phone.fill").foregroundStyle(.secondary) }
                        if !supplier.email.isEmpty { Label(supplier.email, systemImage: "envelope.fill").foregroundStyle(.secondary) }
                        if !supplier.notes.isEmpty { Text(supplier.notes).font(.caption).foregroundStyle(.secondary) }
                    }
                }

                HStack {
                    InfoCard(title: "Приёмок", value: "\(deliveries.count)", subtitle: "всего", icon: "tray.fill")
                    InfoCard(title: "Сумма", value: "\(Int(totalSpend))", subtitle: "за всё время", icon: "banknote.fill")
                }

                if !deliveries.isEmpty {
                    SectionTitle(title: "История приёмок")
                    ForEach(deliveries) { d in
                        BigCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(d.productName).font(.headline)
                                    Spacer()
                                    Text(d.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text("\(d.quantity, specifier: "%.1f") \(d.unit)").foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(d.price, specifier: "%.2f")").bold().foregroundStyle(.chefAccent)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Поставщик")
        .toolbar {
            Button("Редактировать") { showEdit = true }
        }
        .sheet(isPresented: $showEdit) {
            AddEditSupplierView(supplier: supplier).environmentObject(store)
        }
    }
}

struct AddEditSupplierView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    let supplier: Supplier?

    @State private var name  = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    private var isEditing: Bool { supplier != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Название поставщика", text: $name)
                }
                Section("Контакты") {
                    TextField("Телефон", text: $phone).keyboardType(.phonePad)
                    TextField("Email",   text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
                Section("Примечание") {
                    TextField("Условия, контактное лицо…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                if isEditing {
                    Section {
                        Button("Удалить поставщика", role: .destructive) {
                            if let s = supplier { store.deleteSupplier(s) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Редактировать" : "Новый поставщик")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.disabled(!canSave)
                }
            }
        }
        .onAppear {
            if let s = supplier { name = s.name; phone = s.phone; email = s.email; notes = s.notes }
        }
    }

    private func save() {
        let s = Supplier(id: supplier?.id ?? UUID(),
                         name:  name.trimmingCharacters(in: .whitespaces),
                         phone: phone.trimmingCharacters(in: .whitespaces),
                         email: email.trimmingCharacters(in: .whitespaces),
                         notes: notes.trimmingCharacters(in: .whitespaces))
        isEditing ? store.updateSupplier(s) : store.addSupplier(s)
        dismiss()
    }
}

// MARK: - Supplier Auto Order

struct SupplierAutoOrderView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showShareSheet = false
    @State private var orderText = ""

    struct OrderLine: Identifiable {
        let id: UUID
        let item: InventoryItem
        let needed: Double
        let supplier: String
    }

    private var orderLines: [OrderLine] {
        store.purchaseList.map { item in
            let needed = max(item.minQuantity - item.quantity, 0)
            let sup = store.suppliers.first(where: {
                item.name.localizedCaseInsensitiveContains($0.name) ||
                $0.name.localizedCaseInsensitiveContains(item.name)
            })?.name ?? "Без поставщика"
            return OrderLine(id: item.id, item: item, needed: needed, supplier: sup)
        }
    }

    private var grouped: [(String, [OrderLine])] {
        let sups = Array(Set(orderLines.map { $0.supplier })).sorted()
        return sups.map { sup in (sup, orderLines.filter { $0.supplier == sup }) }
    }

    private func buildOrderText() -> String {
        var lines = ["ЗАЯВКА НА ЗАКУПКУ", "Дата: \(Date().formatted(date: .abbreviated, time: .shortened))", "Ресторан: \(store.restaurantName)", ""]
        for (supplier, items) in grouped {
            lines.append("═══ \(supplier) ═══")
            for line in items {
                lines.append("• \(line.item.name): \(String(format: "%.1f", line.needed)) \(line.item.effectiveOrderUnit)")
            }
            lines.append("")
        }
        lines.append("Ответственный: \(store.profile.name)")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if orderLines.isEmpty {
                    EmptyStateView(icon: "cart.badge.questionmark", title: "Заказ не нужен",
                                   subtitle: "Все позиции на складе выше минимума")
                        .padding(.top, 60)
                } else {
                    orderSummaryCard
                    ForEach(grouped, id: \.0) { supplier, lines in
                        SupplierOrderSection(supplier: supplier, lines: lines,
                                            emailBody: buildOrderText())
                    }
                    BigActionButton(title: "Поделиться заявкой", icon: "square.and.arrow.up") {
                        orderText = buildOrderText()
                        showShareSheet = true
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.chefBackground)
        .navigationTitle("Автозаказ поставщикам")
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [orderText])
        }
    }

    private var orderSummaryCard: some View {
        BigCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Позиций к заказу").font(.caption).foregroundStyle(.secondary)
                    Text("\(orderLines.count)").font(.title.bold()).foregroundStyle(.chefAccent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Поставщиков").font(.caption).foregroundStyle(.secondary)
                    Text("\(grouped.count)").font(.title.bold())
                }
            }
        }
        .padding(.horizontal)
    }
}

struct SupplierOrderSection: View {
    @EnvironmentObject var store: ChefProStore
    let supplier: String
    let lines: [SupplierAutoOrderView.OrderLine]
    let emailBody: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(supplier).font(.headline).padding(.horizontal)
                Spacer()
                if let sup = store.suppliers.first(where: { $0.name == supplier }),
                   !sup.email.isEmpty,
                   let url = URL(string: "mailto:\(sup.email)?subject=Заявка&body=\(emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                    Link(destination: url) {
                        Label("Email", systemImage: "envelope").font(.caption)
                    }
                    .padding(.trailing)
                }
            }
            ForEach(lines) { line in
                OrderLineRow(line: line)
            }
        }
    }
}

struct OrderLineRow: View {
    let line: SupplierAutoOrderView.OrderLine

    var body: some View {
        BigCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(line.item.name).font(.subheadline.bold())
                    HStack(spacing: 6) {
                        Text("Остаток: \(line.item.quantity, specifier: "%.1f") \(line.item.unit)")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("·")
                        Text("Мин: \(line.item.minQuantity, specifier: "%.1f")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Заказать").font(.caption).foregroundStyle(.secondary)
                    Text("\(line.needed, specifier: "%.1f") \(line.item.effectiveOrderUnit)")
                        .font(.subheadline.bold()).foregroundStyle(.chefAccent)
                }
            }
        }
        .padding(.horizontal)
    }
}
