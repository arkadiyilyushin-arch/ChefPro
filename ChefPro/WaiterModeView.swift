import SwiftUI

// MARK: - Waiter Mode

struct WaiterModeView: View {
    @EnvironmentObject var store: ChefProStore

    // Shared floor plan storage (same key as FloorPlanView)
    @AppStorage("chefpro_floor_tables") private var tablesData: Data = Data()
    @AppStorage("chefpro_waiter_use_floorplan") private var useFloorPlan: Bool = true
    @AppStorage("chefpro_waiter_manual_count")  private var manualCount: Int  = 12

    @State private var floorTables: [FloorTable] = []
    @State private var selectedTable: WaiterTableItem? = nil
    @State private var showCountPicker = false

    // Unified table items used by the grid
    private var tableItems: [WaiterTableItem] {
        if useFloorPlan && !floorTables.isEmpty {
            return floorTables.map { ft in
                WaiterTableItem(
                    id: ft.id.uuidString,
                    display: ft.number,
                    seats: ft.seats
                )
            }
        } else {
            return (1...max(1, manualCount)).map {
                WaiterTableItem(id: "\($0)", display: "\($0)", seats: 0)
            }
        }
    }

    // Summary counts
    private var activeTables: Int {
        Set(store.kitchenOrders.filter { $0.status != .ready && !$0.tableNumber.isEmpty }.map { $0.tableNumber }).count
    }
    private var readyTables: Int {
        Set(store.kitchenOrders.filter { $0.status == .ready && !$0.tableNumber.isEmpty }.map { $0.tableNumber }).count
    }
    private var totalActive: Int {
        store.kitchenOrders.filter { $0.status != .ready }.count
    }

