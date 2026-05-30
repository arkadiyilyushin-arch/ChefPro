import SwiftUI

// MARK: - Reusable inventory-product autocomplete rows
// Usage: drop inside any Form/List Section after the product TextField.
//
//   Section("Продукт") {
//       TextField("Название", text: $name)
//           .onChange(of: name) { _, _ in showSuggestions = !inventorySuggestions.isEmpty }
//       InventoryProductSuggestions(
//           query: name,
//           show: $showSuggestions
//       ) { item in
//           name     = item.name
//           unit     = item.unit
//           category = item.category
//       }
//   }

struct InventoryProductSuggestions: View {
    @EnvironmentObject var store: ChefProStore

    let query:    String
    @Binding var show: Bool
    /// Called when the user taps a suggestion row
    var onSelect: (InventoryItem) -> Void

    private var suggestions: [InventoryItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return store.inventoryItems
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name < $1.name }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        if show && !suggestions.isEmpty {
            ForEach(suggestions) { item in
                Button {
                    onSelect(item)
                    show = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(.chefAccent)
                            .font(.caption)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                            HStack(spacing: 6) {
                                Text(item.category)
                                Text("·")
                                Text("\(item.quantity, specifier: "%.1f") \(item.unit)")
                                if item.pricePerUnit > 0 {
                                    Text("·")
                                    Text("\(item.pricePerUnit, specifier: "%.2f") ₽/\(item.unit)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
