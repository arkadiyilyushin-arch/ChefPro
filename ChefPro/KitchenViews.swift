import SwiftUI
import AVFoundation
import VisionKit

// MARK: - Kitchen Production Board

struct KitchenBoardView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAddOrder = false
    @State private var showHistory  = false
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var newOrders:     [KitchenOrder] { store.kitchenOrders.filter { $0.status == .new } }
    var cookingOrders: [KitchenOrder] { store.kitchenOrders.filter { $0.status == .cooking } }
    var readyOrders:   [KitchenOrder] { store.kitchenOrders.filter { $0.status == .ready } }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        KanbanColumn(title: "Новые",      accent: .blue,   orders: newOrders,     now: now, columnHeight: geo.size.height - 16)
                        KanbanColumn(title: "Готовятся",  accent: .orange, orders: cookingOrders, now: now, columnHeight: geo.size.height - 16)
                        KanbanColumn(title: "Готово",     accent: .green,  orders: readyOrders,   now: now, columnHeight: geo.size.height - 16)
                    }
                    .padding()
                    .frame(minHeight: geo.size.height)
                }
            }
            .background(Color.chefBackground)
            .navigationTitle("Kitchen Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                            if !store.closedKitchenOrders.isEmpty {
                                Text("\(store.closedKitchenOrders.count)")
                                    .font(.caption2.bold())
                            }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddOrder = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddOrder) {
                AddKitchenOrderView().environmentObject(store)
            }
            .sheet(isPresented: $showHistory) {
                KitchenOrderHistoryView().environmentObject(store)
            }
            .onReceive(ticker) { now = $0 }
        }
    }
}

struct KanbanColumn: View {
    @EnvironmentObject var store: ChefProStore
    let title: String
    let accent: Color
    let orders: [KitchenOrder]
    let now: Date
    var columnHeight: CGFloat = 600

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                Text(title).font(.title3.bold())
                Spacer()
                Text("\(orders.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(accent.opacity(0.15))
                    .foregroundStyle(accent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 12)

            // Scrollable orders list
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    if orders.isEmpty {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemGray6))
                            .frame(width: 272, height: 110)
                            .overlay(Text("Пусто").foregroundStyle(.secondary))
                    } else {
                        ForEach(orders) { order in
                            KitchenOrderCard(order: order, now: now)
                                .environmentObject(store)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .frame(height: columnHeight - 52) // subtract header height
        }
        .frame(width: 280, alignment: .top)
    }
}

struct KitchenOrderCard: View {
    @EnvironmentObject var store: ChefProStore
    let order: KitchenOrder
    let now: Date

    private var timerBase: Date {
        switch order.status {
        case .new:     return order.createdAt
        case .cooking: return order.cookingStartedAt ?? order.createdAt
        case .ready:   return order.readyAt ?? order.createdAt
        }
    }

    private var elapsed: TimeInterval { now.timeIntervalSince(timerBase) }

    private var dishCookSeconds: TimeInterval? {
        let t = store.dishes.first(where: { $0.name == order.dishName })?.cookTime ?? 0
        return t > 0 ? TimeInterval(t * 60) : nil
    }

