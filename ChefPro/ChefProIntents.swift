import AppIntents
import SwiftUI

// MARK: - ChefPro App Shortcuts

@available(iOS 16.0, *)
struct ChefProShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckLowStockIntent(),
            phrases: [
                "Проверить остатки в \(.applicationName)",
                "Низкие остатки \(.applicationName)",
                "Check low stock in \(.applicationName)"
            ],
            shortTitle: "Остатки склада",
            systemImageName: "exclamationmark.triangle.fill"
        )
        AppShortcut(
            intent: GetFoodCostIntent(),
            phrases: [
                "Food cost в \(.applicationName)",
                "Себестоимость в \(.applicationName)",
                "Food cost \(.applicationName)"
            ],
            shortTitle: "Food Cost",
            systemImageName: "percent"
        )
        AppShortcut(
            intent: GetShiftStatusIntent(),
            phrases: [
                "Статус смены \(.applicationName)",
                "Открыта ли смена в \(.applicationName)",
                "Shift status \(.applicationName)"
            ],
            shortTitle: "Статус смены",
            systemImageName: "clock.badge.checkmark.fill"
        )
    }
}

// MARK: - Check Low Stock

@available(iOS 16.0, *)
struct CheckLowStockIntent: AppIntent {
    static var title: LocalizedStringResource = "Проверить низкие остатки"
    static var description = IntentDescription("Показывает товары с низким остатком на складе ChefPro")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "chefpro_inventory_v2"),
              let items = try? JSONDecoder().decode([InventoryItem].self, from: data) else {
            return .result(dialog: "Нет данных о складе")
        }
        let low = items.filter { $0.quantity <= $0.minQuantity && $0.minQuantity > 0 }
        if low.isEmpty {
            return .result(dialog: "Все остатки в норме 👍")
        }
        let names = low.prefix(3).map { $0.name }.joined(separator: ", ")
        let more = low.count > 3 ? " и ещё \(low.count - 3)" : ""
        return .result(dialog: "Нужно заказать: \(names)\(more). Всего \(low.count) позиций.")
    }
}

// MARK: - Get Food Cost

@available(iOS 16.0, *)
struct GetFoodCostIntent: AppIntent {
    static var title: LocalizedStringResource = "Узнать Food Cost"
    static var description = IntentDescription("Показывает средний food cost по блюдам ChefPro")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard
        guard let dishData = defaults.data(forKey: "chefpro_dishes_v2"),
              let invData = defaults.data(forKey: "chefpro_inventory_v2"),
              let dishes = try? JSONDecoder().decode([Dish].self, from: dishData),
              let items = try? JSONDecoder().decode([InventoryItem].self, from: invData) else {
            return .result(dialog: "Нет данных о блюдах")
        }
        // Simple cost calculation without the store
        var totalFC = 0.0
        var count = 0
        for dish in dishes where dish.salePrice > 0 {
            var cost = 0.0
            for ing in dish.ingredients {
                if let item = items.first(where: { $0.name.lowercased() == ing.productName.lowercased() }) {
                    cost += ing.quantity * item.pricePerUnit
                }
            }
            let fc = cost / dish.salePrice * 100
            totalFC += fc
            count += 1
        }
        let avg = count > 0 ? totalFC / Double(count) : 0
        return .result(dialog: "Средний food cost: \(String(format: "%.1f", avg))% по \(count) блюдам")
    }
}

// MARK: - Shift Status

@available(iOS 16.0, *)
struct GetShiftStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Статус смены"
    static var description = IntentDescription("Проверяет открыта ли смена в ChefPro")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "chefpro_current_shift_v1"),
           let shift = try? JSONDecoder().decode(Shift.self, from: data) {
            let df = DateFormatter()
            df.timeStyle = .short
            let time = df.string(from: shift.openedAt)
            return .result(dialog: "Смена открыта с \(time), \(shift.duration)")
        } else {
            return .result(dialog: "Смена не открыта")
        }
    }
}
