import SwiftUI
import CoreImage.CIFilterBuiltins

struct DigitalMenuView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showShareSheet = false
    @State private var pdfURL: URL? = nil
    @State private var selectedCategory = "Все"

    private var activeMenuDishes: [Dish] {
        store.dishes.filter { $0.menuStatus != .removed && $0.dishType == .dish }
    }

    private var categories: [String] {
        ["Все"] + Array(Set(activeMenuDishes.map { $0.category })).sorted()
    }

    private var filteredDishes: [Dish] {
        selectedCategory == "Все"
            ? activeMenuDishes
            : activeMenuDishes.filter { $0.category == selectedCategory }
    }

    private var groupedDishes: [(String, [Dish])] {
        if selectedCategory != "Все" {
            return [(selectedCategory, filteredDishes)]
        }
        let cats = Array(Set(activeMenuDishes.map { $0.category })).sorted()
        return cats.map { cat in (cat, activeMenuDishes.filter { $0.category == cat }) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Text(cat)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(selectedCategory == cat ? Color.chefAccent : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedCategory == cat ? .white : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                }
                Divider()

                List {
                    ForEach(groupedDishes, id: \.0) { category, dishes in
                        Section(category) {
                            ForEach(dishes) { dish in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(dish.name).font(.headline)
                                            if dish.menuStatus == .seasonal {
                                                Image(systemName: "leaf.fill").font(.caption).foregroundStyle(.orange)
                                            }
                                        }
                                        if !dish.allergens.isEmpty {
                                            Text(dish.allergens.joined(separator: " · "))
                                                .font(.caption2).foregroundStyle(.orange)
                                        }
                                        HStack(spacing: 8) {
                                            if dish.portionWeight > 0 {
                                                Text("\(Int(dish.portionWeight)) \(dish.portionWeightUnit)")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            if dish.calories > 0 {
                                                Text("\(Int(dish.calories)) ккал")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Text("\(Int(dish.salePrice)) ₽")
                                        .font(.title3.bold())
                                        .foregroundStyle(.chefAccent)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Color.chefBackground)
            .navigationTitle("Меню")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        pdfURL = PDFReportGenerator.createMenuPDF(store: store)
                        if pdfURL != nil { showShareSheet = true }
                    } label: {
                        Label("Экспорт PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}