    private func ordersFor(_ table: String) -> [KitchenOrder] {
        store.kitchenOrders.filter { $0.tableNumber == table }
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ── Header chips ─────────────────────────────
                    HStack(spacing: 10) {
                        waiterChip(icon: "flame.fill",          label: "Активные", value: "\(totalActive)",   color: .orange)
                        waiterChip(icon: "clock.badge.checkmark", label: "Столов",  value: "\(activeTables)",  color: .red)
                        waiterChip(icon: "checkmark.circle.fill", label: "Готово",  value: "\(readyTables)",   color: .green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // ── Source toggle ────────────────────────────
                    HStack(spacing: 8) {
                        sourceButton(title: "Из плана зала", icon: "rectangle.split.3x3.fill", active: useFloorPlan) {
                            useFloorPlan = true
                        }
                        sourceButton(title: "Вручную", icon: "slider.horizontal.3", active: !useFloorPlan) {
                            useFloorPlan = false
                        }
                        if !useFloorPlan {
                            Button {
                                showCountPicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("\(manualCount)")
                                        .font(.subheadline.bold())
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.chefAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    // ── No floor plan warning ───────────────────
                    if useFloorPlan && floorTables.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "rectangle.split.3x3")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("План зала не настроен")
                                .font(.headline)
                            Text("Перейдите в «Ещё → План зала» чтобы расставить столы, или переключитесь на ручной режим.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                    }

                    // ── Table grid ───────────────────────────────
                    if !tableItems.isEmpty {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(tableItems) { item in
                                tableCard(item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
                .padding(.top, 4)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Режим официанта")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedTable) { item in
                WaiterOrderSheet(tableNumber: item.display, seats: item.seats)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showCountPicker) {
                CountPickerSheet(count: $manualCount)
            }
            .onAppear { loadFloorTables() }
            .onChange(of: tablesData) { loadFloorTables() }
        }
    }

    // MARK: - Table card

    private func tableCard(_ item: WaiterTableItem) -> some View {
        let orders = ordersFor(item.display)
        let newCount  = orders.filter { $0.status == .new || $0.status == .cooking }.count
        let readyCount = orders.filter { $0.status == .ready }.count
        let hasOrders = !orders.isEmpty

        let accentColor: Color = readyCount > 0 ? .green :
                                 newCount   > 0 ? .orange : .primary.opacity(0.5)
        let bgColor: Color = readyCount > 0 ? .green.opacity(0.12) :
                             newCount   > 0 ? .orange.opacity(0.12) :
                             Color(.secondarySystemGroupedBackground)

        return Button {
            selectedTable = item
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(hasOrders ? 0.18 : 0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: hasOrders ? "fork.knife.circle.fill" : "fork.knife.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(hasOrders ? accentColor : .secondary)
                    }
                    Text("Стол \(item.display)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if item.seats > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill").font(.caption2)
                            Text("\(item.seats)").font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    if hasOrders {
                        HStack(spacing: 4) {
                            if newCount > 0 {
                                ordersBadge("\(newCount) готовится", color: .orange)
                            }
                            if readyCount > 0 {
                                ordersBadge("\(readyCount) готово", color: .green)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if hasOrders {
                    Text("\(orders.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(accentColor)
                        .clipShape(Circle())
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func waiterChip(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.bold())
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity)
    }

    private func sourceButton(title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption.bold())
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(active ? Color.chefAccent : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(active ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func ordersBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func loadFloorTables() {
        if let decoded = try? JSONDecoder().decode([FloorTable].self, from: tablesData) {
            floorTables = decoded
        } else {
            floorTables = []
        }
    }
}

// MARK: - Helper model

private struct WaiterTableItem: Identifiable {
    let id:      String
    let display: String   // shown as "Стол X"
    let seats:   Int
}

// MARK: - Count Picker Sheet

private struct CountPickerSheet: View {
    @Binding var count: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(count)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.chefAccent)

                Text("столов")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 20) {
                    Button {
                        if count > 1 { count -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(count > 1 ? .chefAccent : .secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Slider(value: Binding(
                        get: { Double(count) },
                        set: { count = Int($0) }
                    ), in: 1...50, step: 1)
                    .tint(.chefAccent)

                    Button {
                        if count < 50 { count += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(count < 50 ? .chefAccent : .secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, 24)

                // Quick presets
                HStack(spacing: 10) {
                    ForEach([6, 8, 12, 16, 20, 24], id: \.self) { n in
                        Button {
                            count = n
                        } label: {
                            Text("\(n)")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(count == n ? Color.chefAccent : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(count == n ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding()
            .navigationTitle("Количество столов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Элемент корзины

private struct CartItem: Identifiable {
    let id   = UUID()
    var dish:     Dish
    var portions: Int
    var course:   Int
    var note:     String
}

// MARK: - Order Sheet

struct WaiterOrderSheet: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    let tableNumber: String
    let seats:       Int

    @State private var cart:         [CartItem] = []
    @State private var selectedDish: Dish?  = nil
    @State private var portions             = 1
    @State private var course               = 1
    @State private var note                 = ""
    @State private var searchText           = ""
    @State private var showCart             = true
    @FocusState private var searchFocused: Bool

    private var existingOrders: [KitchenOrder] {
        store.kitchenOrders.filter { $0.tableNumber == tableNumber }
    }

    private var filteredDishes: [Dish] {
        store.dishes
            .filter { $0.dishType == .dish && $0.menuStatus != .removed }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var cartTotal: Double {
        cart.reduce(0) { sum, item in
            sum + (item.dish.salePrice * Double(item.portions))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {

                    // ── Шапка стола ───────────────────────────
                    tableHeader

                    // ── На кухне (уже отправленные) ───────────
                    if !existingOrders.isEmpty {
                        kitchenOrdersStrip
                    }

                    // ── Корзина ───────────────────────────────
                    if !cart.isEmpty {
                        cartSection
                    }

                    // ── Поиск ─────────────────────────────────
                    searchBar

                    // ── Список блюд ───────────────────────────
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredDishes) { dish in
                                dishRow(dish)
                                if dish.id != filteredDishes.last?.id {
                                    Divider().padding(.leading, 64)
                                }
                            }
                            if let dish = selectedDish {
                                addToCartPanel(dish)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                        .padding(.bottom, cart.isEmpty ? 20 : 88)
                    }
                }
                .background(Color(.systemGroupedBackground))

                // ── Плавающая кнопка отправки ─────────────────
                if !cart.isEmpty {
                    sendCartButton
                }
            }
            .navigationTitle("Стол \(tableNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    // MARK: - Шапка стола

    private var tableHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.chefAccent.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 22)).foregroundStyle(.chefAccent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Стол \(tableNumber)").font(.headline.bold())
                if seats > 0 {
                    Text("\(seats) мест").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !existingOrders.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(existingOrders.count) позиций")
                        .font(.caption.bold()).foregroundStyle(.orange)
                    Text("на кухне").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // ── Полоса уже отправленных заказов с кнопкой отмены ──────

    private var kitchenOrdersStrip: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(existingOrders) { order in
                        HStack(spacing: 5) {
                            Circle().fill(order.status.color).frame(width: 7, height: 7)
                            Text(order.dishName).lineLimit(1)
                            Text("×\(order.portions)").foregroundStyle(.secondary)
                            Text("·").foregroundStyle(.secondary)
                            Text(order.status.rawValue).foregroundStyle(order.status.color)
                            // Отмена только для новых (ещё не взяли в готовку)
                            if order.status == .new {
                                Button {
                                    withAnimation {
                                        store.deleteKitchenOrder(order)
                                        Task { try? await ChefProFirebaseService.shared.deleteKitchenOrder(id: order.id) }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red.opacity(0.7))
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(order.status.color.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            Divider()
        }
    }

    // ── Корзина ────────────────────────────────────────────────

    private var cartSection: some View {
        VStack(spacing: 0) {
            // Заголовок корзины
            Button {
                withAnimation(.spring(response: 0.3)) { showCart.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.caption.bold()).foregroundStyle(.chefAccent)
                    Text("Корзина")
                        .font(.subheadline.bold())
                    Text("\(cart.count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.chefAccent.opacity(0.15))
                        .foregroundStyle(.chefAccent)
                        .clipShape(Capsule())
                    Spacer()
                    if cartTotal > 0 {
                        Text("\(Int(cartTotal)) ₽")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    Image(systemName: showCart ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showCart {
                VStack(spacing: 0) {
                    ForEach(cart) { item in
                        cartRow(item)
                        if item.id != cart.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func cartRow(_ item: CartItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.chefAccent.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: "fork.knife")
                    .font(.system(size: 13)).foregroundStyle(.chefAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.dish.name).font(.subheadline.bold()).lineLimit(1)
                HStack(spacing: 6) {
                    Text(KitchenOrder.courseNames[item.course] ?? "").font(.caption2).foregroundStyle(.secondary)
                    if !item.note.isEmpty {
                        Text("· \(item.note)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            Spacer()
            Text("×\(item.portions)")
                .font(.subheadline.bold()).foregroundStyle(.chefAccent)
            if item.dish.salePrice > 0 {
                Text("\(Int(item.dish.salePrice * Double(item.portions))) ₽")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                withAnimation { cart.removeAll { $0.id == item.id } }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
                    .font(.subheadline).padding(8)
            }
            .buttonStyle(.plain).contentShape(Rectangle())
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    // ── Поиск ─────────────────────────────────────────────────

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.subheadline)
            TextField("Поиск блюда…", text: $searchText).focused($searchFocused)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // ── Строка блюда ──────────────────────────────────────────

    private func dishRow(_ dish: Dish) -> some View {
        let isSelected = selectedDish?.id == dish.id
        let inCart = cart.filter { $0.dish.id == dish.id }.reduce(0) { $0 + $1.portions }

        return Button {
            guard !dish.isStopListed else { return }
            withAnimation { selectedDish = isSelected ? nil : dish }
            portions = 1; note = ""
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(dish.isStopListed
                              ? Color.red.opacity(0.1)
                              : isSelected ? Color.chefAccent.opacity(0.15) : Color(.tertiarySystemFill))
                        .frame(width: 36, height: 36)
                    Image(systemName: dish.isStopListed ? "xmark" : "fork.knife")
                        .font(.system(size: 14))
                        .foregroundStyle(dish.isStopListed ? .red : isSelected ? .chefAccent : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(dish.isStopListed ? .secondary : .primary)
                        .lineLimit(1)
                    Text(dish.category).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if dish.isStopListed {
                    Text("СТОП").font(.caption2.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.red).clipShape(Capsule())
                } else {
                    HStack(spacing: 6) {
                        if inCart > 0 {
                            Text("×\(inCart) в корзине")
                                .font(.caption2.bold()).foregroundStyle(.chefAccent)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color.chefAccent.opacity(0.1))
                                .clipShape(Capsule())
                        } else if dish.salePrice > 0 {
                            Text("\(Int(dish.salePrice)) ₽")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                        }
                        if isSelected {
                            Image(systemName: "chevron.up").font(.caption2).foregroundStyle(.chefAccent)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .opacity(dish.isStopListed ? 0.55 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(dish.isStopListed)
    }

    // ── Панель добавления в корзину ────────────────────────────

    private func addToCartPanel(_ dish: Dish) -> some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 14) {
                HStack {
                    Text(dish.name).font(.subheadline.bold()).lineLimit(1)
                    Spacer()
                    Button { withAnimation { selectedDish = nil } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Порции
                HStack {
                    Text("Порций").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 0) {
                        Button { if portions > 1 { portions -= 1 } } label: {
                            Image(systemName: "minus.circle.fill").font(.title3)
                                .foregroundStyle(portions > 1 ? .chefAccent : .secondary)
                        }
                        .buttonStyle(.plain)
                        Text("\(portions)").font(.headline.bold()).frame(width: 36)
                        Button { if portions < 20 { portions += 1 } } label: {
                            Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.chefAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Курс
                HStack {
                    Text("Курс подачи").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $course) {
                        ForEach(Array(KitchenOrder.courseNames.sorted(by: { $0.key < $1.key })), id: \.key) { key, name in
                            Text(name).tag(key)
                        }
                    }
                    .labelsHidden()
                }

                // Примечание
                TextField("Комментарий (аллергии, пожелания…)", text: $note, axis: .vertical)
                    .font(.subheadline).lineLimit(2...3)
                    .padding(10)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Добавить в корзину
                Button {
                    withAnimation {
                        cart.append(CartItem(dish: dish, portions: portions, course: course, note: note))
                        selectedDish = nil
                        portions = 1; course = 1; note = ""
                        showCart = true
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Добавить в корзину", systemImage: "cart.badge.plus")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.chefAccent.opacity(0.12))
                        .foregroundStyle(.chefAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.chefAccent.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain).contentShape(Rectangle())
            }
            .padding(16)
            .background(Color(.tertiarySystemGroupedBackground))
        }
    }

    // ── Кнопка отправки всей корзины ──────────────────────────

    private var sendCartButton: some View {
        Button {
            sendCart()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "paperplane.fill")
                Text("Отправить на кухню")
                Spacer()
                Text("\(cart.count) блюд")
                    .font(.subheadline)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                if cartTotal > 0 {
                    Text("\(Int(cartTotal)) ₽").font(.subheadline)
                }
            }
            .font(.headline)
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(Color.chefAccent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.chefAccent.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain).contentShape(Rectangle())
        .padding(.horizontal, 16).padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Логика отправки

    private func sendCart() {
        for item in cart {
            let order = KitchenOrder(
                dishName:    item.dish.name,
                portions:    item.portions,
                tableNumber: tableNumber,
                note:        item.note,
                course:      item.course,
                status:      .new,
                createdAt:   Date()
            )
            store.addKitchenOrder(order)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        cart.removeAll()
        selectedDish = nil
    }
}
