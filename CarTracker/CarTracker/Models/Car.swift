import Foundation

let popularCarBrands: [String] = [
    "Audi", "BMW", "Chery", "Chevrolet", "Ford",
    "Geely", "Honda", "Hyundai", "Kia", "Lada",
    "Land Rover", "Lexus", "Mazda", "Mercedes-Benz",
    "Mitsubishi", "Nissan", "Porsche", "Renault",
    "Skoda", "Subaru", "Toyota", "Volkswagen", "Volvo"
]

struct Car: Identifiable, Codable {
    var id: UUID = UUID()
    var brand: String
    var model: String
    var year: Int
    var licensePlate: String
    var colorHex: String

    var displayName: String {
        "\(brand) \(model)"
    }
}
