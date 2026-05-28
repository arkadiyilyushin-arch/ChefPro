import SwiftUI

struct BreakevenView: View {
    @EnvironmentObject var store: ChefProStore

    @State private var rent: String = ""
    @State private var salaries: String = ""
    @State private var utilities: String = ""
    @State private var other: String = ""
    @State private var avgCheck: String = ""

    private func parseField(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var fixedCosts: Double {
        parseField(rent) + parseField(salaries) + parseField(utilities) + parseField(other)
    }

    private var avgFoodCost: Double {
        let dishes = store.dishes.filter { $0.salePrice > 0 }
        guard !dishes.isEmpty else { return 30 }
        let total = dishes.reduce(0.0) { $0 + store.foodCostPercent($1) }
        return total / Double(dishes.count)
    }

    private var variableCostRate: Double { avgFoodCost / 100.0 }
    private var contributionMarginRate: Double { 1.0 - variableCostRate }

    private var breakevenRevenue: Double {
        guard contributionMarginRate > 0 else { return 0 }
        return fixedCosts / contributionMarginRate
    }

    private var breakevenPerDay: Double { breakevenRevenue / 30.0 }

    private var breakevenCovers: Double {
        let check = Double(avgCheck.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard check > 0 else { return 0 }
        return breakevenRevenue / check
    }

    private var safetyMargin: Double {
        let monthRevenue = store.currentMonthRevenue
        guard breakevenRevenue > 0 else { return 0 }
        return (monthRevenue - breakevenRevenue) / breakevenRevenue * 100
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Постоянные расходы в месяц") {
                    CostRow(label: "Аренда", value: $rent, icon: "building.fill")
                    CostRow(label: "Зарплаты", value: $salaries, icon: "person.2.fill")
                    CostRow(label: "Коммунальные", value: $utilities, icon: "bolt.fill")
                    CostRow(label: "Прочие", value: $other, icon: "ellipsis.circle.fill")

                    HStack {
                        Text("Итого постоянных").bold()
                        Spacer()
                        Text("\(Int(fixedCosts)) ₽").bold().foregroundStyle(.chefAccent)
                    }
                }

                Section("Параметры") {
                    HStack {
                        Label("Food Cost (авто)", systemImage: "percent")
                        Spacer()
                        Text("\(String(format: "%.1f", avgFoodCost))%").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Средний чек")
                        Spacer()
                        TextField("0", text: $avgCheck)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("₽").foregroundStyle(.secondary)
                    }
                }

                if fixedCosts > 0 {
                    Section("Точка безубыточности") {
                        ResultRow(label: "Выручка в месяц", value: "\(Int(breakevenRevenue)) ₽", color: .orange)
                        ResultRow(label: "Выручка в день", value: "\(Int(breakevenPerDay)) ₽", color: .orange)
                        if breakevenCovers > 0 {
                            ResultRow(label: "Гостей в месяц", value: "\(Int(breakevenCovers))", color: .blue)
                            ResultRow(label: "Гостей в день", value: "\(Int(breakevenCovers / 30))", color: .blue)
                        }
                    }

                    if store.currentMonthRevenue > 0 {
                        Section("Текущий месяц") {
                            ResultRow(label: "Выручка", value: "\(Int(store.currentMonthRevenue)) ₽",
                                      color: store.currentMonthRevenue >= breakevenRevenue ? .green : .red)
                            ResultRow(
                                label: store.currentMonthRevenue >= breakevenRevenue ? "Запас прочности" : "До безубыточности",
                                value: "\(abs(Int(safetyMargin)))%",
                                color: safetyMargin >= 0 ? .green : .red
                            )
                        }
                    }
                }
            }
            .navigationTitle("Точка безубыточности")
        }
    }
}

private struct CostRow: View {
    let label: String
    @Binding var value: String
    let icon: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
            Text("₽").foregroundStyle(.secondary)
        }
    }
}

private struct ResultRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.headline).foregroundStyle(color)
        }
    }
}
