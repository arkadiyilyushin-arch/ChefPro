import SwiftUI

// MARK: - ABC Analysis of Inventory

private struct InventoryABCItem: Identifiable {
    let id:        UUID
    let item:      InventoryItem
    let value:     Double    // quantity * price
    let valuePct:  Double    // % of total value
    let cumPct:    Double    // cumulative %
    let abc:       String    // "A", "B", "C"

    var abcColor: Color {
        switch abc {
        case "A": return .red
        case "B": return .orange
        default:  return .green
        }
    }
}

struct ABCAnalysisView: View {
    @EnvironmentObject var store: ChefProStore

    enum ABCFilter: String, CaseIterable {
        case all = "Все"
        case a   = "A"
        case b   = "B"
        case c   = "C"
    }
    @State private var filter: ABCFilter = .all

    // MARK: - Computed

    private var abcItems: [InventoryABCItem] {
        let sorted = store.inventoryItems.sorted {
            ($0.quantity * $0.pricePerUnit) > ($1.quantity * $1.pricePerUnit)
        }
        let total = sorted.reduce(0.0) { $0 + $1.quantity * $1.pricePerUnit }
        guard total > 0 else {
            return sorted.map { InventoryABCItem(id: $0.id, item: $0, value: 0, valuePct: 0, cumPct: 0, abc: "C") }
        }
        var cumulative = 0.0
        return sorted.map { item in
            let val     = item.quantity * item.pricePerUnit
            let pct     = val / total * 100
            let prevCum = cumulative
            cumulative += pct
            let abc: String
            if prevCum < 80      { abc = "A" }
            else if prevCum < 95 { abc = "B" }
            else                 { abc = "C" }
            return InventoryABCItem(id: item.id, item: item, value: val, valuePct: pct, cumPct: cumulative, abc: abc)
        }
    }

    private var filtered: [InventoryABCItem] {
        switch filter {
        case .all: return abcItems
        case .a:   return abcItems.filter { $0.abc == "A" }
        case .b:   return abcItems.filter { $0.abc == "B" }
        case .c:   return abcItems.filter { $0.abc == "C" }
        }
    }

    private var totalValue: Double { abcItems.reduce(0) { $0 + $1.value } }

    private func count(_ abc: String) -> Int    { abcItems.filter { $0.abc == abc }.count }
    private func value(_ abc: String) -> Double { abcItems.filter { $0.abc == abc }.reduce(0) { $0 + $1.value } }
    private func pct(_ abc: String)   -> Double { totalValue > 0 ? value(abc) / totalValue * 100 : 0 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // ── Summary cards ──────────────────────────
                    HStack(spacing: 0) {
                        abcCard("A", color: .red,    hint: "80% стоимости")
                        abcCard("B", color: .orange, hint: "15% стоимости")
                        abcCard("C", color: .green,  hint: "5% стоимости")
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // ── Progress bar ────────────────────────────
                    if totalValue > 0 {
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                Color.red.frame(width: geo.size.width * CGFloat(pct("A") / 100))
                                Color.orange.frame(width: geo.size.width * CGFloat(pct("B") / 100))
                                Color.green
                            }
                        }
                        .frame(height: 8)
                        .clipShape(Capsule())
                        .padding(.horizontal)
                    }

                    Text("Принцип Парето: ~20% позиций формируют ~80% стоимости склада")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // ── Filter ──────────────────────────────────
                    Picker("Фильтр", selection: $filter) {
                        ForEach(ABCFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // ── Item list ───────────────────────────────
                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 44))
                                .foregroundStyle(.tertiary)
                            Text("Нет позиций в категории \(filter.rawValue)")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, ai in
                                abcRow(ai)
                                if idx < filtered.count - 1 {
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ABC-анализ склада")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Subviews

    private func abcCard(_ abc: String, color: Color, hint: String) -> some View {
        VStack(spacing: 4) {
            Text(abc)
                .font(.title.bold())
                .foregroundStyle(color)
            Text("\(count(abc)) поз.")
                .font(.subheadline.bold())
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(String(format: "%.1f", pct(abc)))%")
                .font(.caption.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.1))
    }

    private func abcRow(_ ai: InventoryABCItem) -> some View {
        HStack(spacing: 12) {
            Text(ai.abc)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(ai.abcColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(ai.item.name).font(.subheadline.bold())
                HStack(spacing: 6) {
                    Text(ai.item.category)
                    Text("·")
                    Text("\(String(format: "%.1f", ai.item.quantity)) \(ai.item.unit)")
                        .foregroundStyle(ai.item.isLowStock ? .red : .secondary)
                    if ai.item.isLowStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red).font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(ai.value)) ₽")
                    .font(.subheadline.bold())
                Text("\(String(format: "%.1f", ai.valuePct))%")
                    .font(.caption)
                    .foregroundStyle(ai.abcColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
