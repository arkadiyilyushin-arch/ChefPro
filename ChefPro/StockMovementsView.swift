import SwiftUI

struct StockMovementsView: View {
    @EnvironmentObject var store: ChefProStore
    var filterItemName: String? = nil   // if set, show only movements for this item

    @State private var selectedType: StockMovementType? = nil
    @State private var searchText = ""
    @State private var showingLast: Int = 100

    private var filtered: [StockMovement] {
        var list = store.stockMovements.sorted { $0.date > $1.date }
        if let name = filterItemName {
            list = list.filter { $0.itemName.lowercased() == name.lowercased() }
        }
        if let type = selectedType {
            list = list.filter { $0.type == type }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.itemName.localizedCaseInsensitiveContains(searchText) ||
                $0.note.localizedCaseInsensitiveContains(searchText)
            }
        }
        return Array(list.prefix(showingLast))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Все", isSelected: selectedType == nil) {
                            selectedType = nil
                        }
                        ForEach(StockMovementType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.rawValue,
                                icon: type.icon,
                                color: type.color,
                                isSelected: selectedType == type
                            ) { selectedType = selectedType == type ? nil : type }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                Divider()

                if filtered.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", title: "Нет движений", subtitle: "Операции со складом появятся здесь")
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered) { movement in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(movement.type.color.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: movement.type.icon)
                                        .foregroundStyle(movement.type.color)
                                        .font(.system(size: 16))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(movement.itemName).font(.headline)
                                    if !movement.note.isEmpty {
                                        Text(movement.note).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(movement.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Text("\(movement.type.sign)\(String(format: "%.2f", movement.quantity)) \(movement.unit)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(movement.type == .delivery ? .green : .red)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        if store.stockMovements.count > showingLast {
                            Button("Показать ещё") { showingLast += 100 }
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Поиск по товару")
                }
            }
            .background(Color.chefBackground)
            .navigationTitle(filterItemName ?? "История движений")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
