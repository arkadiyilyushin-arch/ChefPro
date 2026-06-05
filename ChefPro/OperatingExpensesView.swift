import SwiftUI

// MARK: - Operating Expenses View

struct OperatingExpensesView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd  = false
    @State private var editing: OperatingExpense? = nil
    @State private var selectedCategory: ExpenseCategory? = nil
    @State private var selectedPeriod: ExpensePeriod = .month

    enum ExpensePeriod: String, CaseIterable {
        case month = "Месяц"
        case year  = "Год"
        case all   = "Всё"
    }

    private var since: Date {
        let cal = Calendar.current
        switch selectedPeriod {
        case .month: return cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .year:  return cal.date(byAdding: .year,  value: -1, to: Date()) ?? Date()
        case .all:   return .distantPast
        }
    }

    private var filtered: [OperatingExpense] {
        store.operatingExpenses
            .filter { $0.date >= since }
            .filter { selectedCategory == nil || $0.category == selectedCategory }
            .sorted { $0.date > $1.date }
    }

    private var totalFiltered: Double { filtered.reduce(0) { $0 + $1.amount } }

    private var byCategory: [(ExpenseCategory, Double)] {
        ExpenseCategory.allCases.compactMap { cat in
            let sum = filtered.filter { $0.category == cat }.reduce(0) { $0 + $1.amount }
            return sum > 0 ? (cat, sum) : nil
        }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Period picker
                Picker("Период", selection: $selectedPeriod) {
                    ForEach(ExpensePeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 10)

                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(nil, label: "Все")
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            categoryChip(cat, label: cat.rawValue)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 10)

                if filtered.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "creditcard.fill",
                        title: "Нет расходов",
                        subtitle: "Добавьте операционные расходы",
                        actionTitle: "Добавить",
                        action: { showAdd = true }
                    )
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            // Summary card
                            summaryCard

                            // By category breakdown
                            if byCategory.count > 1 {
                                categoryBreakdown
                            }

                            // Expense list
                            expenseList
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Операционные расходы")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                ExpenseFormView(expense: nil) { store.operatingExpenses.append($0) }
            }
            .sheet(item: $editing) { expense in
                ExpenseFormView(expense: expense) { updated in
                    if let i = store.operatingExpenses.firstIndex(where: { $0.id == updated.id }) {
                        store.operatingExpenses[i] = updated
                    }
                }
            }
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(String(format: "%.2f", totalFiltered))
                    .font(.title2.bold()).foregroundStyle(.primary)
                Text("Итого").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("\(filtered.count)")
                    .font(.title2.bold()).foregroundStyle(.primary)
                Text("Записей").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                let avg = filtered.isEmpty ? 0 : totalFiltered / Double(filtered.count)
                Text(String(format: "%.2f", avg))
                    .font(.title2.bold()).foregroundStyle(.primary)
                Text("Среднее").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("По категориям").font(.subheadline.bold()).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(byCategory.enumerated()), id: \.element.0) { idx, pair in
                    let (cat, sum) = pair
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(cat.color.opacity(0.15)).frame(width: 32, height: 32)
                            Image(systemName: cat.icon)
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(cat.color)
                        }
                        Text(cat.rawValue).font(.subheadline)
                        Spacer(minLength: 4)
                        // bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3).fill(cat.color)
                                    .frame(width: totalFiltered > 0 ? geo.size.width * sum / totalFiltered : 0, height: 6)
                            }
                        }
                        .frame(width: 60, height: 6)
                        Text(String(format: "%.2f", sum))
                            .font(.subheadline.bold()).frame(minWidth: 70, alignment: .trailing)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    if idx < byCategory.count - 1 { Divider().padding(.leading, 56) }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Expense list

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Записи").font(.subheadline.bold()).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, expense in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(expense.category.color.opacity(0.12)).frame(width: 40, height: 40)
                            Image(systemName: expense.category.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(expense.category.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(expense.name).font(.subheadline.bold()).lineLimit(1)
                            HStack(spacing: 6) {
                                Text(expense.category.rawValue).font(.caption).foregroundStyle(.secondary)
                                if expense.recurrence != .once {
                                    Text("·").font(.caption).foregroundStyle(.secondary)
                                    Text(expense.recurrence.rawValue).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(String(format: "%.2f", expense.amount))
                                .font(.subheadline.bold())
                            Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = expense }
                    if idx < filtered.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

    private func categoryChip(_ cat: ExpenseCategory?, label: String) -> some View {
        let active = selectedCategory == cat
        let color: Color = cat?.color ?? .chefAccent
        return Button { selectedCategory = active ? nil : cat } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(active ? color : Color(.systemGray5))
                .foregroundStyle(active ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Expense Form

struct ExpenseFormView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    let expense: OperatingExpense?
    let onSave: (OperatingExpense) -> Void

    @State private var name:       String
    @State private var amount:     String
    @State private var category:   ExpenseCategory
    @State private var recurrence: ExpenseRecurrence
    @State private var date:       Date
    @State private var notes:      String

    init(expense: OperatingExpense?, onSave: @escaping (OperatingExpense) -> Void) {
        self.expense = expense
        self.onSave = onSave
        _name       = State(initialValue: expense?.name ?? "")
        _amount     = State(initialValue: expense != nil ? String(format: "%.2f", expense!.amount) : "")
        _category   = State(initialValue: expense?.category ?? .other)
        _recurrence = State(initialValue: expense?.recurrence ?? .monthly)
        _date       = State(initialValue: expense?.date ?? Date())
        _notes      = State(initialValue: expense?.notes ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название (напр. Аренда за март)", text: $name)
                    HStack {
                        Text("Сумма")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                Section("Категория") {
                    Picker("Категория", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Picker("Периодичность", selection: $recurrence) {
                        ForEach(ExpenseRecurrence.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                }

                Section("Дата и заметки") {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    TextField("Заметки (опционально)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if expense != nil {
                    Section {
                        Button(role: .destructive) {
                            store.operatingExpenses.removeAll { $0.id == expense!.id }
                            dismiss()
                        } label: {
                            Label("Удалить расход", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(expense == nil ? "Новый расход" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let ex = OperatingExpense(
                            id: expense?.id ?? UUID(),
                            name: name,
                            amount: amt,
                            category: category,
                            recurrence: recurrence,
                            date: date,
                            notes: notes
                        )
                        onSave(ex)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
