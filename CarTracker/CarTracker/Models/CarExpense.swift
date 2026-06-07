import Foundation

enum ExpenseCategory: String, Codable, CaseIterable {
    case fuel = "Топливо"
    case service = "Сервис"
    case other = "Прочее"

    var icon: String {
        switch self {
        case .fuel: return "fuelpump.fill"
        case .service: return "wrench.and.screwdriver.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .fuel: return "FuelColor"
        case .service: return "ServiceColor"
        case .other: return "OtherColor"
        }
    }
}

enum TankFillType: String, Codable {
    case full = "Полный бак"
    case partial = "Есть остаток"
}

struct CarExpense: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var category: ExpenseCategory
    var amount: Double
    var mileage: Int
    var liters: Double?
    var pricePerLiter: Double?
    var tankFillType: TankFillType?  // только для топлива
    var note: String
    var carId: UUID
}
