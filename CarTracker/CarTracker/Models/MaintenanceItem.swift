import Foundation

enum MaintenanceIntervalType: String, Codable, CaseIterable {
    case mileage = "По пробегу"
    case date    = "По дате"
    case both    = "По пробегу и дате"
}

struct MaintenanceItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var intervalKm: Int?
    var intervalDays: Int?
    var lastServiceMileage: Int?
    var lastServiceDate: Date?
    var carId: UUID
    var note: String = ""

    var nextServiceMileage: Int? {
        guard let last = lastServiceMileage, let interval = intervalKm else { return nil }
        return last + interval
    }

    var nextServiceDate: Date? {
        guard let last = lastServiceDate, let days = intervalDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: last)
    }

    func remainingKm(currentMileage: Int) -> Int? {
        guard let next = nextServiceMileage else { return nil }
        return next - currentMileage
    }

    func isOverdue(currentMileage: Int) -> Bool {
        let kmOverdue = remainingKm(currentMileage: currentMileage).map { $0 < 0 } ?? false
        let dateOverdue = nextServiceDate.map { $0 < Date() } ?? false
        return kmOverdue || dateOverdue
    }

    func urgencyLevel(currentMileage: Int) -> UrgencyLevel {
        if isOverdue(currentMileage: currentMileage) { return .overdue }
        if let rem = remainingKm(currentMileage: currentMileage), rem < 500 { return .soon }
        if let next = nextServiceDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 999
            if days < 14 { return .soon }
        }
        return .ok
    }
}

enum UrgencyLevel {
    case ok, soon, overdue

    var color: String {
        switch self {
        case .ok:      return "green"
        case .soon:    return "orange"
        case .overdue: return "red"
        }
    }
}

let defaultMaintenanceTemplates: [(title: String, icon: String, km: Int, days: Int)] = [
    ("Замена масла",        "drop.fill",              10000, 365),
    ("Замена фильтра",      "aqi.medium",              10000, 365),
    ("Замена резины",       "circle.circle",           0,    180),
    ("Тормозные колодки",   "car.rear.and.tire.marks", 30000, 730),
    ("Техосмотр",           "doc.badge.checkmark",     0,    365),
    ("Замена свечей",       "bolt.fill",               30000, 730),
    ("Антифриз",            "thermometer.medium",      60000, 1095),
]
