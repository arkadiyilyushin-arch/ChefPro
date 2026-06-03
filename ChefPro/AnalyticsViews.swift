import SwiftUI
import Charts

// MARK: - Reports helpers

struct ProductionRowCard: View {
    @EnvironmentObject var store: ChefProStore
    let item: Production

    var body: some View {
        BigCard {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.dishName).font(.headline)
                    Text("\(item.portions) порц. • \(item.employee)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.totalCost, specifier: "%.2f")")
                        .bold().foregroundStyle(Color.chefAccent)
                    let expectedWeight = store.dishes.first(where: { $0.name == item.dishName })?.portionWeight ?? 0
                    let actual = item.actualPortionWeight
                    if actual > 0 && expectedWeight > 0 {
                        let deviation = (actual - expectedWeight) / expectedWeight * 100
                        let color: Color = abs(deviation) > 10 ? .red : .green
                        Label("\(String(format: "%+.0f", deviation))%", systemImage: "scalemass")
                            .font(.caption.bold())
                            .foregroundStyle(color)
                    }
                }
            }
        }
    }
}

struct LowStockRowCard: View {
    let item: InventoryItem

    var body: some View {
        BigCard {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name).font(.headline)
                    Text(item.category).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(item.quantity, specifier: "%.1f") \(item.unit)")
                    .foregroundStyle(.red).bold()
            }
        }
    }
}

struct ReportsView: View {
    @EnvironmentObject var store: ChefProStore

    var productionCost: Double {
        store.productions.reduce(0) { $0 + $1.totalCost }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    InfoCard(title: "Приемка", value: "\(Int(store.totalDeliverySum))", subtitle: "расходы", icon: "tray.and.arrow.down.fill")
                    InfoCard(title: "Производство", value: "\(Int(productionCost))", subtitle: "себестоимость", icon: "flame.fill")
                }

                HStack {
                    InfoCard(title: "Списания", value: "\(store.writeOffs.count)", subtitle: "операции", icon: "trash.fill")
                    InfoCard(title: "Низкий остаток", value: "\(store.lowStockItems.count)", subtitle: "позиции", icon: "exclamationmark.triangle.fill")
                }

                SectionTitle(title: "Последнее производство")

