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
                        KanbanColumn(title: "Новые",     accent: .blue,   orders: newOrders,     now: now, columnHeight: geo.size.height - 16)
                        KanbanColumn(title: "Готовятся", accent: .orange, orders: cookingOrders, now: now, columnHeight: geo.size.height - 16)
                        KanbanColumn(title: "Готово",    accent: .green,  orders: readyOrders,   now: now, columnHeight: geo.size.height - 16)
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

// MARK: - Grouped table model

struct TableGroup: Identifiable {
    let tableNumber: String
    var orders: [KitchenOrder]
    var id: String { tableNumber }

    var courseGroups: [(course: Int, name: String, orders: [KitchenOrder])] {
        let used = Set(orders.map(\.course)).sorted()
        return used.map { course in
            let name = KitchenOrder.courseNames[course] ?? "\(course) курс"
            let filtered = orders.filter { $0.course == course }
                                 .sorted { $0.createdAt < $1.createdAt }
            return (course, name, filtered)
        }
    }

    var allReady: Bool { orders.allSatisfy { $0.status == .ready } }
    var earliestDate: Date { orders.map(\.createdAt).min() ?? Date() }
}

// MARK: - Kanban Column

struct KanbanColumn: View {
    @EnvironmentObject var store: ChefProStore
    let title: String
    let accent: Color
    let orders: [KitchenOrder]
    let now: Date
    var columnHeight: CGFloat = 600

