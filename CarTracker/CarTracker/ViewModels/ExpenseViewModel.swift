import Foundation
import Combine

class ExpenseViewModel: ObservableObject {
    @Published var cars: [Car] = []
    @Published var expenses: [CarExpense] = []
    @Published var maintenanceItems: [MaintenanceItem] = []
    @Published var selectedCarId: UUID?

    private let carsKey        = "saved_cars"
    private let expensesKey    = "saved_expenses"
    private let selectedCarKey = "selected_car_id"
    private let maintenanceKey = "saved_maintenance"

    init() { loadData() }

    // MARK: - Selected car

    var selectedCar: Car? { cars.first { $0.id == selectedCarId } }

    var currentCarExpenses: [CarExpense] {
        guard let id = selectedCarId else { return [] }
        return expenses.filter { $0.carId == id }.sorted { $0.date > $1.date }
    }

    var currentMaintenanceItems: [MaintenanceItem] {
        guard let id = selectedCarId else { return [] }
        return maintenanceItems.filter { $0.carId == id }
    }

    // MARK: - Totals

    var totalFuel: Double    { currentCarExpenses.filter { $0.category == .fuel }.reduce(0)    { $0 + $1.amount } }
    var totalService: Double { currentCarExpenses.filter { $0.category == .service }.reduce(0) { $0 + $1.amount } }
    var totalOther: Double   { currentCarExpenses.filter { $0.category == .other }.reduce(0)   { $0 + $1.amount } }
    var totalExpenses: Double { totalFuel + totalService + totalOther }

    // MARK: - Fuel consumption

    /// Средний расход л/100 км. Учитывает остаток в баке.
    var averageFuelConsumption: Double? {
        let fills = currentCarExpenses
            .filter { $0.category == .fuel && $0.liters != nil }
            .sorted { $0.mileage < $1.mileage }
        guard fills.count >= 2 else { return nil }

        var totalConsumed = 0.0
        var totalDistance = 0
        for i in 0..<fills.count - 1 {
            let cur  = fills[i], nxt = fills[i+1]
            let consumed = (cur.liters ?? 0) + (cur.remainingLiters ?? 0) - (nxt.remainingLiters ?? 0)
            let dist = nxt.mileage - cur.mileage
            guard consumed > 0, dist > 0 else { continue }
            totalConsumed += consumed
            totalDistance += dist
        }
        guard totalDistance > 0 else { return nil }
        return (totalConsumed / Double(totalDistance)) * 100
    }

    /// История расхода топлива по заправкам (для графика)
    var consumptionHistory: [(date: Date, consumption: Double)] {
        let fills = currentCarExpenses
            .filter { $0.category == .fuel && $0.liters != nil }
            .sorted { $0.mileage < $1.mileage }
        guard fills.count >= 2 else { return [] }

        var result: [(Date, Double)] = []
        for i in 0..<fills.count - 1 {
            let cur = fills[i], nxt = fills[i+1]
            let consumed = (cur.liters ?? 0) + (cur.remainingLiters ?? 0) - (nxt.remainingLiters ?? 0)
            let dist = nxt.mileage - cur.mileage
            guard consumed > 0, dist > 0 else { continue }
            result.append((nxt.date, (consumed / Double(dist)) * 100))
        }
        return result
    }

    /// Стоимость 1 км (все расходы / пройденное расстояние)
    var costPerKm: Double? {
        let fills = currentCarExpenses
            .filter { $0.category == .fuel }
            .sorted { $0.mileage < $1.mileage }
        guard let first = fills.last, let last = fills.first else { return nil }
        let distance = last.mileage - first.mileage
        guard distance > 0 else { return nil }
        return totalExpenses / Double(distance)
    }

    var lastMileage: Int { currentCarExpenses.map { $0.mileage }.max() ?? 0 }

    // MARK: - Expense CRUD

    func addExpense(_ expense: CarExpense)   { expenses.append(expense); saveData() }

    func deleteExpense(at offsets: IndexSet) {
        let ids = offsets.map { currentCarExpenses[$0].id }
        expenses.removeAll { ids.contains($0.id) }
        saveData()
    }

    func updateExpense(_ updated: CarExpense) {
        if let idx = expenses.firstIndex(where: { $0.id == updated.id }) {
            expenses[idx] = updated; saveData()
        }
    }

    // MARK: - Car CRUD

    func addCar(_ car: Car) {
        cars.append(car)
        if selectedCarId == nil { selectedCarId = car.id }
        saveData()
    }

    func deleteCar(at offsets: IndexSet) {
        let removed = offsets.map { cars[$0].id }
        cars.remove(atOffsets: offsets)
        expenses.removeAll { removed.contains($0.carId) }
        maintenanceItems.removeAll { removed.contains($0.carId) }
        if let r = removed.first, selectedCarId == r { selectedCarId = cars.first?.id }
        saveData()
    }

    func selectCar(_ car: Car) { selectedCarId = car.id; saveData() }

    // MARK: - Maintenance CRUD

    func addMaintenance(_ item: MaintenanceItem)    { maintenanceItems.append(item); saveData() }

    func updateMaintenance(_ updated: MaintenanceItem) {
        if let idx = maintenanceItems.firstIndex(where: { $0.id == updated.id }) {
            maintenanceItems[idx] = updated; saveData()
        }
    }

    func deleteMaintenance(at offsets: IndexSet) {
        let ids = offsets.map { currentMaintenanceItems[$0].id }
        maintenanceItems.removeAll { ids.contains($0.id) }
        saveData()
    }

    // MARK: - Persistence

    private func saveData() {
        if let d = try? JSONEncoder().encode(cars)             { UserDefaults.standard.set(d, forKey: carsKey) }
        if let d = try? JSONEncoder().encode(expenses)         { UserDefaults.standard.set(d, forKey: expensesKey) }
        if let d = try? JSONEncoder().encode(maintenanceItems) { UserDefaults.standard.set(d, forKey: maintenanceKey) }
        if let id = selectedCarId { UserDefaults.standard.set(id.uuidString, forKey: selectedCarKey) }
    }

    private func loadData() {
        if let d = UserDefaults.standard.data(forKey: carsKey),
           let v = try? JSONDecoder().decode([Car].self, from: d) { cars = v }
        if let d = UserDefaults.standard.data(forKey: expensesKey),
           let v = try? JSONDecoder().decode([CarExpense].self, from: d) { expenses = v }
        if let d = UserDefaults.standard.data(forKey: maintenanceKey),
           let v = try? JSONDecoder().decode([MaintenanceItem].self, from: d) { maintenanceItems = v }
        if let s = UserDefaults.standard.string(forKey: selectedCarKey),
           let id = UUID(uuidString: s) { selectedCarId = id }
        else { selectedCarId = cars.first?.id }
    }
}
