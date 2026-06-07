import Foundation
import Combine

class ExpenseViewModel: ObservableObject {
    @Published var cars: [Car] = []
    @Published var expenses: [CarExpense] = []
    @Published var selectedCarId: UUID?

    private let carsKey = "saved_cars"
    private let expensesKey = "saved_expenses"
    private let selectedCarKey = "selected_car_id"

    init() {
        loadData()
    }

    // MARK: - Computed

    var selectedCar: Car? {
        cars.first { $0.id == selectedCarId }
    }

    var currentCarExpenses: [CarExpense] {
        guard let id = selectedCarId else { return [] }
        return expenses
            .filter { $0.carId == id }
            .sorted { $0.date > $1.date }
    }

    var totalFuel: Double {
        currentCarExpenses
            .filter { $0.category == .fuel }
            .reduce(0) { $0 + $1.amount }
    }

    var totalService: Double {
        currentCarExpenses
            .filter { $0.category == .service }
            .reduce(0) { $0 + $1.amount }
    }

    var totalOther: Double {
        currentCarExpenses
            .filter { $0.category == .other }
            .reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Double {
        totalFuel + totalService + totalOther
    }

    /// Средний расход топлива л/100 км (только полные баки)
    var averageFuelConsumption: Double? {
        let fullFills = currentCarExpenses
            .filter { $0.category == .fuel && $0.liters != nil && $0.tankFillType == .full }
            .sorted { $0.mileage < $1.mileage }

        guard fullFills.count >= 2 else { return nil }

        // Суммируем литры начиная со второй заправки (первая — точка отсчёта)
        let totalLiters = fullFills.dropFirst().reduce(0) { $0 + ($1.liters ?? 0) }
        let distance = fullFills.last!.mileage - fullFills.first!.mileage

        guard distance > 0 else { return nil }
        return (totalLiters / Double(distance)) * 100
    }

    var lastMileage: Int {
        currentCarExpenses.map { $0.mileage }.max() ?? 0
    }

    // MARK: - Actions

    func addCar(_ car: Car) {
        cars.append(car)
        if selectedCarId == nil { selectedCarId = car.id }
        saveData()
    }

    func deleteCar(at offsets: IndexSet) {
        let removed = offsets.map { cars[$0].id }
        cars.remove(atOffsets: offsets)
        expenses.removeAll { removed.contains($0.carId) }
        if let removed = removed.first, selectedCarId == removed {
            selectedCarId = cars.first?.id
        }
        saveData()
    }

    func selectCar(_ car: Car) {
        selectedCarId = car.id
        saveData()
    }

    func addExpense(_ expense: CarExpense) {
        expenses.append(expense)
        saveData()
    }

    func deleteExpense(at offsets: IndexSet) {
        let sorted = currentCarExpenses
        let ids = offsets.map { sorted[$0].id }
        expenses.removeAll { ids.contains($0.id) }
        saveData()
    }

    // MARK: - Persistence

    private func saveData() {
        if let data = try? JSONEncoder().encode(cars) {
            UserDefaults.standard.set(data, forKey: carsKey)
        }
        if let data = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(data, forKey: expensesKey)
        }
        if let id = selectedCarId {
            UserDefaults.standard.set(id.uuidString, forKey: selectedCarKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: carsKey),
           let decoded = try? JSONDecoder().decode([Car].self, from: data) {
            cars = decoded
        }
        if let data = UserDefaults.standard.data(forKey: expensesKey),
           let decoded = try? JSONDecoder().decode([CarExpense].self, from: data) {
            expenses = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: selectedCarKey),
           let id = UUID(uuidString: idString) {
            selectedCarId = id
        } else {
            selectedCarId = cars.first?.id
        }
    }
}
