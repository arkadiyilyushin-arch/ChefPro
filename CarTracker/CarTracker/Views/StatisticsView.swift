import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var vm: ExpenseViewModel
    @State private var collapsedMonths: Set<String> = []

    var monthlyGroups: [(month: String, date: Date, expenses: [CarExpense])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")

        let dict = Dictionary(grouping: vm.currentCarExpenses) { expense -> String in
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
            ScrollView {
                VStack(spacing: 16) {
                    if vm.currentCarExpenses.isEmpty {
                        emptyState
                    } else {
                        overallCard
                        consumptionCard
                        if !monthlyGroups.isEmpty {
                            monthlySection
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Статистика")
        }
    }

    // MARK: - Общий итог

    private var overallCard: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Все расходы", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(formatAmount(vm.totalExpenses))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                Text("₽")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 0) {
                categoryTotal(icon: "fuelpump.fill", color: .orange,
                              label: "Топливо", amount: vm.totalFuel)
                Divider().frame(height: 44)
                categoryTotal(icon: "wrench.and.screwdriver.fill", color: .blue,
                              label: "Сервис", amount: vm.totalService)
                Divider().frame(height: 44)
                categoryTotal(icon: "ellipsis.circle.fill", color: .purple,
                              label: "Прочее", amount: vm.totalOther)
            }
            .padding(.vertical, 4)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    private func categoryTotal(icon: String, color: Color, label: String, amount: Double) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
            Text(formatAmount(amount))
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Расход топлива

    private var consumptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Средний расход топлива", systemImage: "fuelpump.fill")
                .font(.headline)

            if let avg = vm.averageFuelConsumption {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", avg))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                    Text("л / 100 км")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                Text("По \(vm.currentCarExpenses.filter { $0.category == .fuel && $0.liters != nil }.count) заправкам с учётом остатков")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("Добавьте минимум 2 заправки\nдля расчёта расхода")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if vm.lastMileage > 0 {
                Divider()
                HStack {
                    Image(systemName: "speedometer").foregroundColor(.accentColor)
                    Text("Последний пробег: \(vm.lastMileage.formatted()) км")
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Секции по месяцам

    private var monthlySection: some View {
        VStack(spacing: 10) {
            HStack {
                Label("По месяцам", systemImage: "calendar")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)

            ForEach(monthlyGroups, id: \.month) { group in
                monthCard(group: group)
            }
        }
    }

    private func monthCard(group: (month: String, date: Date, expenses: [CarExpense])) -> some View {
        let isCollapsed = collapsedMonths.contains(group.month)
        let total = group.expenses.reduce(0) { $0 + $1.amount }
        let fuel = group.expenses.filter { $0.category == .fuel }.reduce(0) { $0 + $1.amount }
        let service = group.expenses.filter { $0.category == .service }.reduce(0) { $0 + $1.amount }
        let other = group.expenses.filter { $0.category == .other }.reduce(0) { $0 + $1.amount }
        let liters = group.expenses.compactMap { $0.liters }.reduce(0, +)

        return VStack(spacing: 0) {
            // Заголовок месяца
            Button {
                withAnimation(.spring(response: 0.35)) {
                    if isCollapsed { collapsedMonths.remove(group.month) }
                    else { collapsedMonths.insert(group.month) }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.month.capitalized)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(group.expenses.count) \(pluralRecords(group.expenses.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(formatAmount(total)) ₽")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollapsed)
                        .padding(.leading, 4)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Детали месяца
            if !isCollapsed {
                Divider().padding(.horizontal, 16)

                VStack(spacing: 0) {
                    // Строки по категориям
                    if fuel > 0 {
                        monthDetailRow(icon: "fuelpump.fill", color: .orange,
                                       label: "Топливо", amount: fuel,
                                       extra: liters > 0 ? String(format: "%.1f л", liters) : nil)
                        Divider().padding(.horizontal, 16)
                    }
                    if service > 0 {
                        monthDetailRow(icon: "wrench.and.screwdriver.fill", color: .blue,
                                       label: "Сервис", amount: service, extra: nil)
                        if other > 0 { Divider().padding(.horizontal, 16) }
                    }
                    if other > 0 {
                        monthDetailRow(icon: "ellipsis.circle.fill", color: .purple,
                                       label: "Прочее", amount: other, extra: nil)
                    }

                    // Мини-пайчарт если несколько категорий
                    let categories = [fuel, service, other].filter { $0 > 0 }
                    if categories.count > 1 {
                        Divider().padding(.horizontal, 16)
                        monthMiniChart(fuel: fuel, service: service, other: other, total: total)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    private func monthDetailRow(icon: String, color: Color, label: String,
                                amount: Double, extra: String?) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
            if let extra {
                Text(extra)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
            }
            Spacer()
            Text("\(formatAmount(amount)) ₽")
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func monthMiniChart(fuel: Double, service: Double, other: Double, total: Double) -> some View {
        HStack(spacing: 6) {
            // Прогресс-бары
            GeometryReader { geo in
                HStack(spacing: 3) {
                    if fuel > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: geo.size.width * fuel / total)
                    }
                    if service > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * service / total)
                    }
                    if other > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.purple)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty

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

    // MARK: - Helpers

    private func formatAmount(_ value: Double) -> String {
        Int(value).formatted()
    }

    private func pluralRecords(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "запись" }
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) { return "записи" }
        return "записей"
    }
}