    private var soloOrders: [KitchenOrder] {
        orders.filter { $0.tableNumber.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var tableGroups: [TableGroup] {
        let withTable = orders.filter { !$0.tableNumber.trimmingCharacters(in: .whitespaces).isEmpty }
        let dict = Dictionary(grouping: withTable, by: \.tableNumber)
        return dict.map { TableGroup(tableNumber: $0.key, orders: $0.value) }
                   .sorted { $0.earliestDate < $1.earliestDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    if orders.isEmpty {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemGray6))
                            .frame(width: 272, height: 110)
                            .overlay(Text("Пусто").foregroundStyle(.secondary))
                    } else {
                        ForEach(tableGroups) { group in
                            TableOrderCard(group: group, now: now)
                                .environmentObject(store)
                        }
                        ForEach(soloOrders) { order in
                            KitchenOrderCard(order: order, now: now)
                                .environmentObject(store)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .frame(height: max(100, columnHeight - 52))
        }
        .frame(width: 300, alignment: .top)
    }
}

// MARK: - Table Order Card (grouped by courses)

struct TableOrderCard: View {
    @EnvironmentObject var store: ChefProStore
    let group: TableGroup
    let now: Date

    private var elapsed: TimeInterval { now.timeIntervalSince(group.earliestDate) }

    private var timerString: String {
        let m = Int(elapsed) / 60; let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var timerColor: Color {
        if elapsed < 600  { return .green }
        if elapsed < 1200 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Заголовок стола ──────────────────────────────────
            HStack {
                Label("Стол \(group.tableNumber)", systemImage: "tablecells")
                    .font(.headline.bold())
                Spacer()
                Text(timerString)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundStyle(timerColor)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(timerColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 12)

            // ── Курсы ────────────────────────────────────────────
            ForEach(group.courseGroups, id: \.course) { cg in
                VStack(alignment: .leading, spacing: 6) {
                    Text(cg.name)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    ForEach(cg.orders) { order in
                        TableDishRow(order: order, now: now)
                            .environmentObject(store)
                    }
                }
            }

            // ── Кнопка закрыть стол ─────────────────────────────
            if group.allReady {
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    store.archiveTableOrders(tableNumber: group.tableNumber)
                } label: {
                    Text("Закрыть стол")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding([.horizontal, .bottom], 14)
                .padding(.top, 10)
            } else {
                Spacer().frame(height: 14)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        .frame(width: 300)
    }
}

// MARK: - Single dish row inside TableOrderCard

struct TableDishRow: View {
    @EnvironmentObject var store: ChefProStore
    let order: KitchenOrder
    let now: Date

    private var statusColor: Color {
        switch order.status {
        case .new:     return .blue
        case .cooking: return .orange
        case .ready:   return .green
        }
    }

    private var statusIcon: String {
        switch order.status {
        case .new:     return "clock"
        case .cooking: return "flame.fill"
        case .ready:   return "checkmark.circle.fill"
        }
    }

    private var dishCookSeconds: TimeInterval? {
        let t = store.dishes.first(where: { $0.name == order.dishName })?.cookTime ?? 0
        return t > 0 ? TimeInterval(t * 60) : nil
    }

    private var timerBase: Date {
        switch order.status {
        case .new:     return order.createdAt
        case .cooking: return order.cookingStartedAt ?? order.createdAt
        case .ready:   return order.readyAt ?? order.createdAt
        }
    }

    private var elapsed: TimeInterval { now.timeIntervalSince(timerBase) }

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
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundStyle(statusColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(order.dishName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if !order.note.isEmpty {
                    Text(order.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("×\(order.portions)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Text(timerString)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(timerColor)

            if let next = order.status.next {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.advanceOrderStatus(order)
                } label: {
                    Image(systemName: next.icon)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(next.color)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(order.status == .ready ? Color.green.opacity(0.06) : Color.clear)
    }
}

struct KitchenOrderCard: View {
    @EnvironmentObject var store: ChefProStore
    let order: KitchenOrder
    let now: Date

    private var accent: Color { order.status.color }

    private var courseColor: Color {
        switch order.course {
        case 1: return .teal
        case 2: return .red
        case 3: return .purple
        case 4: return .indigo
        case 5: return .brown
        default: return .gray
        }
    }

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

    private var isOverdue: Bool {
        guard order.status == .cooking, let target = dishCookSeconds else { return false }
        return elapsed > target
    }

    private var timerString: String {
        if order.status == .cooking, let target = dishCookSeconds {
            let remaining = target - elapsed
            if remaining > 0 {
                let m = Int(remaining) / 60; let s = Int(remaining) % 60
                return String(format: "%d:%02d", m, s)
            } else {
                let over = -remaining
                let m = Int(over) / 60; let s = Int(over) % 60
                return String(format: "+%d:%02d", m, s)
            }
        }
        let m = Int(elapsed) / 60; let s = Int(elapsed) % 60
        return String(format: "%d:%02d", m, s)
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
        HStack(spacing: 0) {
            // ── Left accent bar ──────────────────────────────
            RoundedRectangle(cornerRadius: 3)
                .fill(isOverdue ? Color.red : accent)
                .frame(width: 4)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 10) {

                // ── Row 1: name + portions + table + timer ───
                HStack(spacing: 8) {
                    Text(order.dishName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("×\(order.portions)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(accent)
                        .clipShape(Capsule())
                    Spacer(minLength: 4)
                    if !order.tableNumber.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.grid.2x2.fill").font(.caption2)
                            Text("Стол \(order.tableNumber)").font(.subheadline.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    }
                    Text(timerString)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(timerColor)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(timerColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                // ── Row 2: course + note ─────────────────────
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.number").font(.caption2.bold())
                        Text(order.courseName).font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(courseColor)
                    .clipShape(Capsule())
                    if !order.note.isEmpty {
                        Text("·").foregroundStyle(.secondary).font(.caption)
                        Text(order.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if isOverdue {
                        Spacer()
                        Text("ПРОСРОЧЕНО")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                    }
                }

                // ── Row 3: action button ─────────────────────
                if let next = order.status.next {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.advanceOrderStatus(order)
                    } label: {
                        Label(order.status.actionLabel, systemImage: next.icon)
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(next.color)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                } else {
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        store.archiveKitchenOrder(order)
                    } label: {
                        Label("Закрыть заказ", systemImage: "archivebox")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            isOverdue
                ? Color.red.opacity(0.05)
                : Color(.secondarySystemGroupedBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isOverdue ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct AddKitchenOrderView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDishID: UUID? = nil
    @State private var dishName    = ""
    @State private var portions    = 1
    @State private var tableNumber = ""
    @State private var course      = 1
    @State private var note        = ""

    private var canSave: Bool {
        !dishName.trimmingCharacters(in: .whitespaces).isEmpty && portions >= 1
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Порций")
                            Spacer()
                            Text("\(portions)")
                                .font(.headline.bold())
                                .foregroundStyle(Color.chefAccent)
                        }
                        // Portions picker - horizontal scroll of chips 1..20
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(1...20, id: \.self) { n in
                                    Button {
                                        portions = n
                                    } label: {
                                        Text("\(n)")
                                            .font(.headline.bold())
                                            .frame(width: 44, height: 44)
                                            .background(portions == n ? Color.chefAccent : Color(.systemGray5))
                                            .foregroundStyle(portions == n ? .white : .primary)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
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
                    Picker("Курс", selection: $course) {
                        ForEach(KitchenOrder.courseNames.keys.sorted(), id: \.self) { key in
                            Text(KitchenOrder.courseNames[key] ?? "Курс \(key)").tag(key)
                        }
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
            portions:    portions,
            tableNumber: tableNumber.trimmingCharacters(in: .whitespaces),
            note:        note.trimmingCharacters(in: .whitespaces),
            course:      course
        )
        store.addKitchenOrder(order)
        dismiss()
    }
}

// MARK: - Стоп-лист / Гоу-лист

struct StopGoListView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var search = ""

    private var filtered: [Dish] {
        let q = search.lowercased()
        return store.dishes.filter { q.isEmpty || $0.name.lowercased().contains(q) }
    }

    var body: some View {
        List(filtered) { dish in
            StopGoRow(dish: dish)
                .environmentObject(store)
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Поиск блюда")
        .navigationTitle("Стоп / Гоу лист")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StopGoRow: View {
    @EnvironmentObject var store: ChefProStore
    let dish: Dish

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dish.name).font(.headline)
                Text(dish.category).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            // STOP toggle
            Button {
                var d = dish
                d.isStopListed.toggle()
                if d.isStopListed { d.isGoListed = false }
                store.updateDish(d)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: dish.isStopListed ? "xmark.circle.fill" : "xmark.circle")
                    Text("Стоп")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(dish.isStopListed ? Color.red : Color(.systemGray5))
                .foregroundStyle(dish.isStopListed ? .white : .secondary)
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            // GO toggle
            Button {
                var d = dish
                d.isGoListed.toggle()
                if d.isGoListed { d.isStopListed = false }
                store.updateDish(d)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: dish.isGoListed ? "checkmark.circle.fill" : "checkmark.circle")
                    Text("Гоу")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(dish.isGoListed ? Color.green : Color(.systemGray5))
                .foregroundStyle(dish.isGoListed ? .white : .secondary)
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Kitchen Mode

struct KitchenDishButton: View {
    let dish: Dish
    let foodCostPct: Double
    let action: () -> Void

    private var accentColor: Color {
        dish.isStopListed ? .red : dish.isGoListed ? .green : .chefAccent
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Цветная полоска сверху
                accentColor
                    .frame(height: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.bottom, 12)

                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    if dish.isStopListed {
                        Text("СТОП")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    } else if dish.isGoListed {
                        Text("ГОУ")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(.bottom, 10)

                Text(dish.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.bottom, 6)

                Text(dish.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if dish.salePrice > 0 {
                    HStack {
                        Text("FC \(foodCostPct, specifier: "%.0f")%")
                            .font(.caption.bold())
                            .foregroundStyle(accentColor)
                        Spacer()
                        if dish.cookTime > 0 {
                            Label("\(dish.cookTime) мин", systemImage: "timer")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct KitchenModeView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedDish: Dish?
    @State private var searchText = ""

    let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    private var visibleDishes: [Dish] {
        let base = store.dishes.filter { !$0.isStopListed }
        if searchText.isEmpty { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Статус-бар
                HStack(spacing: 12) {
                    KitchenStatChip(
                        value: store.dishes.filter { $0.isGoListed }.count,
                        label: "ГОУ",
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                    KitchenStatChip(
                        value: store.dishes.filter { $0.isStopListed }.count,
                        label: "СТОП",
                        color: .red,
                        icon: "xmark.circle.fill"
                    )
                    KitchenStatChip(
                        value: store.kitchenOrders.filter { $0.status != .ready }.count,
                        label: "Заказов",
                        color: .orange,
                        icon: "tray.fill"
                    )
                    Spacer()
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleDishes) { dish in
                        KitchenDishButton(
                            dish: dish,
                            foodCostPct: store.foodCostPercent(dish),
                            action: { selectedDish = dish }
                        )
                    }
                }

                if visibleDishes.isEmpty {
                    EmptyStateView(icon: "fork.knife", title: "Нет блюд", subtitle: "Все блюда в стоп-листе или склад пуст")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Поиск блюда")
        .navigationTitle("Kitchen Mode")
        .navigationBarTitleDisplayMode(.large)
        .onAppear    { UIApplication.shared.isIdleTimerDisabled = true  }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(item: $selectedDish) { dish in
            ProduceDishView(dish: dish)
                .environmentObject(store)
        }
    }
}

private struct KitchenStatChip: View {
    let value: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text("\(value) \(label)")
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Purchases

struct PurchaseItemCard: View {
    let item: InventoryItem

    var body: some View {
        let recommended = max(item.minQuantity * 2 - item.quantity, item.minQuantity)
        let orderLabel: String = {
            if !item.orderUnit.isEmpty && item.orderUnitRatio > 0 {
                let units = (recommended / item.orderUnitRatio).rounded(.up)
                return "\(String(format: "%.0f", units)) \(item.orderUnit)"
            }
            return "\(String(format: "%.1f", recommended)) \(item.unit)"
        }()

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "cart.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.bold()).lineLimit(1)
                Text(item.category)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 4) {
                    Text("Остаток: \(item.quantity, specifier: "%.1f") \(item.unit)")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("·").font(.caption2).foregroundStyle(.secondary)
                    Text("Мин: \(item.minQuantity, specifier: "%.1f") \(item.unit)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(orderLabel)
                    .font(.subheadline.bold()).foregroundStyle(.chefAccent)
                Text("заказать").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            VStack(alignment: .leading, spacing: 0) {

                // ── Summary chips ─────────────────────────────────
                HStack(spacing: 10) {
                    purchaseChip(icon: "cart.fill", label: "К заказу", value: "\(totalCount)", color: .orange)
                    purchaseChip(icon: "exclamationmark.triangle.fill", label: "Авто", value: "\(store.purchaseList.count)", color: .red)
                    purchaseChip(icon: "pencil.circle.fill", label: "Вручную", value: "\(store.extraPurchaseItems.count)", color: .blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // ── Авто-список (нехватка) ────────────────────────
                if !store.purchaseList.isEmpty {
                    purchaseSectionHeader("Нехватка на складе", icon: "exclamationmark.triangle.fill", color: .orange, count: store.purchaseList.count)
                    VStack(spacing: 0) {
                        ForEach(store.purchaseList) { item in
                            PurchaseItemCard(item: item)
                            if item.id != store.purchaseList.last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                // ── Добавленные вручную ───────────────────────────
                if !store.extraPurchaseItems.isEmpty {
                    purchaseSectionHeader("Добавлено вручную", icon: "pencil.circle.fill", color: .blue, count: store.extraPurchaseItems.count)
                    VStack(spacing: 0) {
                        ForEach(store.extraPurchaseItems) { item in
                            extraItemCard(item)
                            if item.id != store.extraPurchaseItems.last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                // ── Empty state ───────────────────────────────────
                if totalCount == 0 {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "Закупки не нужны",
                        subtitle: "Все продукты выше минимального остатка.\nДобавьте позиции вручную если нужно."
                    )
                    .padding(.top, 40)
                }

                // ── Action buttons ────────────────────────────────
                if totalCount > 0 {
                    VStack(spacing: 10) {
                        Button {
                            orderText = buildOrderText()
                            showShare = true
                        } label: {
                            Label("Сформировать заявку", systemImage: "square.and.arrow.up")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())

                        if !store.extraPurchaseItems.isEmpty {
                            Button(role: .destructive) {
                                store.clearExtraPurchaseItems()
                            } label: {
                                Label("Очистить ручные позиции", systemImage: "trash")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 4)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Закупки")
        .navigationBarTitleDisplayMode(.inline)
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

    private func purchaseChip(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.bold()).foregroundStyle(.primary)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity)
    }

    private func purchaseSectionHeader(_ title: String, icon: String, color: Color, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
            Spacer()
            Text("\(count)").font(.caption2.bold())
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func extraItemCard(_ item: ExtraPurchaseItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline.bold()).lineLimit(1)
                if !item.note.isEmpty {
                    Text(item.note).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("вручную").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(item.quantity, specifier: "%.1f") \(item.unit)")
                .font(.subheadline.bold())
                .foregroundStyle(.blue)
            Button {
                store.removeExtraPurchaseItem(item)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
                    .font(.subheadline)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
