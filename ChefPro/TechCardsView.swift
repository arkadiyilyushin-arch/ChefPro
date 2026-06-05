import SwiftUI
import PhotosUI
import UIKit

// MARK: - Dish Sort Order

enum DishSortOrder: String, CaseIterable {
    case name     = "Название"
    case foodCost = "Себестоимость"
}

// MARK: - Tech Cards

struct DishRowCard: View {
    let dish: Dish
    let cost: Double
    let foodCostPct: Double
    var threshold: Double = 35

    private var fcColor: Color {
        foodCostPct > threshold ? .red : foodCostPct > threshold * 0.85 ? .orange : .chefAccent
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(fcColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "fork.knife")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(fcColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(dish.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .foregroundStyle(dish.menuStatus == .removed ? Color.secondary : Color.primary)
                    if dish.isFavorite {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    }
                    if dish.isStopListed {
                        Text("СТОП").font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.red.opacity(0.15)).foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    if dish.isGoListed {
                        Text("ГОУ").font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.green.opacity(0.15)).foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                Text(dish.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                // Cost · Price · Portion weight
                HStack(spacing: 6) {
                    // Себестоимость
                    HStack(spacing: 2) {
                        Image(systemName: "cart.fill").font(.system(size: 9)).foregroundStyle(.blue)
                        Text(String(format: "%.2f", cost)).font(.caption.bold()).foregroundStyle(.primary)
                    }
                    if dish.salePrice > 0 {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        // Цена продажи
                        HStack(spacing: 2) {
                            Image(systemName: "tag.fill").font(.system(size: 9)).foregroundStyle(.green)
                            Text(String(format: "%.2f", dish.salePrice)).font(.caption.bold()).foregroundStyle(.primary)
                        }
                    }
                    if dish.portionWeight > 0 {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        // Выход
                        HStack(spacing: 2) {
                            Image(systemName: "scalemass.fill").font(.system(size: 9)).foregroundStyle(.orange)
                            Text("\(dish.portionWeight, specifier: "%.0f") \(dish.portionWeightUnit)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            if dish.dishType != .semifinished && dish.salePrice > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(foodCostPct, specifier: "%.0f")%")
                        .font(.headline.bold())
                        .foregroundStyle(fcColor)
                    Text("FC").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct TechCardsView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAddDish = false
    @State private var showScanner = false
    @State private var selectedCategory = "Все"
    @State private var selectedStatus: DishMenuStatus? = nil
    @State private var dishSortOrder: DishSortOrder = .name
    @State private var selectedType: DishType = .dish

    var categories: [String] {
        ["Все"] + store.dishCategories
    }

    var filteredDishes: [Dish] {
        var base = store.dishes.filter { dish in
            let matchesCategory = selectedCategory == "Все" || dish.category == selectedCategory
            let matchesStatus = selectedStatus == nil || dish.menuStatus == selectedStatus
            let matchesType = dish.dishType == selectedType
            return matchesCategory && matchesStatus && matchesType
        }
        // Favorites first unless sorted otherwise
        switch dishSortOrder {
        case .name:
            base.sort { $0.name < $1.name }
        case .foodCost:
            base.sort { store.calculateDishCost($0) < store.calculateDishCost($1) }
        }
        return base.sorted { $0.isFavorite && !$1.isFavorite }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Combined filter chips: type | category | status
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DishType.allCases, id: \.self) { t in
                            Button { selectedType = t } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: t.icon)
                                    Text(t.rawValue)
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(selectedType == t ? Color.chefAccent : Color(.systemGray5))
                                .foregroundStyle(selectedType == t ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                        Rectangle().fill(Color(.separator)).frame(width: 1, height: 22)
                        ForEach(categories, id: \.self) { cat in
                            Button { selectedCategory = cat } label: {
                                Text(cat)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(selectedCategory == cat ? Color.chefAccent : Color(.systemGray5))
                                    .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                        Rectangle().fill(Color(.separator)).frame(width: 1, height: 22)
                        ForEach(DishMenuStatus.allCases, id: \.self) { status in
                            Button {
                                selectedStatus = selectedStatus == status ? nil : status
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: status.icon)
                                    Text(status.rawValue)
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(selectedStatus == status ? status.color : Color(.systemGray5))
                                .foregroundStyle(selectedStatus == status ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

                if filteredDishes.isEmpty {
                    if store.dishes.isEmpty {
                        EmptyStateView(
                            icon: "fork.knife",
                            title: "Нет техкарт",
                            subtitle: "Добавьте первое блюдо чтобы начать",
                            actionTitle: "Добавить блюдо",
                            action: { showAddDish = true }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyStateView(icon: "book.closed", title: "Ничего не найдено", subtitle: "Попробуй изменить поиск или категорию.")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List {
                        ForEach(filteredDishes) { dish in
                            NavigationLink {
                                DishDetailView(dish: dish)
                                    .environmentObject(store)
                            } label: {
                                DishRowCard(
                                    dish: dish,
                                    cost: store.calculateDishCost(dish),
                                    foodCostPct: store.foodCostPercent(dish),
                                    threshold: store.foodCostThreshold
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading) {
                                Button {
                                    if let url = PDFReportGenerator.createTechCardPDF(dish: dish, store: store) {
                                        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let root = scene.windows.first?.rootViewController {
                                            root.present(av, animated: true)
                                        }
                                    }
                                } label: { Label("Поделиться", systemImage: "square.and.arrow.up") }
                                    .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    let deletedDish = dish
                                    store.deleteDish(dish)
                                    withAnimation {
                                        store.undoItem = UndoableItem(
                                            type: .dish,
                                            description: deletedDish.name
                                        ) {
                                            store.dishes.append(deletedDish)
                                        }
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                        if store.undoItem?.description == deletedDish.name {
                                            withAnimation { store.undoItem = nil }
                                        }
                                    }
                                } label: { Label("Удалить", systemImage: "trash") }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.chefBackground)
                }
            }
            .background(Color.chefBackground)
            .navigationTitle("Техкарты")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(DishSortOrder.allCases, id: \.self) { order in
                            Button {
                                dishSortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if dishSortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Сортировка", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "text.viewfinder")
                                .font(.title3)
                        }
                        Button { showAddDish = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddDish) {
                AddDishView { store.addDish($0) }
                    .environmentObject(store)
            }
            .sheet(isPresented: $showScanner) {
                TechCardScannerView { dish in
                    store.addDish(dish)
                    showScanner = false
                }
                .environmentObject(store)
            }
        }
    }
}

struct DishDetailView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss

    let dish: Dish
    @State private var showEdit = false
    @State private var showDeleteAlert = false
    @State private var showProduce = false
    @State private var showScaling = false
    @State private var showShareSheet = false
    @State private var pdfURL: URL? = nil
    @State private var showCookingMode = false
    @State private var showVersions = false
    @State private var showQRCode = false

    var currentDish: Dish {
        store.dishes.first(where: { $0.id == dish.id }) ?? dish
    }

    private var dishStillExists: Bool {
        store.dishes.contains(where: { $0.id == dish.id })
    }

    private func printTechCard() {
        guard let pdfURL = PDFReportGenerator.createTechCardPDF(dish: currentDish, store: store) else { return }
        guard let pdfData = try? Data(contentsOf: pdfURL) else { return }

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = currentDish.name
        printInfo.outputType = .general

        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = pdfData
        controller.present(animated: true)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Hero header ───────────────────────────────────
                dishHero

                VStack(alignment: .leading, spacing: 14) {
                    // ── Stat chips ────────────────────────────────
                    statChips

                    // ── Status tags ───────────────────────────────
                    statusTags

                    // ── Missing ingredients warning ───────────────
                    let missing = store.unmatchedIngredients(for: currentDish)
                    if !missing.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Себестоимость занижена").font(.caption.bold()).foregroundStyle(.orange)
                                Text(missing.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // ── Nutrients ─────────────────────────────────
                    if currentDish.calories > 0 || currentDish.proteins > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Нутриенты", systemImage: "flame.fill")
                                .font(.subheadline.bold()).foregroundStyle(.secondary)
                            HStack(spacing: 0) {
                                NutrientCell(value: currentDish.calories, unit: "ккал", label: "Калории", color: .orange)
                                Divider()
                                NutrientCell(value: currentDish.proteins, unit: "г", label: "Белки", color: .blue)
                                Divider()
                                NutrientCell(value: currentDish.fats, unit: "г", label: "Жиры", color: .yellow)
                                Divider()
                                NutrientCell(value: currentDish.carbs, unit: "г", label: "Углев.", color: .green)
                            }
                            .frame(height: 56)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // ── Ingredients ───────────────────────────────
                    dishSectionHeader("Ингредиенты", count: currentDish.ingredients.count)
                    if currentDish.ingredients.isEmpty {
                        Text("Не добавлены").font(.subheadline).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(currentDish.ingredients.enumerated()), id: \.element.id) { idx, ingredient in
                                HStack(spacing: 10) {
                                    Text(ingredient.productName)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text("\(ingredient.quantity, specifier: "%.1f") \(ingredient.unit)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let item = store.inventoryItems.first(where: {
                                        $0.name.lowercased() == ingredient.productName.lowercased()
                                    }) {
                                        let cost = store.convert(quantity: ingredient.quantity, from: ingredient.unit, to: item.unit) * item.pricePerUnit
                                        Text(String(format: "%.2f", cost))
                                            .font(.caption.bold())
                                            .foregroundStyle(.chefAccent)
                                            .frame(minWidth: 48, alignment: .trailing)
                                    } else {
                                        Text("нет")
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                            .frame(minWidth: 48, alignment: .trailing)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                if idx < currentDish.ingredients.count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // ── Steps ─────────────────────────────────────
                    if !currentDish.steps.isEmpty {
                        dishSectionHeader("Приготовление", count: currentDish.steps.count)
                        VStack(spacing: 0) {
                            ForEach(Array(currentDish.steps.enumerated()), id: \.element.id) { idx, step in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top, spacing: 10) {
                                        ZStack {
                                            Circle().fill(Color.chefAccent).frame(width: 26, height: 26)
                                            Text("\(step.stepNumber)").font(.caption.bold()).foregroundStyle(.white)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(step.instruction).font(.subheadline)
                                            if step.durationMinutes > 0 {
                                                Label("\(step.durationMinutes) мин", systemImage: "timer")
                                                    .font(.caption2).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    if !step.tip.isEmpty {
                                        HStack(spacing: 5) {
                                            Image(systemName: "lightbulb.fill").font(.caption2).foregroundStyle(.orange)
                                            Text(step.tip).font(.caption).foregroundStyle(.orange)
                                        }
                                        .padding(.leading, 36)
                                    }
                                    if let img = store.loadStepPhoto(for: step) {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(maxWidth: .infinity).frame(height: 140)
                                            .clipped().cornerRadius(10)
                                            .padding(.leading, 36)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                if idx < currentDish.steps.count - 1 {
                                    Divider().padding(.leading, 50)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // ── Price history ──────────────────────────────
                    let priceHistory = currentDish.ingredients.compactMap { ing -> (name: String, prev: Double, curr: Double, date: Date)? in
                        guard let item = store.inventoryItems.first(where: { $0.name.lowercased() == ing.productName.lowercased() }),
                              item.priceHistory.count >= 2 else { return nil }
                        let sorted = item.priceHistory.sorted { $0.date < $1.date }
                        let prev = sorted[sorted.count - 2], curr = sorted[sorted.count - 1]
                        return (ing.productName, prev.price, curr.price, curr.date)
                    }
                    if !priceHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Динамика цен", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.subheadline.bold()).foregroundStyle(.secondary)
                            VStack(spacing: 0) {
                                ForEach(Array(priceHistory.prefix(4).enumerated()), id: \.offset) { idx, entry in
                                    HStack {
                                        Text(entry.name).font(.caption).lineLimit(1)
                                        Spacer()
                                        Text("\(entry.prev, specifier: "%.2f") → \(entry.curr, specifier: "%.2f")")
                                            .font(.caption.bold())
                                            .foregroundStyle(entry.curr > entry.prev ? .red : .green)
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    if idx < min(priceHistory.count, 4) - 1 { Divider().padding(.leading, 14) }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // ── Actions grid ──────────────────────────────
                    dishSectionHeader("Действия", count: nil)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        DishActionCell(icon: "flame.fill",    label: "Приготовить",  color: .orange) { showProduce = true }
                        DishActionCell(icon: "pencil",        label: "Редактировать", color: .blue)  { showEdit = true }
                        DishActionCell(icon: "arrow.up.left.and.arrow.down.right", label: "Масштаб", color: .teal) { showScaling = true }
                        DishActionCell(icon: "doc.richtext",  label: "PDF",          color: .red)   {
                            if let url = PDFReportGenerator.createTechCardPDF(dish: currentDish, store: store) {
                                pdfURL = url; showShareSheet = true
                            }
                        }
                        DishActionCell(icon: "printer",       label: "Печать",       color: .gray)  { printTechCard() }
                        DishActionCell(icon: "doc.on.doc",    label: "Дублировать",  color: .purple) {
                            var copy = currentDish; copy.id = UUID()
                            copy.name = currentDish.name + " (копия)"; copy.photoFilename = nil
                            store.dishes.append(copy)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        if !currentDish.steps.isEmpty {
                            DishActionCell(icon: "play.circle.fill", label: "Режим готовки", color: .green) { showCookingMode = true }
                        }
                        DishActionCell(icon: "clock.arrow.circlepath", label: "Версии", color: .indigo) { showVersions = true }
                        DishActionCell(icon: "qrcode",        label: "QR-код",       color: .primary) { showQRCode = true }
                    }

                    // ── Delete ────────────────────────────────────
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить техкарту", systemImage: "trash")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity).frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentDish.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                store.toggleFavorite(currentDish)
            } label: {
                Image(systemName: currentDish.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
        }
        .onChange(of: dishStillExists) { _, exists in
            if !exists { dismiss() }
        }
        .sheet(isPresented: $showEdit) {
            EditDishView(dish: currentDish) { updatedDish in
                store.updateDish(updatedDish)
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showProduce) {
            ProduceDishView(dish: currentDish)
                .environmentObject(store)
        }
        .sheet(isPresented: $showScaling) {
            RecipeScalingView(dish: currentDish)
                .environmentObject(store)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showVersions) {
            NavigationStack {
                RecipeVersionsView(dish: currentDish)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showCookingMode) {
            CookingModeView(dish: currentDish)
                .environmentObject(store)
        }
        .sheet(isPresented: $showQRCode) {
            DishQRCodeView(dish: currentDish)
        }
        .alert("Удалить техкарту?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                store.deleteDish(currentDish)
                dismiss()
            }
        } message: {
            Text("Блюдо будет удалено из техкарт.")
        }
    }

    // MARK: - Hero header

    private var dishHero: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = store.loadDishPhoto(for: currentDish) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color.chefAccent.opacity(0.7), Color.chefAccent.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 52))
                        .foregroundStyle(.white.opacity(0.4))
                )
            }
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center, endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(currentDish.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if currentDish.portionWeight > 0 {
                    Text("\(currentDish.portionWeight, specifier: "%.0f") \(currentDish.portionWeightUnit)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    // MARK: - Stat chips

    private var statChips: some View {
        let cost    = store.calculateDishCost(currentDish)
        let fcPct   = store.foodCostPercent(currentDish)
        let fcColor: Color = fcPct > store.foodCostThreshold ? .red
                           : fcPct > store.foodCostThreshold * 0.85 ? .orange : .chefAccent
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                statChip(icon: "cart.fill",  label: "Себест.", value: String(format: "%.2f", cost), color: .blue)
                if currentDish.salePrice > 0 {
                    statChip(icon: "percent",    label: "FC",      value: String(format: "%.0f%%", fcPct), color: fcColor)
                    statChip(icon: "tag.fill",   label: "Цена",    value: String(format: "%.2f", currentDish.salePrice), color: .green)
                }
                if currentDish.cookTime > 0 {
                    statChip(icon: "timer",      label: "Время",   value: "\(currentDish.cookTime) мин", color: .orange)
                }
                if currentDish.ingredients.count > 0 {
                    statChip(icon: "list.bullet", label: "Ингр.",  value: "\(currentDish.ingredients.count)", color: .purple)
                }
            }
        }
    }

    private func statChip(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2).foregroundStyle(color)
                Text(value).font(.subheadline.bold()).foregroundStyle(.primary)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status tags

    private var statusTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Menu status
                Label(currentDish.menuStatus.rawValue, systemImage: currentDish.menuStatus.icon)
                    .font(.caption.bold())
                    .foregroundStyle(currentDish.menuStatus.color)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(currentDish.menuStatus.color.opacity(0.12))
                    .clipShape(Capsule())

                // Dish type
                Label(currentDish.dishType.rawValue, systemImage: currentDish.dishType.icon)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())

                // Stop / Go
                if currentDish.isStopListed {
                    Text("СТОП").font(.caption.bold())
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                }
                if currentDish.isGoListed {
                    Text("ГОУ").font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }

                // Allergens
                ForEach(currentDish.allergens, id: \.self) { a in
                    Text(a).font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Section header

    private func dishSectionHeader(_ title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            if let count {
                Text("\(count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.chefAccent)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.top, 4)
    }
}

// MARK: - Dish Action Cell

private struct DishActionCell: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QR Code Sheet

struct DishQRCodeView: View {
    let dish: Dish
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false

    private var qrString: String { "chefpro://dish/\(dish.id.uuidString)" }
    private var qrImage: UIImage { generateQRCode(from: qrString) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 260)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 10)

                Text(dish.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Отсканируй камерой iPhone для открытия рецепта")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    showShareSheet = true
                } label: {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.chefAccent)
                .padding(.horizontal, 32)
            }
            .padding(.top, 32)
            .navigationTitle("QR-код")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [qrImage])
            }
        }
    }
}

struct ProduceDishView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss

    let dish: Dish
    @State private var portions = 1
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Блюдо") {
                    Text(dish.name)
                    Stepper("Порций: \(portions)", value: $portions, in: 1...100)
                    Text("Себестоимость: \(store.calculateDishCost(dish) * Double(portions), specifier: "%.2f")")
                }

                Section("Будет списано") {
                    ForEach(dish.ingredients) { ingredient in
                        HStack {
                            Text(ingredient.productName)
                            Spacer()
                            Text("\(ingredient.quantity * Double(portions), specifier: "%.1f") \(ingredient.unit)")
                        }
                    }
                }

                if showError {
                    Section {
                        Text("Недостаточно продуктов на складе или продукт не найден.")
                            .foregroundStyle(.red)
                    }
                }

                if showSuccess {
                    Section {
                        Text("Готово. Ингредиенты списаны со склада.")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Приготовить")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Списать") {
                        let success = store.produceDish(dish, portions: portions)
                        showSuccess = success
                        showError = !success

                        if success {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AddDishView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var category = ""
    @State private var salePrice = ""
    @State private var ingredients: [RecipeIngredient] = []
    @State private var allergens: [String] = []
    @State private var cookTime: Int = 0
    @State private var menuStatus: DishMenuStatus = .active
    @State private var dishType: DishType = .dish
    @State private var portionWeight = ""
    @State private var portionWeightUnit = "г"
    @State private var photoImage: UIImage? = nil
    @State private var steps: [CookingStep] = []
    @State private var calories: Double = 0
    @State private var proteins: Double = 0
    @State private var fats: Double = 0
    @State private var carbs: Double = 0

    var onSave: (Dish) -> Void

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !category.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            DishEditorForm(
                name: $name,
                category: $category,
                salePrice: $salePrice,
                ingredients: $ingredients,
                allergens: $allergens,
                cookTime: $cookTime,
                menuStatus: $menuStatus,
                dishType: $dishType,
                portionWeight: $portionWeight,
                portionWeightUnit: $portionWeightUnit,
                photoImage: $photoImage,
                steps: $steps,
                calories: $calories,
                proteins: $proteins,
                fats: $fats,
                carbs: $carbs
            )
            .navigationTitle("Новое блюдо")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        var dish = Dish(
                            name: name,
                            category: category,
                            salePrice: parsePositiveDouble(salePrice) ?? 0,
                            ingredients: ingredients,
                            allergens: allergens,
                            cookTime: cookTime,
                            menuStatus: menuStatus
                        )
                        if let img = photoImage,
                           let data = img.jpegData(compressionQuality: 0.8) {
                            let filename = "dish_\(dish.id.uuidString).jpg"
                            let url = FileManager.default.documentsURL.appendingPathComponent(filename)
                            try? data.write(to: url, options: .atomic)
                            dish.photoFilename = filename
                        }
                        dish.steps = steps
                        dish.dishType = dishType
                        dish.portionWeight = parseNonNegativeDouble(portionWeight) ?? 0
                        dish.portionWeightUnit = portionWeightUnit
                        dish.calories = calories
                        dish.proteins = proteins
                        dish.fats = fats
                        dish.carbs = carbs
                        onSave(dish)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

struct EditDishView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss

    let dish: Dish

    @State private var name: String
    @State private var category: String
    @State private var salePrice: String
    @State private var ingredients: [RecipeIngredient]
    @State private var allergens: [String]
    @State private var cookTime: Int
    @State private var menuStatus: DishMenuStatus
    @State private var dishType: DishType
    @State private var portionWeight: String
    @State private var portionWeightUnit: String
    @State private var photoImage: UIImage? = nil
    @State private var steps: [CookingStep]
    @State private var calories: Double
    @State private var proteins: Double
    @State private var fats: Double
    @State private var carbs: Double

    var onSave: (Dish) -> Void

    init(dish: Dish, onSave: @escaping (Dish) -> Void) {
        self.dish = dish
        self.onSave = onSave
        _name        = State(initialValue: dish.name)
        _category    = State(initialValue: dish.category)
        _salePrice   = State(initialValue: dish.salePrice > 0 ? String(dish.salePrice) : "")
        _ingredients = State(initialValue: dish.ingredients)
        _allergens   = State(initialValue: dish.allergens)
        _cookTime    = State(initialValue: dish.cookTime)
        _menuStatus  = State(initialValue: dish.menuStatus)
        _dishType    = State(initialValue: dish.dishType)
        _portionWeight = State(initialValue: dish.portionWeight > 0 ? String(dish.portionWeight) : "")
        _portionWeightUnit = State(initialValue: dish.portionWeightUnit)
        _steps       = State(initialValue: dish.steps)
        _calories    = State(initialValue: dish.calories)
        _proteins    = State(initialValue: dish.proteins)
        _fats        = State(initialValue: dish.fats)
        _carbs       = State(initialValue: dish.carbs)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !category.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            DishEditorForm(
                name: $name,
                category: $category,
                salePrice: $salePrice,
                ingredients: $ingredients,
                allergens: $allergens,
                cookTime: $cookTime,
                menuStatus: $menuStatus,
                dishType: $dishType,
                portionWeight: $portionWeight,
                portionWeightUnit: $portionWeightUnit,
                photoImage: $photoImage,
                steps: $steps,
                calories: $calories,
                proteins: $proteins,
                fats: $fats,
                carbs: $carbs
            )
            .navigationTitle("Редактировать")
            .onAppear {
                photoImage = store.loadDishPhoto(for: dish)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        var updatedDish = Dish(
                            id: dish.id,
                            name: name,
                            category: category,
                            salePrice: parsePositiveDouble(salePrice) ?? dish.salePrice,
                            ingredients: ingredients,
                            allergens: allergens,
                            cookTime: cookTime,
                            menuStatus: menuStatus,
                            photoFilename: dish.photoFilename
                        )
                        if let img = photoImage,
                           let data = img.jpegData(compressionQuality: 0.8) {
                            let filename = "dish_\(updatedDish.id.uuidString).jpg"
                            let url = FileManager.default.documentsURL.appendingPathComponent(filename)
                            try? data.write(to: url, options: .atomic)
                            updatedDish.photoFilename = filename
                        } else if photoImage == nil && dish.photoFilename != nil {
                            // User removed photo
                            if let fn = dish.photoFilename {
                                let url = FileManager.default.documentsURL.appendingPathComponent(fn)
                                try? FileManager.default.removeItem(at: url)
                            }
                            updatedDish.photoFilename = nil
                        }
                        updatedDish.steps = steps
                        updatedDish.dishType = dishType
                        updatedDish.portionWeight = parseNonNegativeDouble(portionWeight) ?? 0
                        updatedDish.portionWeightUnit = portionWeightUnit
                        updatedDish.calories = calories
                        updatedDish.proteins = proteins
                        updatedDish.fats = fats
                        updatedDish.carbs = carbs
                        store.saveRecipeVersion(for: dish)
                        onSave(updatedDish)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

struct DishEditorForm: View {
    @EnvironmentObject var store: ChefProStore
    @Binding var name: String
    @Binding var category: String
    @Binding var salePrice: String
    @Binding var ingredients: [RecipeIngredient]
    @Binding var allergens: [String]
    @Binding var cookTime: Int
    @Binding var menuStatus: DishMenuStatus
    @Binding var dishType: DishType
    @Binding var portionWeight: String
    @Binding var portionWeightUnit: String
    @Binding var photoImage: UIImage?
    @Binding var steps: [CookingStep]
    @Binding var calories: Double
    @Binding var proteins: Double
    @Binding var fats: Double
    @Binding var carbs: Double

    @State private var productName    = ""
    @State private var quantity       = ""
    @State private var unit           = "г"
    @State private var yieldFactor    = "1.0"
    @State private var normalisedHint: String? = nil
    @State private var showSuggestions = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var newStepText = ""
    @State private var newStepTip = ""
    @State private var newStepDuration = 0
    @State private var editingStepID: UUID? = nil
    @State private var stepPhotoItems: [UUID: PhotosPickerItem] = [:]
    @State private var stepPhotos: [UUID: UIImage] = [:]
    @State private var isReorderingIngredients = false
    @State private var isReorderingSteps = false

    let units = ["г", "кг", "мл", "л", "шт"]

    // MARK: - Semi-finished cost calculation

    /// Total ingredient cost accounting for yield losses
    private var calculatedIngredientCost: Double {
        ingredients.reduce(0.0) { total, ingredient in
            // try exact match, then partial
            let item = store.inventoryItems.first(where: {
                $0.name.lowercased() == ingredient.productName.lowercased()
            }) ?? store.inventoryItems.first(where: {
                $0.name.lowercased().contains(ingredient.productName.lowercased()) ||
                ingredient.productName.lowercased().contains($0.name.lowercased())
            })
            guard let item else { return total }
            let rawQty = ingredient.yieldFactor > 0
                ? ingredient.quantity / ingredient.yieldFactor
                : ingredient.quantity
            let converted = store.convert(quantity: rawQty, from: ingredient.unit, to: item.unit)
            return total + converted * item.pricePerUnit
        }
    }

    /// Cost per one output unit (portionWeight amount)
    private var costPerBatch: Double { calculatedIngredientCost }

    /// How many ingredients were found in inventory
    private var matchedCount: Int {
        ingredients.filter { ingredient in
            store.inventoryItems.contains(where: {
                $0.name.lowercased() == ingredient.productName.lowercased() ||
                $0.name.lowercased().contains(ingredient.productName.lowercased()) ||
                ingredient.productName.lowercased().contains($0.name.lowercased())
            })
        }.count
    }

    private func applyCalculatedPrice() {
        salePrice = String(format: "%.2f", costPerBatch)
    }

    private var suggestions: [InventoryItem] {
        guard !productName.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return store.inventoryItems
            .filter { $0.name.localizedCaseInsensitiveContains(productName) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        Form {
            // ── Фото блюда ──────────────────────────────────────
            Section("Фото блюда") {
                if let img = photoImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)
                        .listRowInsets(EdgeInsets())
                }
                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(photoImage == nil ? "Добавить фото" : "Изменить фото", systemImage: "camera")
                    }
                    if photoImage != nil {
                        Spacer()
                        Button(role: .destructive) { photoImage = nil; selectedPhotoItem = nil } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img  = UIImage(data: data) {
                        photoImage = img
                    }
                }
            }

            Section("Основная информация") {
                TextField("Название блюда", text: $name)

                // Category: type freely OR pick existing
                HStack {
                    TextField("Категория", text: $category)
                    if !store.dishCategories.isEmpty {
                        Menu {
                            ForEach(store.dishCategories, id: \.self) { cat in
                                Button(cat) { category = cat }
                            }
                            Divider()
                            Button("Новая…") { category = "" }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(.chefAccent)
                        }
                    }
                }

                TextField("Цена продажи", text: $salePrice)
                    .keyboardType(.decimalPad)
                Stepper(cookTime == 0 ? "Время готовки: не задано" : "Время готовки: \(cookTime) мин",
                        value: $cookTime, in: 0...180, step: 5)
                Picker("Статус в меню", selection: $menuStatus) {
                    ForEach(DishMenuStatus.allCases, id: \.self) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                Picker("Тип", selection: $dishType) {
                    ForEach(DishType.allCases, id: \.self) { t in
                        Label(t.rawValue, systemImage: t.icon).tag(t)
                    }
                }
            }

            Section("Выход готового блюда") {
                HStack {
                    TextField("Количество", text: $portionWeight)
                        .keyboardType(.decimalPad)
                    Divider()
                    Picker("", selection: $portionWeightUnit) {
                        ForEach(["г","кг","мл","л","шт","порц"], id: \.self) { u in
                            Text(u).tag(u)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                }
            }

            // ── Авторасчёт себестоимости (только для полуфабрикатов) ──
            if dishType == .semifinished && !ingredients.isEmpty {
                Section {
                    // Total ingredient cost
                    HStack {
                        Label("Стоимость сырья", systemImage: "cart.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(calculatedIngredientCost, specifier: "%.2f") ₽")
                            .bold()
                    }

                    // Cost per output unit
                    if let weight = parsePositiveDouble(portionWeight), weight > 0 {
                        let perUnit = calculatedIngredientCost / weight
                        HStack {
                            Label("Себестоимость за 1 \(portionWeightUnit)", systemImage: "scalemass.fill")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(perUnit, specifier: "%.4f") ₽")
                                .bold()
                                .foregroundStyle(.chefAccent)
                        }
                    }

                    // Coverage indicator
                    if matchedCount < ingredients.count {
                        Label("\(ingredients.count - matchedCount) ингр. не найдено на складе — цена занижена",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    // Apply button
                    Button {
                        applyCalculatedPrice()
                    } label: {
                        Label("Установить как цену продажи (\(String(format: "%.2f", costPerBatch)) ₽)",
                              systemImage: "arrow.down.circle.fill")
                    }
                    .foregroundStyle(.chefAccent)
                } header: {
                    Text("Расчёт себестоимости")
                } footer: {
                    Text("Расчёт учитывает потери при обработке (yieldFactor). Нажмите кнопку чтобы применить как цену.")
                }
                .onChange(of: ingredients) { _, _ in applyCalculatedPrice() }
                .onChange(of: portionWeight) { _, _ in applyCalculatedPrice() }
            }

            Section("Нутриенты (на порцию)") {
                HStack {
                    Label("Калории", systemImage: "flame")
                    Spacer()
                    TextField("0", value: $calories, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("ккал").foregroundStyle(.secondary)
                }
                HStack {
                    Label("Белки", systemImage: "circle.grid.3x3")
                    Spacer()
                    TextField("0", value: $proteins, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("г").foregroundStyle(.secondary)
                }
                HStack {
                    Label("Жиры", systemImage: "drop.fill")
                    Spacer()
                    TextField("0", value: $fats, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("г").foregroundStyle(.secondary)
                }
                HStack {
                    Label("Углеводы", systemImage: "leaf.fill")
                    Spacer()
                    TextField("0", value: $carbs, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("г").foregroundStyle(.secondary)
                }
            }

            Section("Добавить ингредиент") {
                TextField("Продукт со склада", text: $productName)
                    .onChange(of: productName) { _, _ in
                        showSuggestions = !suggestions.isEmpty
                    }

                if showSuggestions {
                    ForEach(suggestions) { item in
                        Button {
                            productName = item.name
                            unit        = item.unit
                            showSuggestions = false
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.chefAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).foregroundStyle(.primary)
                                    Text("\(item.quantity, specifier: "%.1f") \(item.unit) · \(item.category)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                TextField("Количество", text: $quantity)
                    .keyboardType(.decimalPad)
                    .onChange(of: quantity) { _, newVal in
                        if let qty = Double(newVal.replacingOccurrences(of: ",", with: ".")) {
                            let (normQty, normUnit) = normaliseUnit(quantity: qty, unit: unit)
                            if normUnit != unit {
                                let formatted = normQty.truncatingRemainder(dividingBy: 1) == 0
                                    ? String(format: "%.0f", normQty) : String(format: "%.3g", normQty)
                                normalisedHint = "→ \(formatted) \(normUnit)"
                            } else {
                                normalisedHint = nil
                            }
                        } else {
                            normalisedHint = nil
                        }
                    }

                if let hint = normalisedHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.chefAccent)
                }

                Picker("Единица", selection: $unit) {
                    ForEach(units, id: \.self) { Text($0) }
                }

                HStack {
                    Text("Норматив потерь")
                    Spacer()
                    TextField("0.80", text: $yieldFactor)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("(0–1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Добавить ингредиент") {
                    guard let qty = parsePositiveDouble(quantity) else { return }
                    let yf = Double(yieldFactor.replacingOccurrences(of: ",", with: ".")) ?? 1.0
                    let clampedYF = max(0.01, min(1.0, yf))
                    ingredients.append(RecipeIngredient(productName: productName, quantity: qty, unit: unit, yieldFactor: clampedYF))
                    productName = ""; quantity = ""; unit = "г"; yieldFactor = "1.0"; showSuggestions = false
                }
                .disabled(productName.trimmingCharacters(in: .whitespaces).isEmpty || parsePositiveDouble(quantity) == nil)
            }

            Section(header: HStack {
                Text("Ингредиенты")
                Spacer()
                if !ingredients.isEmpty {
                    Button(isReorderingIngredients ? "Готово" : "Упорядочить") {
                        isReorderingIngredients.toggle()
                    }
                    .font(.caption)
                    .foregroundStyle(.chefAccent)
                }
            }) {
                if ingredients.isEmpty {
                    Text("Ингредиенты не добавлены").foregroundStyle(.secondary)
                } else {
                    ForEach(ingredients) { ingredient in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.productName)
                                if ingredient.yieldFactor < 1.0 {
                                    Text("потери \(Int((1 - ingredient.yieldFactor) * 100))%")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Text("\(ingredient.quantity, specifier: "%.1f") \(ingredient.unit)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    .onMove { from, to in
                        ingredients.move(fromOffsets: from, toOffset: to)
                    }
                }
            }
            .environment(\.editMode, isReorderingIngredients ? .constant(.active) : .constant(.inactive))

            Section("Аллергены") {
                ForEach(allAllergens, id: \.self) { allergen in
                    Button {
                        if allergens.contains(allergen) {
                            allergens.removeAll { $0 == allergen }
                        } else {
                            allergens.append(allergen)
                        }
                    } label: {
                        HStack {
                            Text(allergen).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: allergens.contains(allergen) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(allergens.contains(allergen) ? Color.chefAccent : Color.secondary)
                        }
                    }
                }
            }

            // ── Шаги приготовления ────────────────────────────
            Section(header: HStack {
                Text("Шаги приготовления (\(steps.count))")
                Spacer()
                if !steps.isEmpty {
                    Button(isReorderingSteps ? "Готово" : "Упорядочить") {
                        isReorderingSteps.toggle()
                    }
                    .font(.caption)
                    .foregroundStyle(.chefAccent)
                }
            }) {
                ForEach($steps) { $step in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color.chefAccent.opacity(0.15)).frame(width: 28, height: 28)
                                Text("\(step.stepNumber)").font(.caption.bold()).foregroundStyle(.chefAccent)
                            }
                            TextField("Описание шага", text: $step.instruction, axis: .vertical)
                                .lineLimit(2...4)
                        }

                        if step.durationMinutes > 0 {
                            Label("\(step.durationMinutes) мин", systemImage: "timer")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        if !step.tip.isEmpty {
                            Label(step.tip, systemImage: "lightbulb").font(.caption).foregroundStyle(.orange)
                        }

                        if let img = stepPhotos[step.id] ?? store.loadStepPhoto(for: step) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 120)
                                .clipped().cornerRadius(8)
                        }

                        HStack {
                            PhotosPicker(selection: Binding(
                                get: { stepPhotoItems[step.id] },
                                set: { stepPhotoItems[step.id] = $0 }
                            ), matching: .images) {
                                Label("Фото шага", systemImage: "camera").font(.caption)
                            }
                            .onChange(of: stepPhotoItems[step.id]) { _, item in
                                Task {
                                    if let data = try? await item?.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data),
                                       let jpegData = img.jpegData(compressionQuality: 0.8) {
                                        let filename = "step_\(step.id.uuidString).jpg"
                                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                                        try? jpegData.write(to: url, options: .atomic)
                                        step.photoFilename = filename
                                        stepPhotos[step.id] = img
                                    }
                                }
                            }

                            Spacer()

                            Stepper(step.durationMinutes == 0 ? "Время" : "\(step.durationMinutes) мин",
                                    value: $step.durationMinutes, in: 0...120, step: 5)
                                .labelsHidden()
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    steps.remove(atOffsets: offsets)
                    for i in steps.indices { steps[i].stepNumber = i + 1 }
                }
                .onMove { from, to in
                    steps.move(fromOffsets: from, toOffset: to)
                    for i in steps.indices { steps[i].stepNumber = i + 1 }
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Новый шаг (например: обжарить лук 5 минут)", text: $newStepText, axis: .vertical)
                        .lineLimit(2...3)
                    TextField("Совет шеф-повара (опционально)", text: $newStepTip)
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Добавить шаг") {
                        guard !newStepText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let step = CookingStep(
                            stepNumber: steps.count + 1,
                            instruction: newStepText,
                            durationMinutes: newStepDuration,
                            tip: newStepTip
                        )
                        steps.append(step)
                        newStepText = ""; newStepTip = ""; newStepDuration = 0
                    }
                    .disabled(newStepText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .environment(\.editMode, isReorderingSteps ? .constant(.active) : .constant(.inactive))
        }
    }
}

// MARK: - Dish Gallery

struct DishGalleryView: View {
    @EnvironmentObject var store: ChefProStore

    private var dishesWithPhotos: [Dish] {
        store.dishes.filter { $0.photoFilename != nil }
    }

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            if dishesWithPhotos.isEmpty {
                EmptyStateView(icon: "photo.stack", title: "Нет фото",
                               subtitle: "Добавьте фото блюдам в редакторе техкарты")
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(dishesWithPhotos) { dish in
                        NavigationLink {
                            DishDetailView(dish: dish).environmentObject(store)
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                if let img = store.loadDishPhoto(for: dish) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: (UIScreen.main.bounds.width - 4) / 3,
                                               height: (UIScreen.main.bounds.width - 4) / 3)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.chefCard)
                                        .frame(width: (UIScreen.main.bounds.width - 4) / 3,
                                               height: (UIScreen.main.bounds.width - 4) / 3)
                                }
                                LinearGradient(colors: [.clear, .black.opacity(0.5)],
                                               startPoint: .center, endPoint: .bottom)
                                Text(dish.name)
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(6)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .navigationTitle("Галерея блюд")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Recipe Scaling

struct RecipeScalingView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    let dish: Dish
    @State private var portions = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Блюдо") {
                    Text(dish.name).font(.headline)
                    Stepper("Порций: \(portions)", value: $portions, in: 1...999)
                    Text("Итоговая себестоимость: \(store.calculateDishCost(dish) * Double(portions), specifier: "%.2f")")
                        .foregroundStyle(.chefAccent)
                }

                Section("Ингредиенты на \(portions) \(portionsWord)") {
                    ForEach(dish.ingredients) { ing in
                        HStack {
                            Text(ing.productName)
                            Spacer()
                            Text("\(ing.quantity * Double(portions), specifier: "%.2f") \(ing.unit)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                if !dish.allergens.isEmpty {
                    Section("Аллергены") {
                        Text(dish.allergens.joined(separator: " · "))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Масштабирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private var portionsWord: String {
        let rem10 = portions % 10
        let rem100 = portions % 100
        if rem100 >= 11 && rem100 <= 14 { return "порций" }
        if rem10 == 1 { return "порцию" }
        if rem10 >= 2 && rem10 <= 4 { return "порции" }
        return "порций"
    }
}

// MARK: - Menu Collections

struct MenuCollectionsView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newEmoji = "🍽️"

    var body: some View {
        List {
            ForEach(store.menuCollections) { col in
                NavigationLink {
                    MenuCollectionDetailView(collection: col)
                        .environmentObject(store)
                } label: {
                    HStack(spacing: 12) {
                        Text(col.emoji).font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(col.name).font(.headline)
                            Text("\(col.dishIDs.count) блюд").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { store.menuCollections.remove(atOffsets: $0) }
        }
        .navigationTitle("Сборники меню")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                Form {
                    Section("Новый сборник") {
                        HStack {
                            TextField("Эмодзи", text: $newEmoji).frame(width: 50)
                            TextField("Название", text: $newName)
                        }
                    }
                }
                .navigationTitle("Новый сборник")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Отмена") { showAdd = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Создать") {
                            store.addCollection(MenuCollection(name: newName, emoji: newEmoji))
                            newName = ""; newEmoji = "🍽️"; showAdd = false
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}

struct MenuCollectionDetailView: View {
    @EnvironmentObject var store: ChefProStore
    let collection: MenuCollection

    var currentCollection: MenuCollection {
        store.menuCollections.first(where: { $0.id == collection.id }) ?? collection
    }

    var collectionDishes: [Dish] {
        currentCollection.dishIDs.compactMap { id in store.dishes.first(where: { $0.id == id }) }
    }

    var availableDishes: [Dish] {
        store.dishes.filter { !currentCollection.dishIDs.contains($0.id) }
    }

    var body: some View {
        List {
            Section("Блюда в сборнике (\(collectionDishes.count))") {
                ForEach(collectionDishes) { dish in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dish.name).font(.headline)
                            Text(dish.category).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .onDelete { offsets in
                    var col = currentCollection
                    let ids = offsets.map { collectionDishes[$0].id }
                    col.dishIDs.removeAll { ids.contains($0) }
                    store.updateCollection(col)
                }
            }

            if !availableDishes.isEmpty {
                Section("Добавить блюдо") {
                    ForEach(availableDishes) { dish in
                        Button {
                            var col = currentCollection
                            col.dishIDs.append(dish.id)
                            store.updateCollection(col)
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle").foregroundStyle(.green)
                                Text(dish.name).foregroundStyle(.primary)
                                Spacer()
                                Text(dish.category).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(currentCollection.emoji) \(currentCollection.name)")
    }
}

// MARK: - Recipe Templates

struct RecipeTemplate: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let salePrice: Double
    let ingredients: [RecipeIngredient]
}

let recipeTemplates: [RecipeTemplate] = [
    RecipeTemplate(name: "Борщ классический", category: "Супы", salePrice: 9.50, ingredients: [
        RecipeIngredient(productName: "Свекла", quantity: 200, unit: "г"),
        RecipeIngredient(productName: "Капуста", quantity: 150, unit: "г"),
        RecipeIngredient(productName: "Картофель", quantity: 100, unit: "г"),
        RecipeIngredient(productName: "Морковь", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Томатная паста", quantity: 30, unit: "г"),
    ]),
    RecipeTemplate(name: "Пицца Маргарита", category: "Пицца", salePrice: 12.90, ingredients: [
        RecipeIngredient(productName: "Тесто для пиццы", quantity: 250, unit: "г"),
        RecipeIngredient(productName: "Томатный соус", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Сыр Моцарелла", quantity: 120, unit: "г"),
        RecipeIngredient(productName: "Базилик", quantity: 5, unit: "г"),
    ]),
    RecipeTemplate(name: "Паста Карбонара", category: "Паста", salePrice: 14.50, ingredients: [
        RecipeIngredient(productName: "Паста спагетти", quantity: 150, unit: "г"),
        RecipeIngredient(productName: "Бекон", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Яйца", quantity: 2, unit: "шт"),
        RecipeIngredient(productName: "Пармезан", quantity: 40, unit: "г"),
        RecipeIngredient(productName: "Сливки", quantity: 100, unit: "мл"),
    ]),
    RecipeTemplate(name: "Стейк Рибай", category: "Горячие блюда", salePrice: 28.00, ingredients: [
        RecipeIngredient(productName: "Говядина Рибай", quantity: 300, unit: "г", yieldFactor: 0.85),
        RecipeIngredient(productName: "Масло сливочное", quantity: 20, unit: "г"),
        RecipeIngredient(productName: "Розмарин", quantity: 3, unit: "г"),
        RecipeIngredient(productName: "Чеснок", quantity: 5, unit: "г"),
    ]),
    RecipeTemplate(name: "Тирамису", category: "Десерты", salePrice: 8.50, ingredients: [
        RecipeIngredient(productName: "Маскарпоне", quantity: 150, unit: "г"),
        RecipeIngredient(productName: "Савоярди", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Яйца", quantity: 2, unit: "шт"),
        RecipeIngredient(productName: "Кофе эспрессо", quantity: 100, unit: "мл"),
        RecipeIngredient(productName: "Какао-порошок", quantity: 10, unit: "г"),
    ]),
    RecipeTemplate(name: "Греческий салат", category: "Салаты", salePrice: 10.50, ingredients: [
        RecipeIngredient(productName: "Помидоры", quantity: 150, unit: "г"),
        RecipeIngredient(productName: "Огурцы", quantity: 100, unit: "г"),
        RecipeIngredient(productName: "Оливки", quantity: 50, unit: "г"),
        RecipeIngredient(productName: "Фета", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Оливковое масло", quantity: 30, unit: "мл"),
    ]),
    RecipeTemplate(name: "Том Ям", category: "Супы", salePrice: 13.90, ingredients: [
        RecipeIngredient(productName: "Куриный бульон", quantity: 500, unit: "мл"),
        RecipeIngredient(productName: "Тигровые креветки", quantity: 100, unit: "г", yieldFactor: 0.7),
        RecipeIngredient(productName: "Грибы шиитаке", quantity: 60, unit: "г"),
        RecipeIngredient(productName: "Кокосовое молоко", quantity: 150, unit: "мл"),
        RecipeIngredient(productName: "Лемонграсс", quantity: 10, unit: "г"),
    ]),
    RecipeTemplate(name: "Чизкейк Нью-Йорк", category: "Десерты", salePrice: 9.00, ingredients: [
        RecipeIngredient(productName: "Сливочный сыр", quantity: 400, unit: "г"),
        RecipeIngredient(productName: "Сахар", quantity: 120, unit: "г"),
        RecipeIngredient(productName: "Яйца", quantity: 3, unit: "шт"),
        RecipeIngredient(productName: "Печенье крекер", quantity: 150, unit: "г"),
        RecipeIngredient(productName: "Масло сливочное", quantity: 80, unit: "г"),
    ]),
    RecipeTemplate(name: "Суши Нигири Лосось", category: "Суши", salePrice: 3.50, ingredients: [
        RecipeIngredient(productName: "Рис для суши", quantity: 40, unit: "г"),
        RecipeIngredient(productName: "Лосось", quantity: 25, unit: "г", yieldFactor: 0.85),
        RecipeIngredient(productName: "Рисовый уксус", quantity: 5, unit: "мл"),
    ]),
    RecipeTemplate(name: "Биф Бургер", category: "Бургеры", salePrice: 13.50, ingredients: [
        RecipeIngredient(productName: "Котлета говяжья", quantity: 150, unit: "г", yieldFactor: 0.9),
        RecipeIngredient(productName: "Булочка бургерная", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Сыр Чеддер", quantity: 30, unit: "г"),
        RecipeIngredient(productName: "Листья салата", quantity: 20, unit: "г"),
        RecipeIngredient(productName: "Томат", quantity: 40, unit: "г"),
        RecipeIngredient(productName: "Соус бургерный", quantity: 25, unit: "г"),
    ]),
    RecipeTemplate(name: "Крем-суп тыква", category: "Супы", salePrice: 8.50, ingredients: [
        RecipeIngredient(productName: "Тыква", quantity: 400, unit: "г", yieldFactor: 0.75),
        RecipeIngredient(productName: "Сливки", quantity: 150, unit: "мл"),
        RecipeIngredient(productName: "Лук репчатый", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Имбирь", quantity: 10, unit: "г"),
        RecipeIngredient(productName: "Куриный бульон", quantity: 300, unit: "мл"),
    ]),
    RecipeTemplate(name: "Тако с курицей", category: "Мексиканская", salePrice: 10.00, ingredients: [
        RecipeIngredient(productName: "Тортилья", quantity: 60, unit: "г"),
        RecipeIngredient(productName: "Куриное филе", quantity: 100, unit: "г", yieldFactor: 0.85),
        RecipeIngredient(productName: "Авокадо", quantity: 60, unit: "г", yieldFactor: 0.65),
        RecipeIngredient(productName: "Сальса", quantity: 40, unit: "г"),
        RecipeIngredient(productName: "Сметана", quantity: 30, unit: "г"),
    ]),
    RecipeTemplate(name: "Лимонад домашний (1л)", category: "Напитки", salePrice: 6.00, ingredients: [
        RecipeIngredient(productName: "Лимон", quantity: 200, unit: "г", yieldFactor: 0.6),
        RecipeIngredient(productName: "Сахарный сироп", quantity: 150, unit: "мл"),
        RecipeIngredient(productName: "Мята", quantity: 10, unit: "г"),
        RecipeIngredient(productName: "Вода газированная", quantity: 700, unit: "мл"),
    ]),
    RecipeTemplate(name: "Шашлык из баранины", category: "Горячие блюда", salePrice: 18.00, ingredients: [
        RecipeIngredient(productName: "Баранина", quantity: 250, unit: "г", yieldFactor: 0.8),
        RecipeIngredient(productName: "Лук репчатый", quantity: 100, unit: "г"),
        RecipeIngredient(productName: "Специи для шашлыка", quantity: 15, unit: "г"),
        RecipeIngredient(productName: "Лимонный сок", quantity: 30, unit: "мл"),
    ]),
    RecipeTemplate(name: "Омлет с грибами", category: "Завтраки", salePrice: 7.50, ingredients: [
        RecipeIngredient(productName: "Яйца", quantity: 3, unit: "шт"),
        RecipeIngredient(productName: "Шампиньоны", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Молоко", quantity: 50, unit: "мл"),
        RecipeIngredient(productName: "Сыр", quantity: 30, unit: "г"),
        RecipeIngredient(productName: "Масло сливочное", quantity: 15, unit: "г"),
    ]),
    RecipeTemplate(name: "Мороженое Ванильное", category: "Десерты", salePrice: 4.50, ingredients: [
        RecipeIngredient(productName: "Молоко", quantity: 500, unit: "мл"),
        RecipeIngredient(productName: "Сливки 35%", quantity: 200, unit: "мл"),
        RecipeIngredient(productName: "Сахар", quantity: 150, unit: "г"),
        RecipeIngredient(productName: "Яйца", quantity: 4, unit: "шт"),
        RecipeIngredient(productName: "Ваниль", quantity: 2, unit: "г"),
    ]),
    RecipeTemplate(name: "Ризотто с белыми грибами", category: "Горячие блюда", salePrice: 16.00, ingredients: [
        RecipeIngredient(productName: "Рис Арборио", quantity: 150, unit: "г"),
        RecipeIngredient(productName: "Белые грибы", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Пармезан", quantity: 50, unit: "г"),
        RecipeIngredient(productName: "Белое вино", quantity: 100, unit: "мл"),
        RecipeIngredient(productName: "Лук-шалот", quantity: 60, unit: "г"),
        RecipeIngredient(productName: "Масло сливочное", quantity: 40, unit: "г"),
    ]),
    RecipeTemplate(name: "Сёмга на гриле", category: "Рыба", salePrice: 22.00, ingredients: [
        RecipeIngredient(productName: "Лосось филе", quantity: 200, unit: "г", yieldFactor: 0.9),
        RecipeIngredient(productName: "Лимон", quantity: 30, unit: "г"),
        RecipeIngredient(productName: "Розмарин", quantity: 3, unit: "г"),
        RecipeIngredient(productName: "Оливковое масло", quantity: 20, unit: "мл"),
    ]),
    RecipeTemplate(name: "Брускетта с томатами", category: "Закуски", salePrice: 7.00, ingredients: [
        RecipeIngredient(productName: "Хлеб чиабатта", quantity: 80, unit: "г"),
        RecipeIngredient(productName: "Помидоры черри", quantity: 100, unit: "г"),
        RecipeIngredient(productName: "Базилик", quantity: 5, unit: "г"),
        RecipeIngredient(productName: "Чеснок", quantity: 5, unit: "г"),
        RecipeIngredient(productName: "Оливковое масло", quantity: 15, unit: "мл"),
    ]),
    RecipeTemplate(name: "Пад Тай", category: "Азиатская", salePrice: 14.00, ingredients: [
        RecipeIngredient(productName: "Рисовая лапша", quantity: 150, unit: "г"),
        RecipeIngredient(productName: "Тигровые креветки", quantity: 80, unit: "г", yieldFactor: 0.7),
        RecipeIngredient(productName: "Яйца", quantity: 2, unit: "шт"),
        RecipeIngredient(productName: "Соус Пад Тай", quantity: 50, unit: "мл"),
        RecipeIngredient(productName: "Ростки сои", quantity: 60, unit: "г"),
        RecipeIngredient(productName: "Арахис", quantity: 20, unit: "г"),
    ]),
]

// MARK: - Nutrient Cell

private struct NutrientCell: View {
    let value: Double
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value > 0 ? String(format: "%.0f", value) : "—")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cooking Mode

struct CookingModeView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss
    let dish: Dish

    @State private var currentIndex = 0
    @State private var secondsLeft = 0
    @State private var timerRunning = false
    @State private var timer: Timer? = nil

    private var steps: [CookingStep] { dish.steps }
    private var currentStep: CookingStep? {
        guard !steps.isEmpty, currentIndex < steps.count else { return nil }
        return steps[currentIndex]
    }
    private var progress: Double {
        steps.isEmpty ? 0 : Double(currentIndex + 1) / Double(steps.count)
    }
    private var totalMinutes: Int { steps.reduce(0) { $0 + $1.durationMinutes } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.chefBackground.ignoresSafeArea()

                if let step = currentStep {
                    ScrollView {
                        VStack(spacing: 0) {
                            if let img = store.loadStepPhoto(for: step) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(maxWidth: .infinity).frame(height: 280).clipped()
                            } else {
                                ZStack {
                                    Color.chefCard
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 64))
                                        .foregroundStyle(.secondary.opacity(0.3))
                                }
                                .frame(height: 160)
                            }

                            VStack(alignment: .leading, spacing: 20) {
                                HStack {
                                    Text("Шаг \(currentIndex + 1) из \(steps.count)")
                                        .font(.subheadline.bold()).foregroundStyle(.chefAccent)
                                    Spacer()
                                    if step.durationMinutes > 0 {
                                        timerView(for: step)
                                    }
                                }
                                ProgressView(value: progress).tint(.chefAccent)

                                Text(step.instruction).font(.title3).lineSpacing(6)

                                if !step.tip.isEmpty {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "lightbulb.fill").foregroundStyle(.orange)
                                        Text(step.tip).font(.subheadline).foregroundStyle(.orange)
                                    }
                                    .padding(12)
                                    .background(Color.orange.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                HStack(spacing: 14) {
                                    if currentIndex > 0 {
                                        Button {
                                            goToStep(currentIndex - 1)
                                        } label: {
                                            Label("Назад", systemImage: "chevron.left")
                                                .frame(maxWidth: .infinity).frame(height: 52)
                                        }
                                        .buttonStyle(.bordered).controlSize(.large)
                                    }

                                    if currentIndex < steps.count - 1 {
                                        Button {
                                            goToStep(currentIndex + 1)
                                        } label: {
                                            Label("Далее", systemImage: "chevron.right")
                                                .frame(maxWidth: .infinity).frame(height: 52)
                                        }
                                        .buttonStyle(.borderedProminent).tint(.chefAccent).controlSize(.large)
                                    } else {
                                        Button {
                                            stopTimer()
                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                            dismiss()
                                        } label: {
                                            Label("Готово!", systemImage: "checkmark.circle.fill")
                                                .frame(maxWidth: .infinity).frame(height: 52)
                                        }
                                        .buttonStyle(.borderedProminent).tint(.green).controlSize(.large)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "list.number").font(.system(size: 64)).foregroundStyle(.secondary)
                        Text("Шаги не добавлены").font(.title2).bold()
                        Text("Добавьте шаги в редакторе техкарты").foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle(dish.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Закрыть") { stopTimer(); dismiss() } }
                if totalMinutes > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Label("~\(totalMinutes) мин", systemImage: "clock")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear { setupTimer(for: steps.first) }
            .onDisappear { stopTimer() }
        }
    }

    @ViewBuilder
    private func timerView(for step: CookingStep) -> some View {
        HStack(spacing: 8) {
            let mins = secondsLeft / 60
            let secs = secondsLeft % 60
            Text(String(format: "%d:%02d", mins, secs))
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(secondsLeft <= 10 && timerRunning ? .red : .primary)

            Button {
                if timerRunning { pauseTimer() } else { resumeTimer(step: step) }
            } label: {
                Image(systemName: timerRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.chefAccent)
            }

            Button {
                resetTimer(step: step)
            } label: {
                Image(systemName: "arrow.counterclockwise.circle")
                    .font(.title3).foregroundStyle(.secondary)
            }
        }
    }

    private func goToStep(_ index: Int) {
        stopTimer()
        withAnimation { currentIndex = index }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let step = steps[index]
        setupTimer(for: step)
    }

    private func setupTimer(for step: CookingStep?) {
        stopTimer()
        guard let step, step.durationMinutes > 0 else { secondsLeft = 0; return }
        secondsLeft = step.durationMinutes * 60
        timerRunning = false
    }

    private func resumeTimer(step: CookingStep) {
        if secondsLeft == 0 { secondsLeft = step.durationMinutes * 60 }
        timerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsLeft > 0 {
                secondsLeft -= 1
                if secondsLeft == 0 {
                    timerRunning = false
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        }
    }

    private func pauseTimer() {
        timerRunning = false
        timer?.invalidate(); timer = nil
    }

    private func stopTimer() {
        timerRunning = false
        timer?.invalidate(); timer = nil
        secondsLeft = 0
    }

    private func resetTimer(step: CookingStep) {
        stopTimer()
        secondsLeft = step.durationMinutes * 60
    }
}

struct RecipeTemplatesView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var searchText = ""
    @State private var addedIDs: Set<UUID> = []

    private var filtered: [RecipeTemplate] {
        searchText.isEmpty ? recipeTemplates
            : recipeTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.category.localizedCaseInsensitiveContains(searchText) }
    }

    private var grouped: [(String, [RecipeTemplate])] {
        let cats = Array(Set(filtered.map { $0.category })).sorted()
        return cats.map { cat in (cat, filtered.filter { $0.category == cat }) }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.0) { category, templates in
                Section(category) {
                    ForEach(templates) { template in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.name).font(.headline)
                                Text("\(template.ingredients.count) ингредиентов")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if addedIDs.contains(template.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button {
                                    let dish = Dish(
                                        name: template.name,
                                        category: template.category,
                                        salePrice: template.salePrice,
                                        ingredients: template.ingredients
                                    )
                                    store.dishes.append(dish)
                                    addedIDs.insert(template.id)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.chefAccent)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Поиск шаблона")
        .navigationTitle("Шаблоны техкарт")
    }
}