    private var timerString: String {
        if order.status == .cooking, let target = dishCookSeconds {
            let remaining = target - elapsed
            if remaining > 0 {
                let m = Int(remaining) / 60; let s = Int(remaining) % 60
                return String(format: "-%02d:%02d", m, s)
            } else {
                let over = -remaining
                let m = Int(over) / 60; let s = Int(over) % 60
                return String(format: "+%02d:%02d", m, s)
            }
        }
        let m = Int(elapsed) / 60; let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var timerColor: Color {
        guard order.status != .ready else { return .secondary }
        if order.status == .cooking, let target = dishCookSeconds {
            if elapsed > target        { return .red }
            if elapsed > target * 0.75 { return .orange }
            return .green
        }
        if elapsed < 600  { return .green }
        if elapsed < 1200 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header: dish name + timer
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.dishName)
                        .font(.headline)
                        .lineLimit(2)
                    if !order.tableNumber.isEmpty {
                        Label("Стол \(order.tableNumber)", systemImage: "tablecells")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if order.course > 1 || !order.tableNumber.isEmpty {
                        Text(order.courseName)
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                Text(timerString)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundStyle(timerColor)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(timerColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Portions badge
            HStack(spacing: 10) {
                Text("\(order.portions)")
                    .font(.system(size: 40, weight: .bold))
                Text("порц.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            // Note
            if !order.note.isEmpty {
                Text(order.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Action button
            if let next = order.status.next {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.advanceOrderStatus(order)
                } label: {
                    Label(order.status.actionLabel, systemImage: next.icon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(next.color)
                        .foregroundStyle(.white)
                        .font(.headline)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    store.archiveKitchenOrder(order)
                } label: {
                    Text("Закрыть заказ")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        .frame(width: 280)
    }
}

struct AddKitchenOrderView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDishID: UUID? = nil
    @State private var dishName    = ""
    @State private var portions    = "1"
    @State private var tableNumber = ""
    @State private var note        = ""

    private var canSave: Bool {
        !dishName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(portions) ?? 0) >= 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Блюдо") {
                    if !store.dishes.isEmpty {
                        Picker("Из техкарт", selection: $selectedDishID) {
                            Text("— не выбрано —").tag(nil as UUID?)
                            ForEach(store.dishes) { d in
                                Text(d.name).tag(d.id as UUID?)
                            }
                        }
                        .onChange(of: selectedDishID) { _, id in
                            if let id, let d = store.dishes.first(where: { $0.id == id }) {
                                dishName = d.name
                            }
                        }
                    }
                    TextField("Название блюда", text: $dishName)
                }

                Section("Детали") {
                    HStack {
                        Text("Порций")
                        Spacer()
                        TextField("1", text: $portions)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: portions) { _, v in
                                if v.count > 3 { portions = String(v.prefix(3)) }
                            }
                    }
                    HStack {
                        Text("Стол")
                        Spacer()
                        TextField("Необязательно", text: $tableNumber)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    TextField("Примечание (без глютена…)", text: $note)
                }
            }
            .navigationTitle("Новый заказ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let order = KitchenOrder(
            dishName:    dishName.trimmingCharacters(in: .whitespaces),
            portions:    Int(portions) ?? 1,
            tableNumber: tableNumber.trimmingCharacters(in: .whitespaces),
            note:        note.trimmingCharacters(in: .whitespaces)
        )
        store.addKitchenOrder(order)
        dismiss()
    }
}

// MARK: - Kitchen Mode

struct KitchenDishButton: View {
    let dish: Dish
    let foodCostPct: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.chefAccent)
                Text(dish.name)
                    .font(.title3).bold().multilineTextAlignment(.leading)
                Text("Food cost \(foodCostPct, specifier: "%.0f")%")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(Color.chefCard)
            .clipShape(RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(.plain)
    }
}

struct KitchenModeView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedDish: Dish?

    let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BigCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Kitchen Mode")
                            .font(.largeTitle)
                            .bold()
                        Text("Большие кнопки для кухни и работы в перчатках")
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.dishes) { dish in
                        KitchenDishButton(
                            dish: dish,
                            foodCostPct: store.foodCostPercent(dish),
                            action: { selectedDish = dish }
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color.black.opacity(0.92))
        .foregroundStyle(.white)
        .navigationTitle("Kitchen Mode")
        .onAppear    { UIApplication.shared.isIdleTimerDisabled = true  }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(item: $selectedDish) { dish in
            ProduceDishView(dish: dish)
                .environmentObject(store)
        }
    }
}

// MARK: - Purchases

struct PurchaseItemCard: View {
    let item: InventoryItem

    var body: some View {
        let recommended = max(item.minQuantity * 2 - item.quantity, item.minQuantity)
        BigCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(item.name).font(.title3).bold()
                    Spacer()
                    Text("Нужно").font(.caption).foregroundStyle(.orange)
                }
                Text(item.category).foregroundStyle(.secondary)
                HStack {
                    Text("Остаток: \(item.quantity, specifier: "%.1f") \(item.unit)")
                    Spacer()
                    Text("Мин: \(item.minQuantity, specifier: "%.1f") \(item.unit)")
                }
                .font(.subheadline)
                Text("Рекомендованный заказ: \(recommended, specifier: "%.1f") \(item.unit)")
                    .font(.headline).foregroundStyle(Color.chefAccent)
            }
        }
    }
}

