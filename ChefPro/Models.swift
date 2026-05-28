import SwiftUI

// MARK: - Models

struct RecipeIngredient: Identifiable, Codable {
    var id = UUID()
    var productName: String
    var quantity: Double
    var unit: String
    var yieldFactor: Double = 1.0   // 0.8 = 20% processing loss; cost = quantity / yieldFactor * price
}

let allAllergens = ["Глютен","Лактоза","Яйца","Орехи","Рыба","Морепродукты","Соя","Сельдерей","Горчица","Кунжут","Сульфиты"]

enum DishType: String, Codable, CaseIterable {
    case dish         = "Блюдо"
    case semifinished = "Полуфабрикат"

    var icon: String {
        switch self {
        case .dish:         return "fork.knife"
        case .semifinished: return "archivebox.fill"
        }
    }
}

enum DishMenuStatus: String, Codable, CaseIterable {
    case active   = "Активное"
    case seasonal = "Сезонное"
    case removed  = "Снято"

    var icon: String {
        switch self {
        case .active:   return "checkmark.circle.fill"
        case .seasonal: return "leaf.fill"
        case .removed:  return "xmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .active:   return .green
        case .seasonal: return .orange
        case .removed:  return .red
        }
    }
}

struct CookingStep: Identifiable, Codable {
    var id = UUID()
    var stepNumber: Int
    var instruction: String
    var photoFilename: String? = nil
    var durationMinutes: Int = 0   // 0 = not set
    var tip: String = ""           // optional chef tip
}

struct Dish: Identifiable, Codable {
    var id = UUID()
    var name: String
    var category: String
    var salePrice: Double
    var ingredients: [RecipeIngredient]
    var allergens: [String] = []
    var isFavorite: Bool = false
    var cookTime: Int = 0              // minutes; 0 = not set
    var menuStatus: DishMenuStatus = .active
    var photoFilename: String? = nil
    var steps: [CookingStep] = []
    var dishType: DishType = .dish
    var portionWeight: Double = 0      // Выход готового блюда, граммы
    var portionWeightUnit: String = "г"
    var calories: Double = 0       // ккал на порцию
    var proteins: Double = 0       // белки, г
    var fats: Double = 0           // жиры, г
    var carbs: Double = 0          // углеводы, г
}

struct Sale: Identifiable, Codable {
    var id       = UUID()
    var dishName: String
    var portions: Int
    var date:     Date
    var employee: String
}

struct PlanItem: Identifiable, Codable {
    var id       = UUID()
    var dishID:   UUID
    var dishName: String
    var portions: Int
}

struct PricePoint: Identifiable, Codable {
    var id    = UUID()
    var date:  Date
    var price: Double
}

struct InventoryItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var category: String
    var quantity: Double
    var unit: String
    var minQuantity: Double
    var pricePerUnit: Double
    var barcode:        String       = ""
    var priceHistory:   [PricePoint] = []
    var expiryDate:     Date?        = nil
    var orderUnit:      String       = ""
    var orderUnitRatio: Double       = 1
    var sourceDishID:   UUID?        = nil   // если создан из полуфабриката

    var isLowStock: Bool { quantity <= minQuantity }

    var isExpired: Bool {
        guard let d = expiryDate else { return false }
        return d < Date()
    }

    var isExpiringSoon: Bool {
        guard let d = expiryDate else { return false }
        let in3 = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return d > Date() && d <= in3
    }

    var effectiveOrderUnit: String { orderUnit.isEmpty ? unit : orderUnit }
}

struct Delivery: Identifiable, Codable {
    var id = UUID()
    var supplier: String
    var productName: String
    var category: String = ""
    var quantity: Double
    var unit: String
    var price: Double
    var date: Date
    var acceptedBy: String
    var notes: String = ""
}

struct WriteOff: Identifiable, Codable {
    var id = UUID()
    var productName: String
    var quantity: Double
    var unit: String
    var reason: String
    var employee: String
    var date: Date
}

enum StockMovementType: String, Codable, CaseIterable {
    case delivery    = "Приход"
    case writeOff    = "Списание"
    case production  = "Производство"
    case audit       = "Инвентаризация"
    case adjustment  = "Корректировка"

    var icon: String {
        switch self {
        case .delivery:   return "tray.and.arrow.down.fill"
        case .writeOff:   return "trash.fill"
        case .production: return "flame.fill"
        case .audit:      return "list.clipboard.fill"
        case .adjustment: return "slider.horizontal.3"
        }
    }
    var color: Color {
        switch self {
        case .delivery:   return .green
        case .writeOff:   return .red
        case .production: return .orange
        case .audit:      return .purple
        case .adjustment: return .blue
        }
    }
    var sign: String {
        switch self {
        case .delivery:   return "+"
        case .writeOff, .production: return "−"
        case .audit, .adjustment: return "±"
        }
    }
}

struct StockMovement: Identifiable, Codable {
    var id = UUID()
    var itemName: String
    var itemID: UUID?
    var type: StockMovementType
    var quantity: Double
    var unit: String
    var date: Date = Date()
    var note: String = ""
}

struct Production: Identifiable, Codable {
    var id = UUID()
    var dishName: String
    var portions: Int
    var totalCost: Double
    var date: Date
    var employee: String
    var actualPortionWeight: Double = 0   // фактический выход, г (0 = не указан)
}

struct UserProfile: Codable {
    var name: String
    var position: String
    var phone: String
    var permissions: [String]
}

