import SwiftUI

// MARK: - Markup Calculator

struct MarkupCalculatorView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var costInput = ""
    @State private var targetFoodCost: Double = 30

    private var cost: Double { parsePositiveDouble(costInput) ?? 0 }

    private var recommendedPrice: Double {
        guard targetFoodCost > 0 else { return 0 }
        return cost / (targetFoodCost / 100)
    }

    private var markup: Double {
        guard cost > 0 else { return 0 }
        return (recommendedPrice - cost) / cost * 100
    }

    private var margin: Double { recommendedPrice - cost }

    private var fcColor: Color {
        targetFoodCost > store.foodCostThreshold ? .red
            : targetFoodCost > store.foodCostThreshold * 0.85 ? .orange
            : .chefAccent
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {

                // Себестоимость
                BigCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Себестоимость блюда", systemImage: "cart.fill")
                            .font(.headline)
                        HStack {
                            TextField("0.00", text: $costInput)
                                .keyboardType(.decimalPad)
                                .font(.title2.bold())
                            Text("₽")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Целевой food cost
                BigCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Целевой Food Cost", systemImage: "percent")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(targetFoodCost))%")
                                .font(.title3.bold())
                                .foregroundStyle(fcColor)
                        }

                        Slider(value: $targetFoodCost, in: 15...50, step: 5)
                            .tint(fcColor)

                        // Preset buttons
                        HStack(spacing: 8) {
                            ForEach([25, 30, 35, 40], id: \.self) { val in
                                Button {
                                    withAnimation { targetFoodCost = Double(val) }
                                } label: {
                                    Text("\(val)%")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Int(targetFoodCost) == val ? fcColor : Color(.tertiarySystemBackground))
                                        .foregroundStyle(Int(targetFoodCost) == val ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if store.foodCostThreshold > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "building.2")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Целевой food cost вашего заведения: \(Int(store.foodCostThreshold))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Результат
                if cost > 0 {
                    BigCard {
                        VStack(spacing: 16) {
                            // Рекомендуемая цена
                            VStack(spacing: 4) {
                                Text("Рекомендуемая цена продажи")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(recommendedPrice, specifier: "%.2f") ₽")
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundStyle(.chefAccent)
                            }

                            Divider()

                            // Breakdown
                            VStack(spacing: 10) {
                                MarkupRow(label: "Себестоимость", value: "\(String(format: "%.2f", cost)) ₽", color: .primary)
                                MarkupRow(label: "Наценка", value: "\(String(format: "%.0f", markup))%", color: .orange)
                                MarkupRow(label: "Маржа (прибыль)", value: "\(String(format: "%.2f", margin)) ₽", color: .green)
                                MarkupRow(label: "Food Cost", value: "\(String(format: "%.0f", targetFoodCost))%", color: fcColor)
                            }
                        }
                    }
                } else {
                    BigCard {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.left")
                                .foregroundStyle(.secondary)
                            Text("Введите себестоимость блюда для расчёта")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.chefBackground)
        .navigationTitle("Калькулятор наценки")
    }
}

private struct MarkupRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }
}
