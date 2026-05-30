import SwiftUI

// MARK: - Waiter Mode

private struct TableSelection: Identifiable {
    let id: Int   // table number
}

struct WaiterModeView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var tableSelection: TableSelection? = nil
    @State private var tableCount = 12

    // Active orders per table (table number → count of non-ready orders)
    private func activeOrderCount(for table: Int) -> Int {
        store.kitchenOrders.filter {
            $0.tableNumber == "\(table)" && $0.status != .ready
        }.count
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 90), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Active orders summary
                    if store.kitchenOrders.contains(where: { $0.status != .ready && !$0.tableNumber.isEmpty }) {
                        BigCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Активные заказы", systemImage: "flame.fill")
                                    .font(.headline).foregroundStyle(.orange)
                                ForEach(store.kitchenOrders.filter { $0.status != .ready && !$0.tableNumber.isEmpty }) { order in
                                    HStack {
                                        Text("Стол \(order.tableNumber)")
                                            .font(.subheadline.bold())
                                        Text("·")
                                        Text(order.dishName)
                                            .font(.subheadline)
                                        Text("×\(order.portions)")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(order.status.rawValue)
                                            .font(.caption.bold())
                                            .foregroundStyle(order.status.color)
                                    }
                                }
                            }
                        }
                    }

                    Text("Выберите стол")
                        .font(.title3.bold())
                        .padding(.horizontal, 4)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...tableCount, id: \.self) { table in
                            let count = activeOrderCount(for: table)
                            Button {
                                tableSelection = TableSelection(id: table)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "tablecells.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(count > 0 ? .orange : .chefAccent)
                                        Text("Стол \(table)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(count > 0 ? Color.orange.opacity(0.12) : Color(.secondarySystemBackground))
                                    )

                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(5)
                                            .background(Color.orange)
                                            .clipShape(Circle())
                                            .offset(x: -4, y: 4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color.chefBackground)
            .navigationTitle("Режим официанта")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach([8, 12, 16, 20, 24], id: \.self) { n in
                            Button("\(n) столов") { tableCount = n }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(item: $tableSelection) { selection in
                WaiterOrderSheet(tableNumber: selection.id)
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - Order Sheet

struct WaiterOrderSheet: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    let tableNumber: Int
    @State private var selectedDish: Dish? = nil
    @State private var portions = 1
    @State private var course   = 1
    @State private var note     = ""
    @State private var searchText = ""
    @State private var sentOrders: [KitchenOrder] = []

    private var filteredDishes: [Dish] {
        store.dishes.filter { $0.dishType == .dish && $0.menuStatus != .removed }.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Orders sent this session
                if !sentOrders.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Отправлено на кухню")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sentOrders) { order in
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                        Text(order.dishName)
                                        Text("×\(order.portions)").foregroundStyle(.secondary)
                                        Text("·").foregroundStyle(.secondary)
                                        Text(order.courseName).foregroundStyle(.orange)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider()
                }

                // Dish search + picker
                List {
                    Section {
                        TextField("Поиск блюда…", text: $searchText)
                    }

                    Section("Меню") {
                        ForEach(filteredDishes) { dish in
                            Button {
                                selectedDish = dish
                                portions = 1
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(dish.name).font(.headline).foregroundStyle(.primary)
                                        Text(dish.category).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedDish?.id == dish.id {
                                        Image(systemName: "checkmark").foregroundStyle(.chefAccent)
                                    }
                                }
                            }
                        }
                    }

                    if let dish = selectedDish {
                        Section("Заказ — \(dish.name)") {
                            Stepper("Порций: \(portions)", value: $portions, in: 1...20)
                            Picker("Курс подачи", selection: $course) {
                                ForEach(Array(KitchenOrder.courseNames.sorted(by: { $0.key < $1.key })), id: \.key) { key, name in
                                    Text(name).tag(key)
                                }
                            }
                            TextField("Комментарий (аллергии, пожелания…)", text: $note, axis: .vertical)
                                .lineLimit(2...3)
                        }

                        Section {
                            Button {
                                sendOrder(dish: dish)
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Отправить на кухню", systemImage: "paperplane.fill")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.chefAccent)
                        }
                    }
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

    private func sendOrder(dish: Dish) {
        let order = KitchenOrder(
            dishName: dish.name,
            portions: portions,
            tableNumber: "\(tableNumber)",
            note: note,
            course: course,
            status: .new,
            createdAt: Date()
        )
        store.addKitchenOrder(order)
        sentOrders.append(order)
        selectedDish = nil
        portions = 1
        note = ""
        // keep course as-is — usually next dish is same course
    }
}