                if store.productions.isEmpty {
                    BigCard {
                        Text("Производства пока нет")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(store.productions.reversed()) { item in
                        ProductionRowCard(item: item)
                    }
                }

                SectionTitle(title: "Низкие остатки")

                if store.lowStockItems.isEmpty {
                    BigCard {
                        Text("Низких остатков нет")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(store.lowStockItems) { item in
                        LowStockRowCard(item: item)
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Отчеты")
    }
}

// MARK: - Menu Engineering

enum MenuZone: String {
    case star      = "⭐ Звёзды"
    case cashCow   = "🐄 Рабочие лошади"
    case puzzle    = "❓ Загадки"
    case dog       = "🐕 Аутсайдеры"

    var description: String {
        switch self {
        case .star:    return "Популярные и прибыльные. Продвигайте активно."
        case .cashCow: return "Популярные, но дорогие в производстве. Оптимизируйте рецептуру."
        case .puzzle:  return "Прибыльные, но редко заказывают. Улучшайте подачу и продвижение."
        case .dog:     return "Низкие продажи и маржа. Рассмотрите удаление из меню."
        }
    }

    var color: Color {
        switch self {
        case .star:    return .green
        case .cashCow: return .orange
        case .puzzle:  return .blue
        case .dog:     return .red
        }
    }
}

struct DishMetric: Identifiable {
    let id:         UUID
    let dish:       Dish
    let portions:   Int
    let margin:     Double   // (salePrice - cost) / salePrice, higher = better
    let foodCostPct: Double
    var zone:       MenuZone = .dog
}

struct MenuEngineeringView: View {
    @EnvironmentObject var store: ChefProStore

    private var metrics: [DishMetric] {
        var items = store.dishes.map { dish -> DishMetric in
            let portions    = store.productions.filter { $0.dishName == dish.name }.reduce(0) { $0 + $1.portions }
            let cost        = store.calculateDishCost(dish)
            let margin      = dish.salePrice > 0 ? (dish.salePrice - cost) / dish.salePrice : 0
            let fc          = store.foodCostPercent(dish)
            return DishMetric(id: dish.id, dish: dish, portions: portions, margin: margin, foodCostPct: fc)
        }
        guard !items.isEmpty else { return items }
        let medPop    = items.map(\.portions).sorted()[items.count / 2]
        let medMargin = items.map(\.margin).sorted()[items.count / 2]
        for i in items.indices {
            let high = items[i].portions >= medPop
            let prof = items[i].margin  >= medMargin
            items[i].zone = high && prof ? .star : high ? .cashCow : prof ? .puzzle : .dog
        }
        return items
    }

    private var zones: [MenuZone] { [.star, .cashCow, .puzzle, .dog] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BigCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Menu Engineering", systemImage: "chart.bar.xaxis").font(.headline)
                        Text("Классификация блюд по популярности и прибыльности на основе истории производства.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if store.productions.isEmpty {
                    EmptyStateView(icon: "chart.bar.xaxis", title: "Нет данных",
                                  subtitle: "Добавьте производство блюд — тогда появится классификация.")
                } else {
                    ForEach(zones, id: \.rawValue) { zone in
                        let zoneItems = metrics.filter { $0.zone == zone }
                        if !zoneItems.isEmpty {
                            SectionTitle(title: zone.rawValue)
                            Text(zone.description)
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            ForEach(zoneItems) { m in
                                BigCard {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(zone.color.opacity(0.12))
                                                .frame(width: 50, height: 50)
                                            Text(zoneEmoji(zone))
                                                .font(.title2)
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(m.dish.name).font(.headline)
                                            Text(m.dish.category).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("\(m.portions) порц.")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(zone.color)
                                            Text("FC \(Int(m.foodCostPct))%")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Menu Engineering")
    }

    private func zoneEmoji(_ zone: MenuZone) -> String {
        switch zone {
        case .star:    return "⭐"
        case .cashCow: return "🐄"
        case .puzzle:  return "❓"
        case .dog:     return "🐕"
        }
    }
}

// MARK: - Kitchen Order History

struct KitchenOrderHistoryView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.closedKitchenOrders.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", title: "История пуста", subtitle: "Закрытые заказы появятся здесь.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.closedKitchenOrders) { order in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(order.dishName).font(.headline)
                                    Spacer()
                                    Text("\(order.portions) порц.")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.chefAccent)
                                }
                                HStack(spacing: 8) {
                                    if !order.tableNumber.isEmpty {
                                        Label("Стол \(order.tableNumber)", systemImage: "tablecells")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let ready = order.readyAt {
                                        Label(ready.formatted(date: .omitted, time: .shortened), systemImage: "checkmark.circle")
                                            .font(.caption).foregroundStyle(.green)
                                    }
                                    if let cook = order.cookingStartedAt, let ready = order.readyAt {
                                        let mins = Int(ready.timeIntervalSince(cook)) / 60
                                        Label("\(mins) мин.", systemImage: "flame.fill")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { offsets in
                            store.closedKitchenOrders.remove(atOffsets: offsets)
                        }
                    }
                }
            }
            .navigationTitle("История заказов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                if !store.closedKitchenOrders.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Очистить", role: .destructive) {
                            store.closedKitchenOrders.removeAll()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Analytics

struct AnalyticsView: View {
    @EnvironmentObject var store: ChefProStore

    private var foodCostData: [(name: String, pct: Double)] {
        store.dishes.map { dish in
            (name: dish.name, pct: store.foodCostPercent(dish))
        }.sorted { $0.pct > $1.pct }
    }

    private struct DailyDelivery: Identifiable {
        var id: Date { date }
        let date: Date
        let total: Double
    }

    private var deliveryByDay: [DailyDelivery] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: store.deliveries) { d in
            cal.startOfDay(for: d.date)
        }
        return grouped.map { DailyDelivery(date: $0.key, total: $0.value.reduce(0) { $0 + $1.price }) }
            .sorted { $0.date < $1.date }
    }

    private struct DishProduction: Identifiable {
        var id: String { name }
        let name: String
        let count: Int
    }

    private var productionByDish: [DishProduction] {
        let grouped = Dictionary(grouping: store.productions) { $0.dishName }
        return grouped.map { DishProduction(name: $0.key, count: $0.value.reduce(0) { $0 + $1.portions }) }
            .sorted { $0.count > $1.count }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Food Cost ──────────────────────────────────
                BigCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Food Cost по блюдам", systemImage: "percent")
                            .font(.headline)

                        if foodCostData.isEmpty {
                            Text("Добавьте блюда в техкарты")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Chart(foodCostData, id: \.name) { item in
                                BarMark(
                                    x: .value("Блюдо", item.name),
                                    y: .value("Food Cost %", item.pct)
                                )
                                .foregroundStyle(item.pct < 30 ? Color.green : item.pct < 40 ? Color.orange : Color.red)
                                .cornerRadius(6)
                                .annotation(position: .top) {
                                    Text("\(Int(item.pct))%")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisValueLabel(orientation: .vertical) {
                                        if let s = value.as(String.self) {
                                            Text(s).font(.caption2).lineLimit(2)
                                        }
                                    }
                                }
                            }
                            .chartYAxisLabel("%")
                            .frame(height: 200)

                            HStack(spacing: 16) {
                                legendDot(color: .green,  label: "< 30%")
                                legendDot(color: .orange, label: "30–40%")
                                legendDot(color: .red,    label: "> 40%")
                            }
                            .font(.caption)
                        }
                    }
                }

                // ── Закупки ────────────────────────────────────
                BigCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Расходы на закупки", systemImage: "cart.fill")
                            .font(.headline)

                        if deliveryByDay.isEmpty {
                            Text("Нет данных о приёмках")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Chart(deliveryByDay) { item in
                                LineMark(
                                    x: .value("Дата", item.date, unit: .day),
                                    y: .value("Сумма", item.total)
                                )
                                .foregroundStyle(Color.chefAccent)
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Дата", item.date, unit: .day),
                                    y: .value("Сумма", item.total)
                                )
                                .foregroundStyle(Color.orange.opacity(0.12))
                                .interpolationMethod(.catmullRom)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { value in
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                }
                            }
                            .frame(height: 160)
                        }
                    }
                }

                // ── Производство ───────────────────────────────
                BigCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Топ производство (порций)", systemImage: "flame.fill")
                            .font(.headline)

                        if productionByDish.isEmpty {
                            Text("Производства пока нет")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Chart(productionByDish) { item in
                                BarMark(
                                    x: .value("Порций", item.count),
                                    y: .value("Блюдо",  item.name)
                                )
                                .foregroundStyle(Color.chefAccent)
                                .cornerRadius(6)
                                .annotation(position: .trailing) {
                                    Text("\(item.count)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .chartXAxisLabel("Порций")
                            .frame(height: max(160, CGFloat(productionByDish.count) * 36))
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Аналитика")
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Sales

struct SalesView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd = false

    private var grouped: [(String, [Sale])] {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy"
        let dict = Dictionary(grouping: store.sales.reversed()) { df.string(from: $0.date) }
        return dict.sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            if store.sales.isEmpty {
                EmptyStateView(
                    icon: "bag",
                    title: "Продаж нет",
                    subtitle: "Добавьте продажи или выполните план производства."
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(grouped, id: \.0) { date, items in
                    Section(date) {
                        ForEach(items) { sale in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sale.dishName).font(.headline)
                                    Text(sale.employee).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(sale.portions) порц.")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.chefAccent)
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { items[$0].id }
                            store.sales.removeAll { ids.contains($0.id) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Продажи")
        .toolbar {
            Button { showAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAdd) {
            AddSaleView().environmentObject(store)
        }
    }
}

struct AddSaleView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDishID: UUID? = nil
    @State private var portions = 1
    @State private var employee = ""

    private var canSave: Bool { selectedDishID != nil && portions >= 1 }

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
                Section("Порции") {
                    Stepper("Порций: \(portions)", value: $portions, in: 1...999)
                }
                Section("Сотрудник") {
                    TextField("Кто принял заказ", text: $employee)
                }
            }
            .navigationTitle("Новая продажа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let id = selectedDishID,
                              let dish = store.dishes.first(where: { $0.id == id }) else { return }
                        let sale = Sale(
                            dishName: dish.name,
                            portions: portions,
                            date: Date(),
                            employee: employee.isEmpty ? store.profile.name : employee
                        )
                        store.addSale(sale)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear { employee = store.profile.name }
    }
}

// MARK: - Profit & Loss

struct ProfitLossView: View {
    @EnvironmentObject var store: ChefProStore

    enum Period: String, CaseIterable { case today = "Сегодня"; case week = "Неделя"; case month = "Месяц"; case all = "Всё время" }
    @State private var period: Period = .week

    private var since: Date {
        let cal = Calendar.current
        switch period {
        case .today: return cal.startOfDay(for: Date())
        case .week:  return cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month: return cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .all:   return .distantPast
        }
    }

    private var revenue: Double {
        store.sales.filter { $0.date >= since }.reduce(0.0) { total, sale in
            let price = store.dishes.first(where: { $0.name == sale.dishName })?.salePrice ?? 0
            return total + price * Double(sale.portions)
        }
    }

    private var cogs: Double {
        store.productions.filter { $0.date >= since }.reduce(0.0) { $0 + $1.totalCost }
    }

    private var grossProfit: Double { revenue - cogs }
    private var grossMarginPct: Double { revenue > 0 ? grossProfit / revenue * 100 : 0 }

    private var deliveryCosts: Double {
        store.deliveries.filter { $0.date >= since }.reduce(0.0) { $0 + $1.price }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Период", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Сводка
                HStack(spacing: 14) {
                    plCard(title: "Выручка", value: revenue, color: .green, icon: "arrow.up.circle.fill")
                    plCard(title: "Себест.", value: cogs,    color: .orange, icon: "flame.fill")
                }
                HStack(spacing: 14) {
                    plCard(title: "Валовая прибыль", value: grossProfit,
                           color: grossProfit >= 0 ? .green : .red, icon: "chart.line.uptrend.xyaxis")
                    BigCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Маржа", systemImage: "percent").font(.subheadline).foregroundStyle(.secondary)
                            Text("\(grossMarginPct, specifier: "%.1f")%")
                                .font(.title2.bold())
                                .foregroundStyle(grossMarginPct >= 60 ? Color.green : grossMarginPct >= 40 ? Color.orange : Color.red)
                        }
                    }
                }

                BigCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Детализация", systemImage: "list.bullet.rectangle").font(.headline)
                        Divider()
                        plRow(label: "Продажи (шт.)",       value: "\(store.sales.filter { $0.date >= since }.reduce(0) { $0 + $1.portions }) порц.")
                        plRow(label: "Производств",          value: "\(store.productions.filter { $0.date >= since }.count)")
                        plRow(label: "Приёмок на сумму",     value: String(format: "%.2f", deliveryCosts))
                        plRow(label: "Списаний",             value: "\(store.writeOffs.filter { $0.date >= since }.count) шт.")
                    }
                }

                if store.sales.isEmpty {
                    EmptyStateView(icon: "bag", title: "Нет данных о продажах",
                                  subtitle: "Добавляйте продажи в разделе «Продажи» для расчёта выручки.")
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("P&L")
    }

    private func plCard(title: String, value: Double, color: Color, icon: String) -> some View {
        BigCard {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon).font(.subheadline).foregroundStyle(.secondary)
                Text("\(value, specifier: "%.2f")")
                    .font(.title2.bold()).foregroundStyle(color)
            }
        }
    }

    private func plRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
        .font(.subheadline)
    }
}

// MARK: - CSV Export

struct CSVExportView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showShare = false
    @State private var csvURL: URL?

    enum CSVType: String, CaseIterable, Identifiable {
        case sales       = "Продажи"
        case productions = "Производство"
        case writeOffs   = "Списания"
        case deliveries  = "Приёмки"
        case inventory   = "Склад"
        case dishes      = "Техкарты"
        var id: String { rawValue }
    }
    @State private var selected: CSVType = .sales

    var body: some View {
        Form {
            Section("Тип данных") {
                Picker("Данные", selection: $selected) {
                    ForEach(CSVType.allCases) { t in Text(t.rawValue).tag(t) }
                }
            }
            Section {
                Button {
                    csvURL = buildCSV(type: selected)
                    if csvURL != nil { showShare = true }
                } label: {
                    Label("Экспорт в CSV", systemImage: "square.and.arrow.up")
                        .font(.headline).frame(minHeight: 44)
                }
                if let url = csvURL {
                    Text(url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("CSV-экспорт")
        .sheet(isPresented: $showShare) {
            if let url = csvURL { ShareSheet(items: [url]) }
        }
    }

    private func buildCSV(type: CSVType) -> URL? {
        var lines: [String] = []
        switch type {
        case .sales:
            lines = ["Блюдо,Порции,Дата,Сотрудник"] + store.sales.map {
                "\($0.dishName),\($0.portions),\($0.date.formatted()),\($0.employee)"
            }
        case .productions:
            lines = ["Блюдо,Порции,Себестоимость,Дата,Сотрудник"] + store.productions.map {
                "\($0.dishName),\($0.portions),\(String(format: "%.2f",$0.totalCost)),\($0.date.formatted()),\($0.employee)"
            }
        case .writeOffs:
            lines = ["Продукт,Количество,Единица,Причина,Сотрудник,Дата"] + store.writeOffs.map {
                "\($0.productName),\(String(format: "%.2f",$0.quantity)),\($0.unit),\($0.reason),\($0.employee),\($0.date.formatted())"
            }
        case .deliveries:
            lines = ["Поставщик,Продукт,Количество,Единица,Сумма,Принял,Дата,Примечание"] + store.deliveries.map {
                "\($0.supplier),\($0.productName),\(String(format: "%.2f",$0.quantity)),\($0.unit),\(String(format: "%.2f",$0.price)),\($0.acceptedBy),\($0.date.formatted()),\($0.notes)"
            }
        case .inventory:
            lines = ["Название;Категория;Количество;Единица;Мин.остаток;Цена/ед;Стоимость;Штрихкод"] + store.inventoryItems.map {
                let cost = $0.quantity * $0.pricePerUnit
                return "\($0.name);\($0.category);\(String(format: "%.2f",$0.quantity));\($0.unit);\(String(format: "%.2f",$0.minQuantity));\(String(format: "%.2f",$0.pricePerUnit));\(String(format: "%.2f",cost));\($0.barcode)"
            }
        case .dishes:
            lines = ["Название;Категория;Цена продажи;Себестоимость;Food Cost %;Статус"] + store.dishes.map {
                let cost = store.calculateDishCost($0)
                let fc = $0.salePrice > 0 ? (cost / $0.salePrice * 100) : 0
                return "\($0.name);\($0.category);\(String(format: "%.2f",$0.salePrice));\(String(format: "%.2f",cost));\(String(format: "%.1f",fc));\($0.menuStatus.rawValue)"
            }
        }
        let csv = lines.joined(separator: "\n")
        let fileName = "ChefPro_\(type.rawValue)_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Food Cost Trend

struct FoodCostTrendView: View {
    @EnvironmentObject var store: ChefProStore

    private struct FCPoint: Identifiable {
        let id = UUID()
        let date: Date
        let dish: String
        let pct: Double
    }

    private var points: [FCPoint] {
        store.productions.flatMap { prod -> [FCPoint] in
            guard let dish = store.dishes.first(where: { $0.name == prod.dishName }) else { return [] }
            return [FCPoint(date: prod.date, dish: dish.name, pct: store.foodCostPercent(dish))]
        }
        .sorted { $0.date < $1.date }
    }

    private var byDish: [String: [FCPoint]] {
        Dictionary(grouping: points, by: \.dish)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BigCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Динамика Food Cost", systemImage: "waveform.path.ecg").font(.headline)
                        Text("Food cost % по блюдам на основе истории производства.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if points.isEmpty {
                    EmptyStateView(icon: "waveform", title: "Нет данных",
                                  subtitle: "Производите блюда — здесь появится динамика FC%.")
                } else {
                    BigCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Все блюда").font(.headline)
                            Chart(points) { p in
                                LineMark(
                                    x: .value("Дата", p.date),
                                    y: .value("FC%", p.pct)
                                )
                                .foregroundStyle(by: .value("Блюдо", p.dish))
                                RuleMark(y: .value("Порог", store.foodCostThreshold))
                                    .lineStyle(StrokeStyle(dash: [5]))
                                    .foregroundStyle(.red.opacity(0.5))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("\(Int(store.foodCostThreshold))%")
                                            .font(.caption2).foregroundStyle(.red)
                                    }
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) {
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                }
                            }
                            .frame(height: 200)
                        }
                    }

                    ForEach(byDish.sorted(by: { $0.key < $1.key }), id: \.key) { dish, pts in
                        BigCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(dish).font(.headline)
                                    Spacer()
                                    Text("Текущий: \(store.foodCostPercent(store.dishes.first(where: { $0.name == dish }) ?? store.dishes[0]), specifier: "%.1f")%")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Chart(pts) { p in
                                    AreaMark(x: .value("Дата", p.date), y: .value("FC%", p.pct))
                                        .foregroundStyle(.chefAccent.opacity(0.15))
                                    LineMark(x: .value("Дата", p.date), y: .value("FC%", p.pct))
                                        .foregroundStyle(.chefAccent)
                                }
                                .frame(height: 80)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Динамика FC")
    }
}

// MARK: - Purchase Budget

struct PurchaseBudgetView: View {
    @EnvironmentObject var store: ChefProStore

    enum BudgetPeriod: String, CaseIterable { case month = "Этот месяц"; case quarter = "Квартал"; case year = "Год" }
    @State private var period: BudgetPeriod = .month

    private var since: Date {
        let cal = Calendar.current
        switch period {
        case .month:   return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        case .quarter: return cal.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .year:    return cal.date(byAdding: .year,  value: -1, to: Date()) ?? Date()
        }
    }

    private var spent: Double {
        store.deliveries.filter { $0.date >= since }.reduce(0) { $0 + $1.price }
    }

    private var budget: Double { store.purchaseBudget }

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(spent / budget, 1.0)
    }

    private var progressColor: Color {
        progress > 0.9 ? .red : progress > 0.7 ? .orange : .chefAccent
    }

    private struct SupplierSpend: Identifiable {
        let id = UUID(); let name: String; let amount: Double
    }

    private var bySupplier: [SupplierSpend] {
        let dict = Dictionary(grouping: store.deliveries.filter { $0.date >= since }, by: \.supplier)
            .mapValues { $0.reduce(0.0) { $0 + $1.price } }
        return dict.map { SupplierSpend(name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Период", selection: $period) {
                    ForEach(BudgetPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                BigCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Потрачено").font(.caption).foregroundStyle(.secondary)
                                Text("\(spent, specifier: "%.2f")").font(.title2.bold()).foregroundStyle(progressColor)
                            }
                            Spacer()
                            if budget > 0 {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Бюджет").font(.caption).foregroundStyle(.secondary)
                                    Text("\(budget, specifier: "%.2f")").font(.title2.bold())
                                }
                            }
                        }

                        if budget > 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                ProgressView(value: progress).tint(progressColor)
                                HStack {
                                    Text("\(Int(progress * 100))% использовано")
                                        .font(.caption).foregroundStyle(progressColor)
                                    Spacer()
                                    let remaining = budget - spent
                                    Text(remaining >= 0 ? "Остаток: \(remaining, specifier: "%.2f")" : "Перерасход: \(abs(remaining), specifier: "%.2f")")
                                        .font(.caption).foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                                }
                            }
                        } else {
                            Text("Установите бюджет в Настройках").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                if !bySupplier.isEmpty {
                    SectionTitle(title: "По поставщикам")
                    BigCard {
                        VStack(spacing: 0) {
                            Chart(bySupplier) { s in
                                BarMark(x: .value("Сумма", s.amount), y: .value("Поставщик", s.name))
                                    .foregroundStyle(.chefAccent)
                            }
                            .frame(height: CGFloat(max(bySupplier.count * 44, 80)))
                        }
                    }

                    ForEach(bySupplier) { s in
                        BigCard {
                            HStack {
                                Text(s.name).font(.headline)
                                Spacer()
                                Text("\(s.amount, specifier: "%.2f")").bold().foregroundStyle(.chefAccent)
                                if budget > 0 {
                                    Text("(\(Int(s.amount / budget * 100))%)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Бюджет закупок")
    }
}

// MARK: - Price Calculator

struct PriceCalculatorView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedDishID: UUID? = nil
    @State private var targetFoodCost: Double = 30.0
    @State private var customCost = ""

    private var selectedDish: Dish? {
        store.dishes.first(where: { $0.id == selectedDishID })
    }

    private var dishCost: Double {
        if let dish = selectedDish { return store.calculateDishCost(dish) }
        if let c = Double(customCost.replacingOccurrences(of: ",", with: ".")) { return c }
        return 0
    }

    private var recommendedPrice: Double {
        guard targetFoodCost > 0 else { return 0 }
        return dishCost / (targetFoodCost / 100)
    }

    private var currentFoodCost: Double {
        guard let dish = selectedDish, dish.salePrice > 0 else { return 0 }
        return dishCost / dish.salePrice * 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                BigCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Выбрать блюдо").font(.headline)
                        Picker("Блюдо", selection: $selectedDishID) {
                            Text("Ввести себестоимость вручную").tag(Optional<UUID>.none)
                            ForEach(store.dishes) { dish in
                                Text(dish.name).tag(Optional(dish.id))
                            }
                        }
                        .pickerStyle(.menu)

                        if selectedDish == nil {
                            HStack {
                                Text("Себестоимость")
                                Spacer()
                                TextField("0.00", text: $customCost)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                        }
                    }
                }

                BigCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Целевой Food Cost: \(Int(targetFoodCost))%").font(.headline)
                        Slider(value: $targetFoodCost, in: 10...60, step: 1).tint(.chefAccent)
                        HStack(spacing: 4) {
                            ForEach([20, 25, 30, 35, 40], id: \.self) { val in
                                Button("\(val)%") { targetFoodCost = Double(val) }
                                    .font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Int(targetFoodCost) == val ? Color.chefAccent : Color.chefCard)
                                    .foregroundStyle(Int(targetFoodCost) == val ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if dishCost > 0 {
                    BigCard {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Себестоимость").font(.caption).foregroundStyle(.secondary)
                                    Text("\(dishCost, specifier: "%.2f")").font(.title2.bold())
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Рекомендуемая цена").font(.caption).foregroundStyle(.secondary)
                                    Text("\(recommendedPrice, specifier: "%.2f")")
                                        .font(.title.bold()).foregroundStyle(.chefAccent)
                                }
                            }

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Маржа").font(.caption).foregroundStyle(.secondary)
                                    Text("\(recommendedPrice - dishCost, specifier: "%.2f")")
                                        .font(.title3.bold()).foregroundStyle(.green)
                                }
                                Spacer()
                                if let dish = selectedDish, dish.salePrice > 0 {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Текущий FC").font(.caption).foregroundStyle(.secondary)
                                        let fc = currentFoodCost
                                        Text("\(fc, specifier: "%.1f")%")
                                            .font(.title3.bold())
                                            .foregroundStyle(fc > store.foodCostThreshold ? .red : .green)
                                    }
                                }
                            }

                            if let dish = selectedDish {
                                let diff = recommendedPrice - dish.salePrice
                                HStack {
                                    Image(systemName: diff >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    Text(diff >= 0
                                         ? "Можно поднять цену на \(diff, specifier: "%.2f")"
                                         : "Цена выше нормы на \(abs(diff), specifier: "%.2f")")
                                }
                                .font(.subheadline)
                                .foregroundStyle(diff >= 0 ? Color.green : Color.orange)
                            }
                        }
                    }
                } else {
                    EmptyStateView(icon: "percent", title: "Выберите блюдо",
                                   subtitle: "или введите себестоимость вручную")
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Калькулятор цены")
    }
}

// MARK: - Profitability Ranking

struct ProfitabilityRankingView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var sortByMargin = true

    private struct DishProfit: Identifiable {
        let id: UUID
        let name: String
        let category: String
        let cost: Double
        let price: Double
        var margin: Double { price - cost }
        var foodCost: Double { price > 0 ? cost / price * 100 : 0 }
    }

    private var ranked: [DishProfit] {
        store.dishes
            .filter { $0.salePrice > 0 }
            .map { d in
                DishProfit(id: d.id, name: d.name, category: d.category,
                           cost: store.calculateDishCost(d), price: d.salePrice)
            }
            .sorted { sortByMargin ? $0.margin > $1.margin : $0.foodCost < $1.foodCost }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Сортировка", selection: $sortByMargin) {
                    Text("По марже ↓").tag(true)
                    Text("По Food Cost ↑").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if ranked.isEmpty {
                    EmptyStateView(icon: "chart.bar.fill", title: "Нет данных",
                                   subtitle: "Добавьте блюда с ценой продажи")
                        .padding()
                } else {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, dish in
                        BigCard {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(index < 3 ? Color.chefAccent.opacity(0.15) : Color.secondary.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    Text("\(index + 1)")
                                        .font(.headline.bold())
                                        .foregroundStyle(index < 3 ? Color.chefAccent : Color.secondary)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(dish.name).font(.headline)
                                    Text(dish.category).font(.caption).foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("+\(dish.margin, specifier: "%.2f")")
                                        .font(.headline.bold()).foregroundStyle(.green)
                                    Text("FC: \(dish.foodCost, specifier: "%.1f")%")
                                        .font(.caption)
                                        .foregroundStyle(dish.foodCost > store.foodCostThreshold ? .red : .secondary)
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
        .navigationTitle("Рейтинг прибыльности")
    }
}

// MARK: - Food Cost по периодам

struct FoodCostByPeriodView: View {
    @EnvironmentObject var store: ChefProStore

    enum Granularity: String, CaseIterable {
        case week = "По неделям"
        case month = "По месяцам"
    }

    @State private var granularity: Granularity = .week

    private struct PeriodPoint: Identifiable {
        let id = UUID()
        let label: String
        let date: Date
        let pct: Double
    }

    private var points: [PeriodPoint] {
        let cal = Calendar.current
        let component: Calendar.Component = granularity == .week ? .weekOfYear : .month

        // Group productions by period
        let grouped = Dictionary(grouping: store.productions) { prod -> Date in
            let comps = cal.dateComponents([.year, component], from: prod.date)
            return cal.date(from: comps) ?? prod.date
        }

        return grouped.compactMap { (date, prods) -> PeriodPoint? in
            // Total cost in period
            let totalCost = prods.reduce(0.0) { $0 + $1.totalCost }
            // Estimated revenue: use monthly plan proportionally
            let days = granularity == .week ? 7.0 : Double(cal.range(of: .day, in: .month, for: date)?.count ?? 30)
            let dailyRevenue = store.monthlyRevenuePlan / 30.0
            let periodRevenue = dailyRevenue * days
            guard periodRevenue > 0 else { return nil }
            let pct = totalCost / periodRevenue * 100

            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "ru_RU")
            fmt.dateFormat = granularity == .week ? "d MMM" : "MMM yy"
            return PeriodPoint(label: fmt.string(from: date), date: date, pct: pct)
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Период", selection: $granularity) {
                    ForEach(Granularity.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if points.isEmpty {
                    EmptyStateView(icon: "chart.bar", title: "Нет данных",
                                  subtitle: "Добавьте производства и плановую выручку в Настройках.")
                } else {
                    BigCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Food Cost %", systemImage: "percent").font(.headline)
                            Text("Рассчитан как себестоимость производства / плановая выручка за период.")
                                .font(.caption).foregroundStyle(.secondary)

                            Chart(points) { p in
                                BarMark(
                                    x: .value("Период", p.label),
                                    y: .value("FC%", p.pct)
                                )
                                .foregroundStyle(p.pct < 30 ? Color.green : p.pct < 40 ? Color.orange : Color.red)
                                .cornerRadius(4)
                                .annotation(position: .top) {
                                    Text("\(Int(p.pct))%")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                }

                                RuleMark(y: .value("Порог", store.foodCostThreshold))
                                    .lineStyle(StrokeStyle(dash: [5]))
                                    .foregroundStyle(.red.opacity(0.6))
                            }
                            .chartXAxis {
                                AxisMarks { v in
                                    AxisValueLabel(orientation: .vertical) {
                                        if let s = v.as(String.self) { Text(s).font(.caption2) }
                                    }
                                }
                            }
                            .frame(height: 220)

                            HStack(spacing: 16) {
                                legendDot(.green, "< 30%")
                                legendDot(.orange, "30–40%")
                                legendDot(.red, "> 40%")
                                Spacer()
                                HStack(spacing: 4) {
                                    Rectangle().fill(.red.opacity(0.6))
                                        .frame(width: 16, height: 2)
                                    Text("Порог \(Int(store.foodCostThreshold))%")
                                }
                                .font(.caption)
                            }
                            .font(.caption)
                        }
                    }

                    // Summary table
                    BigCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Сводка", systemImage: "tablecells").font(.headline)
                            Divider()
                            ForEach(points.suffix(6)) { p in
                                HStack {
                                    Text(p.label).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(p.pct, specifier: "%.1f")%")
                                        .bold()
                                        .foregroundStyle(p.pct < 30 ? .green : p.pct < 40 ? .orange : .red)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("FC по периодам")
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Топ-10 блюд по затратам

struct TopDishCostView: View {
    @EnvironmentObject var store: ChefProStore

    private struct DishCost: Identifiable {
        let id: UUID
        let name: String
        let category: String
        let totalCost: Double
        let portions: Int
        let costPerPortion: Double
        let foodCostPct: Double
    }

    private var topDishes: [DishCost] {
        let grouped = Dictionary(grouping: store.productions) { $0.dishName }
        return grouped.compactMap { (name, prods) -> DishCost? in
            guard let dish = store.dishes.first(where: { $0.name == name }) else { return nil }
            let total = prods.reduce(0.0) { $0 + $1.totalCost }
            let portions = prods.reduce(0) { $0 + $1.portions }
            let costPer = portions > 0 ? total / Double(portions) : 0
            return DishCost(id: dish.id, name: name, category: dish.category,
                            totalCost: total, portions: portions,
                            costPerPortion: costPer, foodCostPct: store.foodCostPercent(dish))
        }
        .sorted { $0.totalCost > $1.totalCost }
        .prefix(10)
        .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if topDishes.isEmpty {
                    EmptyStateView(icon: "flame", title: "Нет данных",
                                  subtitle: "Добавьте производства чтобы увидеть топ по затратам.")
                } else {
                    BigCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Топ-10 по сумме затрат", systemImage: "flame.fill").font(.headline)
                            Chart(topDishes) { d in
                                BarMark(
                                    x: .value("Сумма", d.totalCost),
                                    y: .value("Блюдо", d.name)
                                )
                                .foregroundStyle(Color.chefAccent)
                                .cornerRadius(4)
                                .annotation(position: .trailing) {
                                    Text("\(Int(d.totalCost)) ₽")
                                        .font(.caption.bold()).foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: max(200, CGFloat(topDishes.count) * 36))
                        }
                    }

                    ForEach(Array(topDishes.enumerated()), id: \.element.id) { index, d in
                        BigCard {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.title3.bold())
                                    .foregroundStyle(index < 3 ? Color.chefAccent : .secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(d.name).font(.headline)
                                    Text(d.category).font(.caption).foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(d.totalCost, specifier: "%.0f") ₽")
                                        .font(.headline.bold())
                                    Text("\(d.portions) порц. • FC \(d.foodCostPct, specifier: "%.0f")%")
                                        .font(.caption)
                                        .foregroundStyle(d.foodCostPct > store.foodCostThreshold ? .red : .secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Топ затрат")
    }
}

// MARK: - План vs Факт

struct PlanVsFactView: View {
    @EnvironmentObject var store: ChefProStore

    enum Period: String, CaseIterable { case week = "Неделя"; case month = "Месяц" }
    @State private var period: Period = .month

    private var since: Date {
        let cal = Calendar.current
        switch period {
        case .week:  return cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month: return Date().startOfMonth()
        }
    }

    private var factor: Double { period == .week ? 7.0 / 30.0 : 1.0 }

    // План
    private var planRevenue: Double { store.monthlyRevenuePlan * factor }
    private var planFoodCost: Double { planRevenue * store.monthlyFoodCostTarget / 100 }
    private var planPurchases: Double { store.purchaseBudget * factor }

    // Факт
    private var factRevenue: Double {
        store.sales.filter { $0.date >= since }.reduce(0.0) { total, sale in
            let price = store.dishes.first(where: { $0.name == sale.dishName })?.salePrice ?? 0
            return total + price * Double(sale.portions)
        }
    }
    private var factFoodCost: Double {
        store.productions.filter { $0.date >= since }.reduce(0.0) { $0 + $1.totalCost }
    }
    private var factPurchases: Double {
        store.deliveries.filter { $0.date >= since }.reduce(0.0) { $0 + $1.price }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Период", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if store.monthlyRevenuePlan == 0 {
                    BigCard {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar.xaxis").font(.largeTitle).foregroundStyle(.secondary)
                            Text("Установите плановую выручку и целевой Food Cost в Настройках")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                } else {
                    pvfRow(title: "Выручка", plan: planRevenue, fact: factRevenue,
                           higherIsBetter: true, icon: "arrow.up.circle.fill")
                    pvfRow(title: "Food Cost (себест.)", plan: planFoodCost, fact: factFoodCost,
                           higherIsBetter: false, icon: "flame.fill")
                    pvfRow(title: "Закупки", plan: planPurchases, fact: factPurchases,
                           higherIsBetter: false, icon: "cart.fill")

                    // Визуальное сравнение
                    BigCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Сравнение", systemImage: "chart.bar.fill").font(.headline)

                            pvfBar(label: "Выручка", plan: planRevenue, fact: factRevenue, color: .green)
                            pvfBar(label: "Food Cost", plan: planFoodCost, fact: factFoodCost, color: .orange)
                            pvfBar(label: "Закупки", plan: planPurchases, fact: factPurchases, color: .blue)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("План vs Факт")
    }

    private func pvfRow(title: String, plan: Double, fact: Double, higherIsBetter: Bool, icon: String) -> some View {
        let diff = fact - plan
        let good = higherIsBetter ? diff >= 0 : diff <= 0
        let pct = plan > 0 ? abs(diff) / plan * 100 : 0
        return BigCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon).font(.headline)
                HStack {
                    VStack(alignment: .leading) {
                        Text("ПЛАН").font(.caption).foregroundStyle(.secondary)
                        Text("\(plan, specifier: "%.0f") ₽").font(.title3.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("ФАКТ").font(.caption).foregroundStyle(.secondary)
                        Text("\(fact, specifier: "%.0f") ₽").font(.title3.bold())
                    }
                }
                HStack {
                    Spacer()
                    Label(
                        "\(diff >= 0 ? "+" : "")\(diff, specifier: "%.0f") ₽ (\(pct, specifier: "%.1f")%)",
                        systemImage: diff >= 0 ? "arrow.up" : "arrow.down"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(good ? .green : .red)
                }
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(good ? Color.green : Color.red)
                            .frame(width: plan > 0 ? min(geo.size.width * CGFloat(fact / plan), geo.size.width) : 0,
                                   height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func pvfBar(label: String, plan: Double, fact: Double, color: Color) -> some View {
        let maxVal = max(plan, fact, 1)
        return VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.2)).frame(height: 14)
                        RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(plan / maxVal), height: 14)
                    }
                }
                .frame(height: 14)
                Text("П").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.2)).frame(height: 14)
                        RoundedRectangle(cornerRadius: 3).fill(color)
                            .frame(width: geo.size.width * CGFloat(fact / maxVal), height: 14)
                    }
                }
                .frame(height: 14)
                Text("Ф").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Date helpers

private extension Date {
    func startOfMonth() -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
}