struct Employee: Identifiable, Codable {
    var id = UUID()
    var name: String
    var position: String
    var phone: String
    var pin: String
    var permissions: [String]
}

enum AppColorScheme: String, Codable, CaseIterable {
    case system = "Системная"
    case light  = "Светлая"
    case dark   = "Тёмная"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct Supplier: Identifiable, Codable {
    var id    = UUID()
    var name: String
    var phone: String  = ""
    var email: String  = ""
    var notes: String  = ""
}

struct Shift: Identifiable, Codable {
    var id         = UUID()
    var openedAt:  Date
    var closedAt:  Date?
    var openedBy:  String
    var productionsCount:    Int    = 0
    var writeOffsCount:      Int    = 0
    var deliveriesCount:     Int    = 0
    var totalProductionCost: Double = 0
    var totalDeliveryCost:   Double = 0

    // MARK: Financial data (Feature 5)
    var revenue:          Double = 0   // общая выручка за смену
    var cashRevenue:      Double = 0   // наличные
    var cardRevenue:      Double = 0   // безнал
    var guestsCount:      Int    = 0   // количество гостей
    var foodCostForShift: Double = 0   // food cost % за смену

    var averageCheck: Double { guestsCount > 0 ? revenue / Double(guestsCount) : 0 }

    var isOpen: Bool { closedAt == nil }

    var duration: String {
        let end  = closedAt ?? Date()
        let secs = Int(end.timeIntervalSince(openedAt))
        let h    = secs / 3600
        let m    = (secs % 3600) / 60
        return h > 0 ? "\(h)ч \(m)м" : "\(m)м"
    }
}

enum ChecklistType: String, Codable, CaseIterable {
    case opening = "Открытие"
    case closing = "Закрытие"
    var icon: String { self == .opening ? "sun.horizon.fill" : "moon.fill" }
    var color: Color { self == .opening ? .orange : .indigo }
}

struct ChecklistItem: Identifiable, Codable {
    var id = UUID()
    var text: String
    var type: ChecklistType
    var isDefault: Bool = true        // default template items vs custom
    var isCompleted: Bool = false
    var completedBy: String = ""
    var completedAt: Date? = nil
}

struct MenuCollection: Identifiable, Codable {
    var id = UUID()
    var name: String
    var emoji: String = "🍽️"
    var dishIDs: [UUID] = []
}

struct WorkShift: Identifiable, Codable {
    var id = UUID()
    var employeeID: UUID
    var employeeName: String
    var date: Date
    var startTime: Date
    var endTime: Date
    var notes: String = ""

    var duration: String {
        let secs = max(0, Int(endTime.timeIntervalSince(startTime)))
        let h = secs / 3600; let m = (secs % 3600) / 60
        return h > 0 ? "\(h)ч \(m)м" : "\(m)м"
    }
}

enum OrderStatus: String, Codable, CaseIterable {
    case new     = "Новые"
    case cooking = "Готовится"
    case ready   = "Готово"

    var next: OrderStatus? {
        switch self {
        case .new:     return .cooking
        case .cooking: return .ready
        case .ready:   return nil
        }
    }

    var color: Color {
        switch self {
        case .new:     return .blue
        case .cooking: return .orange
        case .ready:   return .green
        }
    }

    var icon: String {
        switch self {
        case .new:     return "clock"
        case .cooking: return "flame.fill"
        case .ready:   return "checkmark.circle.fill"
        }
    }

    var actionLabel: String {
        switch self {
        case .new:     return "В готовку"
        case .cooking: return "Готово!"
        case .ready:   return ""
        }
    }
}

struct KitchenOrder: Identifiable, Codable {
    var id              = UUID()
    var dishName: String
    var portions: Int
    var tableNumber: String = ""
    var note: String        = ""
    var status: OrderStatus = .new
    var createdAt: Date     = Date()
    var cookingStartedAt: Date? = nil
    var readyAt: Date?          = nil
}

struct TemperatureLog: Identifiable, Codable {
    var id = UUID()
    var location: String
    var temperature: Double  // Celsius
    var recordedAt: Date = Date()
    var recordedBy: String = ""
    var notes: String = ""

    var isOk: Bool {
        // Fridge: 0..+8; Freezer: -25..-15; anything in range
        temperature >= -25 && temperature <= 8
    }
    var isCritical: Bool {
        temperature > 8 || temperature < -25
    }
    var statusLabel: String {
        isCritical ? "⚠ Нарушение" : isOk ? "✓ Норма" : "В норме"
    }
    var statusColor: Color {
        isCritical ? .red : .green
    }
}

enum AppLanguage: String, Codable, CaseIterable {
    case russian = "Русский"
    case english = "English"
}

struct AppBackup: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var restaurantName: String
    var dishes: [Dish]
    var inventoryItems: [InventoryItem]
    var deliveries: [Delivery]
    var writeOffs: [WriteOff]
    var productions: [Production]
    var employees: [Employee]
    var suppliers: [Supplier]
    var sales: [Sale]
    var checklists: [ChecklistItem]
    var menuCollections: [MenuCollection]
    var workSchedule: [WorkShift]
    var temperatureLogs: [TemperatureLog]
    var shiftHistory: [Shift]
    var stockMovements: [StockMovement] = []
}

struct RecipeVersion: Identifiable, Codable {
    var id = UUID()
    var dishID: UUID
    var dishName: String
    var savedAt: Date = Date()
    var savedBy: String
    var ingredients: [RecipeIngredient]
    var steps: [CookingStep]
    var salePrice: Double
    var cookTime: Int
    var notes: String = ""
}
