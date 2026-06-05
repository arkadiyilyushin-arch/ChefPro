import SwiftUI

// MARK: - Global Search

struct GlobalSearchView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var query = ""
    @FocusState private var focused: Bool

    // MARK: Result types

    private struct DishResult: Identifiable {
        let id: UUID
        let dish: Dish
        let cost: Double
        let fcPct: Double
    }
    private struct InventoryResult: Identifiable {
        let id: UUID
        let item: InventoryItem
    }
    private struct SupplierResult: Identifiable {
        let id: UUID
        let supplier: Supplier
    }
    private struct EmployeeResult: Identifiable {
        let id: UUID
        let employee: Employee
    }

    // MARK: Filtered results

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var dishResults: [DishResult] {
        guard !trimmed.isEmpty else { return [] }
        return store.dishes.filter { d in
            d.name.localizedCaseInsensitiveContains(trimmed) ||
            d.category.localizedCaseInsensitiveContains(trimmed) ||
            d.ingredients.contains { $0.productName.localizedCaseInsensitiveContains(trimmed) }
        }.map { d in
            DishResult(id: d.id, dish: d,
                       cost: store.calculateDishCost(d),
                       fcPct: store.foodCostPercent(d))
        }
    }

    private var inventoryResults: [InventoryResult] {
        guard !trimmed.isEmpty else { return [] }
        return store.inventoryItems.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.category.localizedCaseInsensitiveContains(trimmed)
        }.map { InventoryResult(id: $0.id, item: $0) }
    }

    private var supplierResults: [SupplierResult] {
        guard !trimmed.isEmpty else { return [] }
        return store.suppliers.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.phone.localizedCaseInsensitiveContains(trimmed)
        }.map { SupplierResult(id: $0.id, supplier: $0) }
    }

    private var employeeResults: [EmployeeResult] {
        guard !trimmed.isEmpty else { return [] }
        return store.employees.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.position.localizedCaseInsensitiveContains(trimmed)
        }.map { EmployeeResult(id: $0.id, employee: $0) }
    }

    private var hasResults: Bool {
        !dishResults.isEmpty || !inventoryResults.isEmpty ||
        !supplierResults.isEmpty || !employeeResults.isEmpty
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16, weight: .medium))
                    TextField("Блюда, склад, сотрудники, поставщики…", text: $query)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

                if trimmed.isEmpty {
                    emptyPrompt
                } else if !hasResults {
                    noResults
                } else {
                    resultsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { focused = true }
        }
    }

    // MARK: - Empty / no-results

    private var emptyPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.4))
            VStack(spacing: 6) {
                Text("Глобальный поиск")
                    .font(.title3.bold())
                Text("Ищет по техкартам, складу,\nпоставщикам и сотрудникам")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("Ничего не найдено")
                .font(.title3.bold())
            Text("Попробуй другой запрос")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Results list

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                // Dishes
                if !dishResults.isEmpty {
                    sectionBlock(title: "Техкарты", icon: "book.fill", color: .chefAccent, count: dishResults.count) {
                        ForEach(dishResults) { r in
                            NavigationLink {
                                DishDetailView(dish: r.dish).environmentObject(store)
                            } label: {
                                dishRow(r)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Inventory
                if !inventoryResults.isEmpty {
                    sectionBlock(title: "Склад", icon: "shippingbox.fill", color: .orange, count: inventoryResults.count) {
                        ForEach(inventoryResults) { r in
                            inventoryRow(r)
                        }
                    }
                }

                // Suppliers
                if !supplierResults.isEmpty {
                    sectionBlock(title: "Поставщики", icon: "building.2.fill", color: .blue, count: supplierResults.count) {
                        ForEach(supplierResults) { r in
                            supplierRow(r)
                        }
                    }
                }

                // Employees
                if !employeeResults.isEmpty {
                    sectionBlock(title: "Сотрудники", icon: "person.2.fill", color: .purple, count: employeeResults.count) {
                        ForEach(employeeResults) { r in
                            employeeRow(r)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Section block

    @ViewBuilder
    private func sectionBlock<Content: View>(
        title: String, icon: String, color: Color,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline.bold())
                Text("\(count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(color)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.leading, 14)

            content()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Row views

    private func dishRow(_ r: DishResult) -> some View {
        let fcColor: Color = r.fcPct > store.foodCostThreshold ? .red
                           : r.fcPct > store.foodCostThreshold * 0.85 ? .orange : .chefAccent
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(fcColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "fork.knife")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(fcColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.dish.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(r.dish.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    HStack(spacing: 2) {
                        Image(systemName: "cart.fill").font(.system(size: 9)).foregroundStyle(.blue)
                        Text(String(format: "%.2f", r.cost)).font(.caption.bold())
                    }
                    if r.dish.salePrice > 0 {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: "tag.fill").font(.system(size: 9)).foregroundStyle(.green)
                            Text(String(format: "%.2f", r.dish.salePrice)).font(.caption.bold())
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            Spacer(minLength: 4)
            if r.dish.salePrice > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", r.fcPct))
                        .font(.headline.bold())
                        .foregroundStyle(fcColor)
                    Text("FC").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func inventoryRow(_ r: InventoryResult) -> some View {
        let low = r.item.quantity <= r.item.minQuantity
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill((low ? Color.orange : Color.green).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(low ? .orange : .green)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.item.name).font(.subheadline.bold()).lineLimit(1)
                Text(r.item.category).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f \(r.item.unit)", r.item.quantity))
                    .font(.subheadline.bold())
                    .foregroundStyle(low ? .orange : .primary)
                if low {
                    Text("На исходе").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func supplierRow(_ r: SupplierResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.supplier.name).font(.subheadline.bold()).lineLimit(1)
                if !r.supplier.phone.isEmpty {
                    Text(r.supplier.phone).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func employeeRow(_ r: EmployeeResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.employee.name).font(.subheadline.bold()).lineLimit(1)
                Text(r.employee.position).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