struct PurchasesView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showShare   = false
    @State private var showAddItem = false
    @State private var orderText   = ""

    private var totalCount: Int { store.purchaseList.count + store.extraPurchaseItems.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                InfoCard(
                    title: "К заказу",
                    value: "\(totalCount)",
                    subtitle: store.extraPurchaseItems.isEmpty
                        ? "позиций (нехватка на складе)"
                        : "\(store.purchaseList.count) авто + \(store.extraPurchaseItems.count) вручную",
                    icon: "cart.fill"
                )

                // ── Авто-список (нехватка) ────────────────────────
                if !store.purchaseList.isEmpty {
                    sectionHeader("Нехватка на складе", systemImage: "exclamationmark.triangle.fill", color: .orange)
                    ForEach(store.purchaseList) { item in
                        PurchaseItemCard(item: item)
                    }
                }

                // ── Добавленные вручную ───────────────────────────
                if !store.extraPurchaseItems.isEmpty {
                    sectionHeader("Добавлено вручную", systemImage: "pencil.circle.fill", color: .blue)
                    ForEach(store.extraPurchaseItems) { item in
                        extraItemCard(item)
                    }
                }

                // ── Empty state ───────────────────────────────────
                if totalCount == 0 {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "Закупки не нужны",
                        subtitle: "Все продукты выше минимального остатка.\nДобавьте позиции вручную если нужно."
                    )
                }

                // ── Action buttons ────────────────────────────────
                if totalCount > 0 {
                    BigActionButton(title: "Сформировать заявку", icon: "square.and.arrow.up") {
                        orderText = buildOrderText()
                        showShare = true
                    }

                    if !store.extraPurchaseItems.isEmpty {
                        Button(role: .destructive) {
                            store.clearExtraPurchaseItems()
                        } label: {
                            Label("Очистить ручные позиции", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Закупки")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [orderText])
        }
        .sheet(isPresented: $showAddItem) {
            AddExtraPurchaseItemView { item in
                store.addExtraPurchaseItem(item)
            }
            .environmentObject(store)
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.bold())
            .foregroundStyle(color)
            .padding(.top, 4)
    }

    private func extraItemCard(_ item: ExtraPurchaseItem) -> some View {
        BigCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline)
                    if !item.note.isEmpty {
                        Text(item.note).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.quantity, specifier: "%.1f") \(item.unit)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Text("вручную").font(.caption2).foregroundStyle(.secondary)
                }
                Button {
                    store.removeExtraPurchaseItem(item)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Order text

    private func buildOrderText() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy"
        var lines = ["Заявка на закупку — \(store.restaurantName)", "Дата: \(df.string(from: Date()))", ""]

        if !store.purchaseList.isEmpty {
            lines.append("=== Нехватка на складе ===")
            for item in store.purchaseList {
                let neededStorage = max(0, item.minQuantity - item.quantity)
                if !item.orderUnit.isEmpty && item.orderUnitRatio > 0 {
                    let neededOrder = (neededStorage / item.orderUnitRatio).rounded(.up)
                    lines.append("• \(item.name): \(String(format: "%.0f", neededOrder)) \(item.orderUnit)  (≈\(String(format: "%.1f", neededStorage)) \(item.unit), остаток: \(String(format: "%.1f", item.quantity)) \(item.unit))")
                } else {
                    lines.append("• \(item.name): \(String(format: "%.1f", neededStorage)) \(item.unit)  (остаток: \(String(format: "%.1f", item.quantity)) \(item.unit), мин: \(String(format: "%.1f", item.minQuantity)) \(item.unit))")
                }
            }
            lines.append("")
        }

        if !store.extraPurchaseItems.isEmpty {
            lines.append("=== Добавлено вручную ===")
            for item in store.extraPurchaseItems {
                var line = "• \(item.name): \(String(format: "%.1f", item.quantity)) \(item.unit)"
                if !item.note.isEmpty { line += "  (\(item.note))" }
                lines.append(line)
            }
            lines.append("")
        }

        lines.append("Итого позиций: \(totalCount)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Add Extra Purchase Item

struct AddExtraPurchaseItemView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss
    let onSave: (ExtraPurchaseItem) -> Void

    @State private var name     = ""
    @State private var quantity = ""
    @State private var unit     = "кг"
    @State private var note     = ""
    @State private var showSuggestions = false

    let units = ["кг", "г", "л", "мл", "шт", "порц", "уп", "ящ"]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        parsePositiveDouble(quantity) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Продукт") {
                    TextField("Название", text: $name)
                        .onChange(of: name) { _, _ in
                            showSuggestions = !name.trimmingCharacters(in: .whitespaces).isEmpty
                        }
                    InventoryProductSuggestions(query: name, show: $showSuggestions) { item in
                        name = item.name
                        unit = item.unit
                    }

                    HStack(spacing: 8) {
                        TextField("Количество", text: $quantity)
                            .keyboardType(.decimalPad)
                        Picker("", selection: $unit) {
                            ForEach(units, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }
                }

                Section("Примечание") {
                    TextField("Комментарий (необязательно)", text: $note, axis: .vertical)
                        .lineLimit(2...3)
                }
            }
            .navigationTitle("Добавить к заказу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let item = ExtraPurchaseItem(
                            name:     name.trimmingCharacters(in: .whitespaces),
                            quantity: parsePositiveDouble(quantity) ?? 0,
                            unit:     unit,
                            note:     note.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(item)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - PDF Reports View

struct PDFReportsView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedReport: ChefPDFReportType = .inventory
    @State private var pdfURL: URL?
    @State private var showShare = false
    @State private var showPDFError = false

    var body: some View {
        Form {
            Section("Тип отчета") {
                Picker("Отчет", selection: $selectedReport) {
                    ForEach(ChefPDFReportType.allCases) { report in
                        Text(report.rawValue).tag(report)
                    }
                }
            }

            Section("PDF") {
                Button {
                    pdfURL = PDFReportGenerator.createReport(type: selectedReport, store: store)
                    if pdfURL != nil {
                        showShare = true
                    } else {
                        showPDFError = true
                    }
                } label: {
                    Label("Создать PDF", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .frame(minHeight: 44)
                }

                if let pdfURL {
                    Text(pdfURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("PDF-отчеты")
        .sheet(isPresented: $showShare) {
            if let pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
        .alert("Ошибка создания PDF", isPresented: $showPDFError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Не удалось создать PDF. Проверьте свободное место на устройстве.")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - QR / Barcode

struct BarcodeScannerView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var scannedCode  = ""
    @State private var showScanner  = false
    @State private var showLinkPicker = false
    @State private var linkItemID: UUID? = nil

    private var matchedItem: InventoryItem? { store.inventoryItem(forBarcode: scannedCode) }

    var body: some View {
        Form {
            Section("Сканирование") {
                Button {
                    showScanner = true
                } label: {
                    Label("Открыть сканер", systemImage: "barcode.viewfinder")
                        .font(.headline).frame(minHeight: 50)
                }
                TextField("Или введите код вручную", text: $scannedCode)
                    .textInputAutocapitalization(.never)
            }

            if !scannedCode.isEmpty {
                Section("Результат") {
                    HStack {
                        Image(systemName: "barcode").foregroundStyle(.secondary)
                        Text(scannedCode).font(.system(.body, design: .monospaced))
                    }

                    if let item = matchedItem {
                        NavigationLink {
                            InventoryDetailView(item: item).environmentObject(store)
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.headline)
                                    Text("\(item.quantity, specifier: "%.1f") \(item.unit) · \(item.category)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "questionmark.circle").foregroundStyle(.orange)
                            Text("Товар не найден")
                        }
                        Picker("Привязать к товару", selection: $linkItemID) {
                            Text("— выбрать —").tag(UUID?.none)
                            ForEach(store.inventoryItems) { item in
                                Text(item.name).tag(Optional(item.id))
                            }
                        }
                        if let id = linkItemID {
                            Button("Сохранить привязку") {
                                if let idx = store.inventoryItems.firstIndex(where: { $0.id == id }) {
                                    store.inventoryItems[idx].barcode = scannedCode
                                    linkItemID = nil
                                }
                            }
                            .foregroundStyle(.chefAccent)
                        }
                    }
                }
            }
        }
        .navigationTitle("QR / Barcode")
        .sheet(isPresented: $showScanner) {
            DataScannerScreen(scannedCode: $scannedCode)
        }
    }
}

struct DataScannerScreen: View {
    @Environment(\.dismiss) var dismiss
    @Binding var scannedCode: String
    @State private var scannerStartError = false

    var body: some View {
        NavigationStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(
                    scannedCode: $scannedCode,
                    onStartError: { scannerStartError = true },
                    onScan: { dismiss() }
                )
                .navigationTitle("Сканер")
                .toolbar {
                    Button("Закрыть") { dismiss() }
                }
                .alert("Ошибка сканера", isPresented: $scannerStartError) {
                    Button("OK") { dismiss() }
                } message: {
                    Text("Не удалось запустить сканер. Проверьте разрешение на использование камеры.")
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.secondary)
                    Text("Сканер недоступен")
                        .font(.title2)
                        .bold()
                    Text("Проверь устройство, камеру и разрешение.")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .navigationTitle("Сканер")
                .toolbar {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedCode: String
    var onStartError: (() -> Void)?
    var onScan: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator

        do {
            try scanner.startScanning()
        } catch {
            onStartError?()
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scannedCode, onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var scannedCode: String
        var onScan: () -> Void

        init(scannedCode: Binding<String>, onScan: @escaping () -> Void) {
            _scannedCode = scannedCode
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .barcode(let barcode):
                guard let payload = barcode.payloadStringValue, !payload.isEmpty else { return }
                scannedCode = payload
                onScan()
            default:
                break
            }
        }
    }
}
