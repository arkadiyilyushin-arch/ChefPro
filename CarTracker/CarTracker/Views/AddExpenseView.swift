import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: ExpenseViewModel

    // Если передан expense — режим редактирования
    var editingExpense: CarExpense? = nil

    @State private var category: ExpenseCategory = .fuel
    @State private var amount: String = ""
    @State private var mileage: String = ""
    @State private var liters: String = ""
    @State private var pricePerLiter: String = ""
    @State private var remainingLiters: String = ""
    @State private var tankFillType: TankFillType = .full
    @State private var note: String = ""
    @State private var date: Date = Date()

    var isEditing: Bool { editingExpense != nil }

    var lastMileage: Int { vm.lastMileage }

    var computedAmount: Double? {
        guard category == .fuel,
              let l = Double(liters.replacingOccurrences(of: ",", with: ".")),
              let p = Double(pricePerLiter.replacingOccurrences(of: ",", with: ".")),
              l > 0, p > 0
        else { return nil }
        return l * p
    }

    var displayAmount: String {
        if let a = computedAmount { return String(format: "%.2f", a) }
        return amount
    }

    var isValid: Bool {
        let a = Double(displayAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let m = Int(mileage) ?? 0
        return a > 0 && m > 0
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    categoryPicker
                    dateCard
                    mileageCard
                    if category == .fuel {
                        tankTypeCard
                        fuelCard
                        if tankFillType == .partial {
                            remainingCard
                        }
                    } else {
                        amountCard
                    }
                    noteCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Редактировать" : "Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { prefill() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Сохранить" : "Добавить") { save() }
                        .bold()
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Prefill при редактировании

    private func prefill() {
        guard let e = editingExpense else { return }
        category = e.category
        date = e.date
        mileage = String(e.mileage)
        amount = String(format: "%.2f", e.amount)
        note = e.note
        if let l = e.liters { liters = String(format: "%.2f", l) }
        if let p = e.pricePerLiter { pricePerLiter = String(format: "%.2f", p) }
        if let r = e.remainingLiters { remainingLiters = String(format: "%.2f", r) }
        tankFillType = e.tankFillType ?? .full
    }

    // MARK: - Subviews

    private var categoryPicker: some View {
        HStack(spacing: 0) {
            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                Button {
                    withAnimation(.spring(response: 0.3)) { category = cat }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.title3)
                        Text(cat.rawValue)
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        category == cat
                        ? Color.accentColor
                        : Color(.secondarySystemGroupedBackground)
                    )
                    .foregroundColor(category == cat ? .white : .secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 6, y: 2)
    }

    private var dateCard: some View {
        CardView {
            DatePicker("Дата", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.compact)
        }
    }

    private var mileageCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Label("Пробег (км)", systemImage: "speedometer")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                HStack {
                    TextField("Текущий пробег", text: $mileage)
                        .keyboardType(.numberPad)
                        .font(.title2.bold())
                    Spacer()
                    if lastMileage > 0 && !isEditing {
                        Text("Прошлый: \(lastMileage.formatted()) км")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var tankTypeCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Состояние бака", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    ForEach([TankFillType.full, TankFillType.partial], id: \.self) { type in
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                tankFillType = type
                                if type == .full { remainingLiters = "" }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: type == .full ? "fuelpump.fill" : "fuelpump")
                                    .font(.subheadline)
                                Text(type.rawValue)
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(tankFillType == type ? Color.orange : Color(.tertiarySystemGroupedBackground))
                            .foregroundColor(tankFillType == type ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private var remainingCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Label("Остаток в баке до заправки", systemImage: "drop.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                HStack {
                    TextField("0.00", text: $remainingLiters)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                    Text("л")
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text("Остаток учитывается в расчёте среднего расхода")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var fuelCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Залито топлива", systemImage: "fuelpump.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Литры")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("0.00", text: $liters)
                                .keyboardType(.decimalPad)
                                .font(.title3.bold())
                            Text("л")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Цена за литр")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("0.00", text: $pricePerLiter)
                                .keyboardType(.decimalPad)
                                .font(.title3.bold())
                            Text("₽")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Итого")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if computedAmount != nil {
                            Text("авто-расчёт")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    HStack {
                        if let a = computedAmount {
                            Text(String(format: "%.2f ₽", a))
                                .font(.title2.bold())
                                .foregroundColor(.accentColor)
                        } else {
                            TextField("Сумма вручную", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.title2.bold())
                            Text("₽")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Итоговый расчёт с остатком
                if tankFillType == .partial,
                   let l = Double(liters.replacingOccurrences(of: ",", with: ".")),
                   let r = Double(remainingLiters.replacingOccurrences(of: ",", with: ".")),
                   l > 0 {
                    Divider()
                    HStack {
                        Image(systemName: "sum")
                            .foregroundColor(.green)
                        Text("Итого в баке после заправки:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f л", l + r))
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    private var amountCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Label("Сумма", systemImage: "rublesign.circle")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                HStack {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                    Text("₽")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var noteCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Label("Примечание", systemImage: "note.text")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                TextField("Необязательно...", text: $note, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard let m = Int(mileage) else { return }
        let finalAmount: Double
        if let a = computedAmount {
            finalAmount = a
        } else {
            finalAmount = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        guard finalAmount > 0, let carId = vm.selectedCarId else { return }

        var expense = editingExpense ?? CarExpense(
            date: date, category: category, amount: finalAmount,
            mileage: m, note: note, carId: carId
        )

        expense.date = date
        expense.category = category
        expense.amount = finalAmount
        expense.mileage = m
        expense.note = note
        expense.liters = nil
        expense.pricePerLiter = nil
        expense.remainingLiters = nil
        expense.tankFillType = nil

        if category == .fuel {
            expense.liters = Double(liters.replacingOccurrences(of: ",", with: "."))
            expense.pricePerLiter = Double(pricePerLiter.replacingOccurrences(of: ",", with: "."))
            expense.tankFillType = tankFillType
            if tankFillType == .partial {
                expense.remainingLiters = Double(remainingLiters.replacingOccurrences(of: ",", with: "."))
            }
        }

        if isEditing {
            vm.updateExpense(expense)
        } else {
            vm.addExpense(expense)
        }
        dismiss()
    }
}

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}
