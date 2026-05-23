import WidgetKit
import SwiftUI

// MARK: - Shared Data Keys

private let appGroupID = "group.com.chefpro.app"
private let foodCostPercentKey = "widget_food_cost_percent"
private let lowStockCountKey = "widget_low_stock_count"
private let restaurantNameKey = "widget_restaurant_name"

// MARK: - Timeline Entry

struct ChefProEntry: TimelineEntry {
    let date: Date
    let restaurantName: String
    let foodCostPercent: Double
    let lowStockCount: Int
}

// MARK: - Timeline Provider

struct ChefProTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> ChefProEntry {
        ChefProEntry(
            date: Date(),
            restaurantName: "ChefPro",
            foodCostPercent: 28.5,
            lowStockCount: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ChefProEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChefProEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> ChefProEntry {
        let defaults = UserDefaults(suiteName: appGroupID)
        let restaurantName = defaults?.string(forKey: restaurantNameKey) ?? "ChefPro"
        let foodCostPercent = defaults?.double(forKey: foodCostPercentKey) ?? 0.0
        let lowStockCount = defaults?.integer(forKey: lowStockCountKey) ?? 0
        return ChefProEntry(
            date: Date(),
            restaurantName: restaurantName,
            foodCostPercent: foodCostPercent,
            lowStockCount: lowStockCount
        )
    }
}

// MARK: - Small Widget View

struct ChefProSmallWidgetView: View {
    let entry: ChefProEntry

    var foodCostColor: Color {
        if entry.foodCostPercent < 25 { return .green }
        if entry.foodCostPercent < 35 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.orange)
                    .font(.system(size: 14, weight: .semibold))
                Text("ChefPro")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Food Cost")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%%", entry.foodCostPercent))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(foodCostColor)
            }

            Spacer()

            if entry.lowStockCount > 0 {
                Label("\(entry.lowStockCount) low stock", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
            } else {
                Label("Stock OK", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget View

struct ChefProMediumWidgetView: View {
    let entry: ChefProEntry

    var foodCostColor: Color {
        if entry.foodCostPercent < 25 { return .green }
        if entry.foodCostPercent < 35 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left panel — Food Cost
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.orange)
                        .font(.system(size: 13, weight: .semibold))
                    Text(entry.restaurantName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Food Cost Today")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", entry.foodCostPercent))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(foodCostColor)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Divider()
                .padding(.vertical, 12)

            // Right panel — Stock
            VStack(alignment: .leading, spacing: 6) {
                Text("Inventory")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if entry.lowStockCount > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 22))
                        Text("\(entry.lowStockCount) items")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                        Text("low stock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 22))
                        Text("All clear")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                        Text("no shortages")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Widget Entry View

struct ChefProWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: ChefProEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            ChefProSmallWidgetView(entry: entry)
        case .systemMedium:
            ChefProMediumWidgetView(entry: entry)
        default:
            ChefProSmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct ChefProWidget: Widget {
    let kind: String = "ChefProWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChefProTimelineProvider()) { entry in
            ChefProWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ChefPro")
        .description("Monitor food cost and inventory status at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    ChefProWidget()
} timeline: {
    ChefProEntry(date: .now, restaurantName: "My Restaurant", foodCostPercent: 27.4, lowStockCount: 0)
    ChefProEntry(date: .now, restaurantName: "My Restaurant", foodCostPercent: 38.1, lowStockCount: 3)
}

#Preview(as: .systemMedium) {
    ChefProWidget()
} timeline: {
    ChefProEntry(date: .now, restaurantName: "My Restaurant", foodCostPercent: 27.4, lowStockCount: 0)
    ChefProEntry(date: .now, restaurantName: "My Restaurant", foodCostPercent: 38.1, lowStockCount: 3)
}
