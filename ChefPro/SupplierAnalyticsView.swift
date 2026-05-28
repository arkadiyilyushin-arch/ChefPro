import SwiftUI
import Charts

struct SupplierAnalyticsView: View {
    @EnvironmentObject var store: ChefProStore

    struct SupplierStat: Identifiable {
        let id: String
        let name: String
        let totalSpend: Double
        let deliveryCount: Int
        let topProduct: String
        let avgPrice: Double
        let deliveries: [Delivery]
    }

    private var stats: [SupplierStat] {
        let grouped = Dictionary(grouping: store.deliveries, by: { $0.supplier })
        return grouped.map { name, deliveries in
            let total = deliveries.reduce(0) { $0 + $1.price }
            let topProduct = Dictionary(grouping: deliveries, by: { $0.productName })
                .max(by: { $0.value.count < $1.value.count })?.key ?? ""
            return SupplierStat(
                id: name,
                name: name,
                totalSpend: total,
                deliveryCount: deliveries.count,
                topProduct: topProduct,
                avgPrice: deliveries.isEmpty ? 0 : total / Double(deliveries.count),
                deliveries: deliveries.sorted { $0.date > $1.date }
            )
        }.sorted { $0.totalSpend > $1.totalSpend }
    }

    var body: some View {
        NavigationStack {
            if stats.isEmpty {
                EmptyStateView(icon: "building.2.fill", title: "Нет данных", subtitle: "Добавьте приёмки товаров")
                    .frame(maxHeight: .infinity)
                    .background(Color.chefBackground)
                    .navigationTitle("Аналитика поставщиков")
            } else {
                List {
                    // Total spend summary
                    Section {
                        let total = stats.reduce(0) { $0 + $1.totalSpend }
                        HStack {
                            Label("Всего потрачено", systemImage: "creditcard.fill")
                            Spacer()
                            Text("\(Int(total)) ₽").font(.headline).foregroundStyle(.chefAccent)
                        }
                        HStack {
                            Label("Поставщиков", systemImage: "building.2")
                            Spacer()
                            Text("\(stats.count)").foregroundStyle(.secondary)
                        }
                    }

                    // Per-supplier breakdown
                    Section("По поставщикам") {
                        ForEach(stats) { stat in
                            NavigationLink {
                                SupplierSpendDetailView(stat: stat).environmentObject(store)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(stat.name).font(.headline)
                                        Spacer()
                                        Text("\(Int(stat.totalSpend)) ₽")
                                            .font(.headline).foregroundStyle(.chefAccent)
                                    }
                                    HStack {
                                        Text("\(stat.deliveryCount) приёмок")
                                            .font(.caption).foregroundStyle(.secondary)
                                        if !stat.topProduct.isEmpty {
                                            Text("· топ: \(stat.topProduct)")
                                                .font(.caption).foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    // Spend bar proportional to max
                                    let maxSpend = stats.first?.totalSpend ?? 1
                                    ProgressView(value: stat.totalSpend / maxSpend)
                                        .tint(.chefAccent)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .background(Color.chefBackground)
                .navigationTitle("Аналитика поставщиков")
            }
        }
    }
}

struct SupplierSpendDetailView: View {
    @EnvironmentObject var store: ChefProStore
    let stat: SupplierAnalyticsView.SupplierStat

    // Product breakdown
    private var productStats: [(name: String, total: Double, count: Int)] {
        let grouped = Dictionary(grouping: stat.deliveries, by: { $0.productName })
        return grouped.map { name, dels in
            (name: name, total: dels.reduce(0) { $0 + $1.price }, count: dels.count)
        }.sorted { $0.total > $1.total }
    }

    var body: some View {
        List {
            Section("Итого") {
                HStack { Text("Сумма закупок"); Spacer(); Text("\(Int(stat.totalSpend)) ₽").bold() }
                HStack { Text("Приёмок"); Spacer(); Text("\(stat.deliveryCount)").foregroundStyle(.secondary) }
                HStack { Text("Средний чек"); Spacer(); Text("\(Int(stat.avgPrice)) ₽").foregroundStyle(.secondary) }
            }

            Section("Товары") {
                ForEach(productStats, id: \.name) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.subheadline)
                            Text("\(p.count) закупок").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(p.total)) ₽").font(.subheadline.bold()).foregroundStyle(.chefAccent)
                    }
                }
            }

            Section("Последние приёмки") {
                ForEach(stat.deliveries.prefix(10)) { d in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.productName).font(.subheadline)
                            Text(d.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(d.price)) ₽").font(.subheadline.bold())
                            Text("\(d.quantity, specifier: "%.1f") \(d.unit)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(stat.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
