import SwiftUI

struct ExpenseListView: View {
    @EnvironmentObject var vm: ExpenseViewModel
    @State private var showAdd = false
    @State private var editingExpense: CarExpense? = nil
    @State private var filterCategory: ExpenseCategory? = nil
    @State private var collapsedMonths: Set<String> = []
    @State private var searchText = ""

    var grouped: [(month: String, date: Date, expenses: [CarExpense])] {
        var source = vm.currentCarExpenses
        if let f = filterCategory { source = source.filter { $0.category == f } }
        if !searchText.isEmpty {
            source = source.filter {
                $0.note.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
                String($0.mileage).contains(searchText)
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")

        let dict = Dictionary(grouping: source) { expense -> String in
            formatter.string(from: expense.date)
        }

        return dict.keys
            .compactMap { key -> (String, Date, [CarExpense])? in
                guard let items = dict[key] else { return nil }
                let sorted = items.sorted { $0.date > $1.date }
                return (key, sorted.first!.date, sorted)
            }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        statsHeader
                        filterBar
                        if grouped.isEmpty {
                            emptyState
                        } else {
                            monthSections
                        }
                    }
                    .padding(.bottom, 100)
                }

                addButton
            }
            .navigationTitle(vm.selectedCar?.displayName ?? "Расходы")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Поиск по заметкам, категории, пробегу")
            .sheet(isPresented: $showAdd) {
                AddExpenseView().environmentObject(vm)
            }
            .sheet(item: $editingExpense) { expense in
                AddExpenseView(editingExpense: expense).environmentObject(vm)
            }
        }
    }

    // MARK: - Шапка со статистикой

    private var statsHeader: some View {
        HStack(spacing: 12) {
            // Пробег
            statCard(
                icon: "speedometer",
                color: .blue,
                title: "Пробег",
                value: vm.lastMileage > 0 ? "\(vm.lastMileage.formatted())" : "—",
                unit: vm.lastMileage > 0 ? "км" : ""
            )

            // Средний расход
            if let avg = vm.averageFuelConsumption {
                statCard(
                    icon: "fuelpump.fill",
                    color: .orange,
                    title: "Расход",
                    value: String(format: "%.1f", avg),
                    unit: "л/100км"
                )
            } else {
                statCard(
                    icon: "fuelpump.fill",
                    color: .orange,
                    title: "Расход",
                    value: "—",
                    unit: "нужно 2+ заправки"
                )
            }

            // Итого за всё время
            statCard(
                icon: "rublesign.circle.fill",
                color: .green,
                title: "Всего",
                value: vm.totalExpenses > 0 ? formatAmount(vm.totalExpenses) : "—",
                unit: vm.totalExpenses > 0 ? "₽" : ""
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func statCard(icon: String, color: Color, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Фильтр

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(label: "Все", isSelected: filterCategory == nil) {
                    filterCategory = nil
                }
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    FilterChip(label: cat.rawValue, icon: cat.icon,
                               isSelected: filterCategory == cat) {
                        filterCategory = filterCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Секции по месяцам

    private var monthSections: some View {
        LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
            ForEach(grouped, id: \.month) { group in
                let isCollapsed = collapsedMonths.contains(group.month)
                let monthTotal = group.expenses.reduce(0) { $0 + $1.amount }

                Section {
                    if !isCollapsed {
                        VStack(spacing: 8) {
                            ForEach(group.expenses) { expense in
                                ExpenseRowView(expense: expense)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingExpense = expense }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                vm.expenses.removeAll { $0.id == expense.id }
                                            }
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                        Button { editingExpense = expense } label: {
                                            Label("Изменить", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } header: {
                    monthHeader(
                        title: group.month.capitalized,
                        total: monthTotal,
                        count: group.expenses.count,
                        isCollapsed: isCollapsed
                    ) {
                        withAnimation(.spring(response: 0.35)) {
                            if isCollapsed {
                                collapsedMonths.remove(group.month)
                            } else {
                                collapsedMonths.insert(group.month)
                            }
                        }
                    }
                }
            }
        }
    }

    private func monthHeader(title: String, total: Double, count: Int,
                             isCollapsed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(count) \(pluralRecords(count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(formatAmount(total)) ₽")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollapsed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Нет записей")
                .font(.title2.bold())
            Text("Нажмите «+» чтобы добавить\nпервую запись")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - FAB

    private var addButton: some View {
        Button { showAdd = true } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .accentColor.opacity(0.4), radius: 12, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        .disabled(vm.selectedCar == nil)
    }

    // MARK: - Helpers

    private func formatAmount(_ value: Double) -> String {
        let n = Int(value)
        return n.formatted()
    }

    private func pluralRecords(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "запись" }
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) { return "записи" }
        return "записей"
    }
}

// MARK: - Row

struct ExpenseRowView: View {
    let expense: CarExpense

    var categoryColor: Color {
        switch expense.category {
        case .fuel: return .orange
        case .service: return .blue
        case .other: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: expense.category.icon)
                    .foregroundColor(categoryColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.category.rawValue)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "speedometer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(expense.mileage.formatted()) км")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let liters = expense.liters {
                    HStack(spacing: 4) {
                        Image(systemName: expense.tankFillType == .full ? "fuelpump.fill" : "fuelpump")
                            .font(.caption2)
                            .foregroundColor(expense.tankFillType == .full ? .orange : .secondary)
                        Text(String(format: "%.1f л залито", liters))
                            .font(.caption)
                            .foregroundColor(.orange)
                        if let rem = expense.remainingLiters, rem > 0 {
                            Text("·")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(String(format: "+ %.1f л остаток", rem))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(Int(expense.amount).formatted()) ₽")
                .font(.headline.bold())
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.bold())
                }
                Text(label)
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? .accentColor.opacity(0.3) : .clear, radius: 4)
        }
    }
}
