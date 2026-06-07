import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var vm: ExpenseViewModel

    var chartData: [(category: String, amount: Double, color: Color)] {
        [
            ("Топливо", vm.totalFuel, .orange),
            ("Сервис", vm.totalService, .blue),
            ("Прочее", vm.totalOther, .purple)
        ].filter { $0.amount > 0 }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if vm.currentCarExpenses.isEmpty {
                        emptyState
                    } else {
                        consumptionCard
                        totalsCard
                        if !chartData.isEmpty { pieCard }
                        monthlyCard
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Статистика")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Нет данных")
                .font(.title2.bold())
            Text("Добавьте первые расходы\nдля просмотра статистики")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Карточка расхода топлива

    private var consumptionCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Средний расход", systemImage: "fuelpump.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                if let avg = vm.averageFuelConsumption {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", avg))
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                        Text("л/100 км")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    Text("Рассчитано по \(vm.currentCarExpenses.filter { $0.category == .fuel && $0.tankFillType == .full }.count) полным бакам")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Добавьте минимум 2 заправки\nс полным баком для расчёта расхода")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if vm.lastMileage > 0 {
                    Divider()
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.accentColor)
                        Text("Текущий пробег: \(vm.lastMileage.formatted()) км")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Итого

    private var totalsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Общие расходы", systemImage: "banknote.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(vm.totalExpenses.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                    Text("₽")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 10) {
                    expenseRow(icon: "fuelpump.fill", label: "Топливо",
                               amount: vm.totalFuel, color: .orange)
                    expenseRow(icon: "wrench.and.screwdriver.fill", label: "Сервис",
                               amount: vm.totalService, color: .blue)
                    expenseRow(icon: "ellipsis.circle.fill", label: "Прочее",
                               amount: vm.totalOther, color: .purple)
                }
            }
        }
    }

    private func expenseRow(icon: String, label: String, amount: Double, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(amount.formatted(.number.precision(.fractionLength(0)))) ₽")
                .font(.subheadline.bold())
        }
    }

    // MARK: - Pie chart

    private var pieCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Распределение", systemImage: "chart.pie.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                Chart(chartData, id: \.category) { item in
                    SectorMark(
                        angle: .value("Сумма", item.amount),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(6)
                }
                .frame(height: 200)

                HStack(spacing: 16) {
                    ForEach(chartData, id: \.category) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.category)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - По месяцам

    private var monthlyCard: some View {
        let grouped = Dictionary(grouping: vm.currentCarExpenses) { expense -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL yyyy"
            formatter.locale = Locale(identifier: "ru_RU")
            return formatter.string(from: expense.date)
        }
        let months = grouped.keys.sorted(by: >)

        return CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label("По месяцам", systemImage: "calendar")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                ForEach(months.prefix(6), id: \.self) { month in
                    let total = grouped[month]!.reduce(0) { $0 + $1.amount }
                    HStack {
                        Text(month.capitalized)
                            .font(.subheadline)
                        Spacer()
                        Text("\(total.formatted(.number.precision(.fractionLength(0)))) ₽")
                            .font(.subheadline.bold())
                    }
                    if month != months.prefix(6).last {
                        Divider()
                    }
                }
            }
        }
    }
}
