import SwiftUI
import UIKit

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
    @State private var showOrder = false

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

                // Contact action buttons
                HStack(spacing: 12) {
                    if !supplier.phone.isEmpty,
                       let callURL = URL(string: "tel:\(supplier.phone.replacingOccurrences(of: " ", with: ""))") {
                        Link(destination: callURL) {
                            Label("Позвонить", systemImage: "phone.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    Button {
                        showOrder = true
                    } label: {
                        Label("Заказать", systemImage: "cart.badge.plus")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.chefAccent.opacity(0.15))
                            .foregroundStyle(.chefAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 4)

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
        .sheet(isPresented: $showOrder) {
            SupplierOrderComposeView(supplier: supplier).environmentObject(store)
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
    @State private var copiedToClipboard = false

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
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy"
        var lines: [String] = [
            "ЗАЯВКА НА ПОСТАВКУ",
            "Дата: \(df.string(from: Date()))",
            "Ресторан: \(store.restaurantName)",
            ""
        ]
        for (supplier, items) in grouped {
            lines.append("═══ \(supplier) ═══")
            lines.append("Товар | Кол-во | Ед.")
            for line in items {
                lines.append("• \(line.item.name) | \(String(format: "%.1f", line.needed)) | \(line.item.effectiveOrderUnit)")
            }
            lines.append("")
        }
        lines.append("Ответственный: \(store.profile.name)")
        return lines.joined(separator: "\n")
    }

    private func shareViaWhatsApp(text: String) {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "whatsapp://send?text=\(encoded)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                UIPasteboard.general.string = text
                copiedToClipboard = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedToClipboard = false }
            }
        }
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

                    // Share buttons row
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                shareViaWhatsApp(text: buildOrderText())
                            } label: {
                                Label("WhatsApp", systemImage: "message.fill")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button {
                                orderText = buildOrderText()
                                showShareSheet = true
                            } label: {
                                Label("Email", systemImage: "envelope.fill")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        Button {
                            UIPasteboard.general.string = buildOrderText()
                            copiedToClipboard = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedToClipboard = false }
                        } label: {
                            Label(copiedToClipboard ? "Скопировано!" : "Скопировать", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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
    @State private var copiedSection = false

    private var supplierRecord: Supplier? {
        store.suppliers.first(where: { $0.name == supplier })
    }

    private func supplierOrderText() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy"
        var result = "ЗАЯВКА НА ПОСТАВКУ\nДата: \(df.string(from: Date()))\nРесторан: \(store.restaurantName)\nПоставщик: \(supplier)\n\nТовар | Кол-во | Ед.\n"
        for line in lines {
            result += "• \(line.item.name) | \(String(format: "%.1f", line.needed)) | \(line.item.effectiveOrderUnit)\n"
        }
        return result
    }

    private func shareViaWhatsApp() {
        let text = supplierOrderText()
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "whatsapp://send?text=\(encoded)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                UIPasteboard.general.string = text
                copiedSection = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSection = false }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(supplier).font(.headline).padding(.horizontal)
                Spacer()
                // Per-supplier share buttons
                HStack(spacing: 8) {
                    // WhatsApp
                    Button { shareViaWhatsApp() } label: {
                        Image(systemName: "message.fill")
                            .font(.caption)
                            .padding(6)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Circle())
                    }

                    // Email
                    if let sup = supplierRecord, !sup.email.isEmpty,
                       let subjectEncoded = "Заявка на поставку".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let bodyEncoded = supplierOrderText().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "mailto:\(sup.email)?subject=\(subjectEncoded)&body=\(bodyEncoded)") {
                        Link(destination: url) {
                            Image(systemName: "envelope.fill")
                                .font(.caption)
                                .padding(6)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Circle())
                        }
                    }

                    // Phone
                    if let sup = supplierRecord, !sup.phone.isEmpty,
                       let phoneURL = URL(string: "tel:\(sup.phone.replacingOccurrences(of: " ", with: ""))") {
                        Link(destination: phoneURL) {
                            Image(systemName: "phone.fill")
                                .font(.caption)
                                .padding(6)
                                .background(Color.green.opacity(0.1))
                                .foregroundStyle(.green)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.trailing)
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

// MARK: - Supplier Order Compose (from SupplierDetailView)

struct SupplierOrderComposeView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss
    let supplier: Supplier

    @State private var copiedToClipboard = false

    // Items for this supplier (low-stock items linked to this supplier, or all purchase-list items)
    private var relevantItems: [InventoryItem] {
        let linked = store.inventoryItems.filter { item in
            item.name.localizedCaseInsensitiveContains(supplier.name) ||
            supplier.name.localizedCaseInsensitiveContains(item.name)
        }
        if !linked.isEmpty { return linked }
        return store.purchaseList
    }

    private func buildOrderText() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy"
        var lines: [String] = [
            "ЗАЯВКА НА ПОСТАВКУ",
            "Дата: \(df.string(from: Date()))",
            "Ресторан: \(store.restaurantName)",
            "Поставщик: \(supplier.name)",
            "",
            "Товар | Кол-во | Ед."
        ]
        for item in relevantItems {
            let needed = max(item.minQuantity - item.quantity, 0)
            lines.append("• \(item.name) | \(String(format: "%.1f", needed)) | \(item.effectiveOrderUnit)")
        }
        lines.append("\nОтветственный: \(store.profile.name)")
        return lines.joined(separator: "\n")
    }

    private func shareViaWhatsApp() {
        let text = buildOrderText()
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "whatsapp://send?text=\(encoded)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                UIPasteboard.general.string = text
                copiedToClipboard = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedToClipboard = false }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Order text preview
                    BigCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Текст заявки", systemImage: "doc.text").font(.headline)
                            Divider()
                            Text(buildOrderText())
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }

                    // Items list
                    if relevantItems.isEmpty {
                        EmptyStateView(icon: "cart", title: "Нет товаров для заказа",
                                       subtitle: "Добавьте позиции на склад и свяжите их с поставщиком.")
                    } else {
                        SectionTitle(title: "Позиции (\(relevantItems.count))")
                        ForEach(relevantItems) { item in
                            BigCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).font(.subheadline.bold())
                                        Text("Остаток: \(item.quantity, specifier: "%.1f") \(item.unit)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        let needed = max(item.minQuantity - item.quantity, 0)
                                        Text("\(needed, specifier: "%.1f") \(item.effectiveOrderUnit)")
                                            .font(.subheadline.bold()).foregroundStyle(.chefAccent)
                                        Text("к заказу").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Share buttons
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Button { shareViaWhatsApp() } label: {
                                Label("WhatsApp", systemImage: "message.fill")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            if !supplier.email.isEmpty,
                               let subjectEncoded = "Заявка на поставку".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                               let bodyEncoded = buildOrderText().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                               let url = URL(string: "mailto:\(supplier.email)?subject=\(subjectEncoded)&body=\(bodyEncoded)") {
                                Link(destination: url) {
                                    Label("Email", systemImage: "envelope.fill")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            } else {
                                Label("Email не задан", systemImage: "envelope")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray5))
                                    .foregroundStyle(.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        Button {
                            UIPasteboard.general.string = buildOrderText()
                            copiedToClipboard = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedToClipboard = false }
                        } label: {
                            Label(copiedToClipboard ? "Скопировано!" : "Скопировать заявку",
                                  systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding()
            }
            .background(Color.chefBackground)
            .navigationTitle("Заявка — \(supplier.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
