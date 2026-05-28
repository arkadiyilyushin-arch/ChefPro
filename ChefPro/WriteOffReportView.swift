import SwiftUI
import Charts

// MARK: - Write-Off Report

struct WriteOffReportView: View {
    @EnvironmentObject var store: ChefProStore

    // Computed data

    private var priceMap: [String: Double] {
        var map: [String: Double] = [:]
        for item in store.inventoryItems {
            map[item.name.lowercased()] = item.pricePerUnit
        }
        return map
    }

    private struct DayLoss: Identifiable {
        let id = UUID()
        let date: Date
        let totalCost: Double
    }

    private var dailyLosses: [DayLoss] {
        let calendar = Calendar.current
        let now = Date()
        guard let start = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now)) else { return [] }

        let map = priceMap
        var buckets: [Date: Double] = [:]

        for writeOff in store.writeOffs {
            guard writeOff.date >= start else { continue }
            let day = calendar.startOfDay(for: writeOff.date)
            let price = map[writeOff.productName.lowercased()] ?? 0
            buckets[day, default: 0] += writeOff.quantity * price
        }

        return (0..<14).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayLoss(date: day, totalCost: buckets[day] ?? 0)
        }
    }

    private struct ProductLoss: Identifiable {
        let id = UUID()
        let name: String
        let totalQty: Double
        let unit: String
        let totalCost: Double
    }

    private var topProducts: [ProductLoss] {
        let calendar = Calendar.current
        let now = Date()
        guard let start = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now)) else { return [] }

        let map = priceMap
        var qtyMap: [String: Double] = [:]
        var unitMap: [String: String] = [:]

        for writeOff in store.writeOffs {
            guard writeOff.date >= start else { continue }
            qtyMap[writeOff.productName, default: 0] += writeOff.quantity
            unitMap[writeOff.productName] = writeOff.unit
        }

        return qtyMap
            .map { name, qty in
                let price = map[name.lowercased()] ?? 0
                return ProductLoss(name: name, totalQty: qty, unit: unitMap[name] ?? "", totalCost: qty * price)
            }
            .sorted { $0.totalQty > $1.totalQty }
            .prefix(10)
            .map { $0 }
    }

    private var totalLoss: Double {
        dailyLosses.reduce(0) { $0 + $1.totalCost }
    }

    // Date formatter for axis
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: Total
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Итого за 14 дней")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(totalLoss, specifier: "%.2f") ₽")
                            .font(.title2.bold())
                            .foregroundStyle(totalLoss > 0 ? .red : .primary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // MARK: Bar Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Потери по дням (₽)")
                        .font(.headline)
                        .padding(.horizontal)

                    if dailyLosses.allSatisfy({ $0.totalCost == 0 }) {
                        Text("Нет списаний за последние 14 дней")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Chart(dailyLosses) { point in
                            BarMark(
                                x: .value("Дата", point.date, unit: .day),
                                y: .value("Сумма", point.totalCost)
                            )
                            .foregroundStyle(Color.red.gradient)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 2)) { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(dayFormatter.string(from: date))
                                            .font(.caption2)
                                    }
                                }
                                AxisGridLine()
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // MARK: Top Products
                VStack(alignment: .leading, spacing: 8) {
                    Text("Топ-10 списываемых продуктов")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    if topProducts.isEmpty {
                        Text("Нет данных")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(topProducts.enumerated()), id: \.element.id) { index, product in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.name)
                                        .font(.subheadline.bold())
                                    Text("\(product.totalQty, specifier: "%.2f") \(product.unit)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if product.totalCost > 0 {
                                    Text("\(product.totalCost, specifier: "%.2f") ₽")
                                        .font(.subheadline)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)

                            if index < topProducts.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer(minLength: 20)
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Отчёт по списаниям")
        .navigationBarTitleDisplayMode(.inline)
    }
}
