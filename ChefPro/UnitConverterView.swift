import SwiftUI

// MARK: - Unit Converter

struct UnitConverterView: View {
    @State private var inputText = ""
    @State private var selectedUnit = "г"

    private let units = ["г", "кг", "мл", "л", "шт", "уп", "ст.л", "ч.л"]

    private var result: String {
        guard let qty = Double(inputText.replacingOccurrences(of: ",", with: ".")) else { return "" }
        let (normQty, normUnit) = normaliseUnit(quantity: qty, unit: selectedUnit)
        if normUnit == selectedUnit {
            return "Конвертация не требуется"
        }
        let formatted = normQty.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", normQty) : String(format: "%.3g", normQty)
        return "\(inputText) \(selectedUnit) = \(formatted) \(normUnit)"
    }

    var body: some View {
        Form {
            Section("Введите значение") {
                TextField("Количество", text: $inputText)
                    .keyboardType(.decimalPad)

                Picker("Единица измерения", selection: $selectedUnit) {
                    ForEach(units, id: \.self) { Text($0) }
                }
            }

            if !inputText.isEmpty {
                Section("Результат") {
                    Text(result)
                        .font(.headline)
                        .foregroundStyle(.chefAccent)
                }
            }

            Section("Правила конвертации") {
                Label("1000 г → 1 кг", systemImage: "arrow.right")
                    .font(.subheadline).foregroundStyle(.secondary)
                Label("1000 мл → 1 л", systemImage: "arrow.right")
                    .font(.subheadline).foregroundStyle(.secondary)
                Label("кг, л, шт — без изменений", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Конвертер единиц")
        .navigationBarTitleDisplayMode(.large)
    }
}
