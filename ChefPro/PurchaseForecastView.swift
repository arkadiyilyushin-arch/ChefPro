import SwiftUI

struct PurchaseForecastView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var forecastDays = 7

    struct ForecastItem: Identifiable {
        let id: UUID
        let name: String
        let unit: String
        let currentStock: Double
        let avgDailyUsage: Double
        let daysRemaining: Double
        let neededQty: Double      // to cover forecastDays
        let orderUnit: String
    }

    private var forecastItems: [ForecastItem] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        // Sum write-offs per item over last 30 days (production-related)
        var usageMap: [String: Double] = [:]
        for wo in store.writeOffs where wo.date >= cutoff {
            usageMap[wo.productName.lowercased(), default: 0] += wo.quantity
        }

        var items: [ForecastItem] = []
        for inv in store.inventoryItems {
            let key = inv.name.lowercased()
            let totalUsage = usageMap[key] ?? 0
            guard totalUsage > 0 else { continue }
            let avgDaily = totalUsage / 30.0
            let daysLeft = avgDaily > 0 ? inv.quantity / avgDaily : 999
            let needed = max(0, avgDaily * Double(forecastDays) - inv.quantity)
            items.append(ForecastItem(
                id: inv.id,
                name: inv.name,
                unit: inv.unit,
                currentStock: inv.quantity,
                avgDailyUsage: avgDaily,
                daysRemaining: daysLeft,
                neededQty: needed,
                orderUnit: inv.effectiveOrderUnit
            ))
        }
        return items.sorted { $0.daysRemaining < $1.daysRemaining }
    }

    private var criticalItems: [ForecastItem] { forecastItems.filter { $0.daysRemaining < Double(forecastDays) } }
    private var okItems: [ForecastItem] { forecastItems.filter { $0.daysRemaining >= Double(forecastDays) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Days selector
                Picker("Горизонт прогноза", selection: $forecastDays) {
                    Text("3 дня").tag(3)
                    Text("7 дней").tag(7)
                    Text("14 дней").tag(14)
                    Text("30 дней").tag(30)
                }
                .pickerStyle(.segmented)
                .padding()

                if forecastItems.isEmpty {
                    EmptyStateView(
                        icon: "chart.line.downtrend.xyaxis",
                        title: "Нет данных",
                        subtitle: "Нужны данные о производстве за последние 30 дней"
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        if !criticalItems.isEmpty {
                            Section("⚠ Нужно заказать (\(criticalItems.count))") {
                                ForEach(criticalItems) { item in
                                    ForecastRow(item: item, forecastDays: forecastDays, urgent: true)
                                }
                            }
                        }
                        if !okItems.isEmpty {
                            Section("✓ Хватит на \(forecastDays) дней (\(okItems.count))") {
                                ForEach(okItems) { item in
                                    ForecastRow(item: item, forecastDays: forecastDays, urgent: false)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.chefBackground)
            .navigationTitle("Прогноз закупок")
        }
    }
}

private struct ForecastRow: View {
    let item: PurchaseForecastView.ForecastItem
    let forecastDays: Int
    let urgent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name).font(.headline)
                Spacer()
                if item.neededQty > 0 {
                    Text("Заказать: \(String(format: "%.1f", item.neededQty)) \(item.orderUnit)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(urgent ? Color.red : Color.chefAccent)
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 16) {
                Label("\(String(format: "%.1f", item.currentStock)) \(item.unit)", systemImage: "shippingbox.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Label("\(String(format: "%.1f", item.avgDailyUsage))/день", systemImage: "chart.bar.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Label(item.daysRemaining < 999 ? "\(Int(item.daysRemaining)) дн." : "∞", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(urgent ? .red : .green)
            }
        }
        .padding(.vertical, 4)
    }
}
