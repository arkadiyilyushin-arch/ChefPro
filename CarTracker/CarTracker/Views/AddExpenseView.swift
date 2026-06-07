import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: ExpenseViewModel

    @State private var category: ExpenseCategory = .fuel
    @State private var amount: String = ""
    @State private var mileage: String = ""
    @State private var liters: String = ""
    @State private var pricePerLiter: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var tankFillType: TankFillType = .full
    @State private var syncAmount = true

    var lastMileage: Int { vm.lastMileage }

    var computedAmount: Double? {
        guard category == .fuel, syncAmount,
              let l = Double(liters.replacingOccurrences(of: ",", with: ".")),
              let p = Double(pricePerLiter.replacingOccurrences(of: ",", with: "."))
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
                    } else {
                        amountCard
                    }
                    noteCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .bold()
                        .disabled(!isValid)
                }
            }
        }
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
                    if lastMileage > 0 {
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
                            withAnimation(.spring(response: 0.25)) { tankFillType = type }
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

                if tankFillType == .partial {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Эта заправка не будет учитываться в расчёте среднего расхода")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var fuelCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Топливо", systemImage: "fuelpump.fill")
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

        var expense = CarExpense(
            date: date,
            category: category,
            amount: finalAmount,
            mileage: m,
            note: note,
            carId: carId
        )
        if category == .fuel {
            expense.liters = Double(liters.replacingOccurrences(of: ",", with: "."))
            expense.pricePerLiter = Double(pricePerLiter.replacingOccurrences(of: ",", with: "."))
            expense.tankFillType = tankFillType
        }
        vm.addExpense(expense)
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
