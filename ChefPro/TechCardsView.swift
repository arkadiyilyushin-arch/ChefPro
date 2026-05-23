import SwiftUI
import PhotosUI

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
        BigCard {
            HStack(spacing: 14) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(fcColor)
                    .frame(width: 44, height: 44)
                    .background(fcColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Text(dish.name).font(.title3).bold()
                            .foregroundStyle(dish.menuStatus == .removed ? Color.secondary : Color.primary)
                        if dish.isFavorite {
                            Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                        }
                        if dish.menuStatus != .active {
                            Image(systemName: dish.menuStatus.icon)
                                .font(.caption).foregroundStyle(dish.menuStatus.color)
                        }
                    }
                    Text(dish.category).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("Себестоимость: \(cost, specifier: "%.2f")")
                            .font(.subheadline).foregroundStyle(.primary)
                        if dish.cookTime > 0 {
                            Label("\(dish.cookTime) мин", systemImage: "timer")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !dish.allergens.isEmpty {
                        Text(dish.allergens.joined(separator: ", "))
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(foodCostPct, specifier: "%.0f")%")
                        .font(.title3).bold().foregroundStyle(fcColor)
                    Text("Food cost").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct TechCardsView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAddDish = false
    @State private var searchText = ""
    @State private var selectedCategory = "Все"
    @State private var selectedStatus: DishMenuStatus? = nil

    var categories: [String] {
        ["Все"] + store.dishCategories
    }

    var filteredDishes: [Dish] {
        let base = store.dishes.filter { dish in
            let ingredientNames = dish.ingredients.map { $0.productName }.joined(separator: " ")
            let matchesSearch = searchText.isEmpty ||
            dish.name.localizedCaseInsensitiveContains(searchText) ||
            dish.category.localizedCaseInsensitiveContains(searchText) ||
            ingredientNames.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == "Все" || dish.category == selectedCategory
            let matchesStatus = selectedStatus == nil || dish.menuStatus == selectedStatus
            return matchesSearch && matchesCategory && matchesStatus
        }
        return base.sorted { $0.isFavorite && !$1.isFavorite }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                Button { selectedCategory = cat } label: {
                                    Text(cat)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(selectedCategory == cat ? Color.chefAccent : Color(.systemGray5))
                                        .foregroundStyle(selectedCategory == cat ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                }
                            }
                            Divider().frame(height: 24)
                            ForEach(DishMenuStatus.allCases, id: \.self) { status in
                                Button {
                                    selectedStatus = selectedStatus == status ? nil : status
                                } label: {
                                    Label(status.rawValue, systemImage: status.icon)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(selectedStatus == status ? status.color : Color(.systemGray5))
                                        .foregroundStyle(selectedStatus == status ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if filteredDishes.isEmpty {
                        EmptyStateView(icon: "book.closed", title: "Ничего не найдено", subtitle: "Попробуй изменить поиск или категорию.")
                    } else {
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
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.chefBackground)
            .searchable(text: $searchText, prompt: "Поиск блюда или ингредиента")
            .navigationTitle("Техкарты")
            .toolbar {
                Button { showAddDish = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .sheet(isPresented: $showAddDish) {
                AddDishView { store.dishes.append($0) }
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

    var currentDish: Dish {
        store.dishes.first(where: { $0.id == dish.id }) ?? dish
    }

    private var dishStillExists: Bool {
        store.dishes.contains(where: { $0.id == dish.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BigCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(currentDish.name)
                            .font(.largeTitle)
                            .bold()
                        Text(currentDish.category)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Себестоимость")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(store.calculateDishCost(currentDish), specifier: "%.2f")")
                                    .font(.title2)
                                    .bold()
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text("Food cost")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(store.foodCostPercent(currentDish), specifier: "%.1f")%")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.chefAccent)
                            }
                        }

                        HStack(spacing: 16) {
                            Text("Цена продажи: \(currentDish.salePrice, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if currentDish.cookTime > 0 {
                                Label("\(currentDish.cookTime) мин", systemImage: "timer")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 6) {
                            Image(systemName: currentDish.menuStatus.icon)
                                .foregroundStyle(currentDish.menuStatus.color)
                            Text(currentDish.menuStatus.rawValue)
                                .font(.subheadline).foregroundStyle(currentDish.menuStatus.color)
                        }

                        if !currentDish.allergens.isEmpty {
                            Divider()
                            HStack(spacing: 6) {
                                Image(systemName: "allergens").foregroundStyle(.orange)
                                Text(currentDish.allergens.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                }

                if let photo = store.loadDishPhoto(for: currentDish) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                        .cornerRadius(20)
                }

                SectionTitle(title: "Ингредиенты")

                if currentDish.ingredients.isEmpty {
                    BigCard {
                        Text("Ингредиенты не добавлены")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(currentDish.ingredients) { ingredient in
                        BigCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(ingredient.productName)
                                        .font(.headline)
                                    Text("\(ingredient.quantity, specifier: "%.1f") \(ingredient.unit)")
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let item = store.inventoryItems.first(where: { $0.name.lowercased() == ingredient.productName.lowercased() }) {
                                    let converted = store.convert(quantity: ingredient.quantity, from: ingredient.unit, to: item.unit)
                                    Text("\(converted * item.pricePerUnit, specifier: "%.2f")")
                                        .font(.headline)
                                        .foregroundStyle(.chefAccent)
                                } else {
                                    Text("нет на складе")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }

                if !currentDish.steps.isEmpty {
                    SectionTitle(title: "Шаги приготовления (\(currentDish.steps.count))")

                    ForEach(currentDish.steps) { step in
                        BigCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(Color.chefAccent).frame(width: 32, height: 32)
                                        Text("\(step.stepNumber)")
                                            .font(.subheadline.bold()).foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(step.instruction)
                                            .font(.subheadline)
                                        if step.durationMinutes > 0 {
                                            Label("\(step.durationMinutes) мин", systemImage: "timer")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                if let img = store.loadStepPhoto(for: step) {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(maxWidth: .infinity).frame(height: 160)
                                        .clipped().cornerRadius(12)
                                }
                                if !step.tip.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lightbulb.fill").foregroundStyle(.orange)
                                        Text(step.tip).font(.caption).foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }

                    BigActionButton(title: "Режим приготовления", icon: "play.circle.fill") {
                        showCookingMode = true
                    }
                }

                BigActionButton(title: "Приготовить / списать", icon: "flame.fill") {
                    showProduce = true
                }

                BigActionButton(title: "Масштабировать рецептуру", icon: "arrow.up.left.and.arrow.down.right") {
                    showScaling = true
                }

                BigActionButton(title: "Экспорт техкарты в PDF", icon: "doc.richtext") {
                    if let url = PDFReportGenerator.createTechCardPDF(dish: currentDish, store: store) {
                        pdfURL = url
                        showShareSheet = true
                    }
                }

                BigActionButton(title: "Дублировать техкарту", icon: "doc.on.doc") {
                    var copy = currentDish
                    copy.id = UUID()
                    copy.name = currentDish.name + " (копия)"
                    copy.photoFilename = nil
                    store.dishes.append(copy)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                BigActionButton(title: "Редактировать техкарту", icon: "pencil") {
                    showEdit = true
                }

                BigActionButton(title: "История версий", icon: "clock.arrow.circlepath") {
                    showVersions = true
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Удалить техкарту", systemImage: "trash")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Техкарта")
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
    @State private var photoImage: UIImage? = nil
    @State private var steps: [CookingStep] = []

    var onSave: (Dish) -> Void

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !category.trimmingCharacters(in: .whitespaces).isEmpty &&
        parsePositiveDouble(salePrice) != nil
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
                photoImage: $photoImage,
                steps: $steps
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
    @State private var photoImage: UIImage? = nil
    @State private var steps: [CookingStep]

    var onSave: (Dish) -> Void

    init(dish: Dish, onSave: @escaping (Dish) -> Void) {
        self.dish = dish
        self.onSave = onSave
        _name        = State(initialValue: dish.name)
        _category    = State(initialValue: dish.category)
        _salePrice   = State(initialValue: String(dish.salePrice))
        _ingredients = State(initialValue: dish.ingredients)
        _allergens   = State(initialValue: dish.allergens)
        _cookTime    = State(initialValue: dish.cookTime)
        _menuStatus  = State(initialValue: dish.menuStatus)
        _steps       = State(initialValue: dish.steps)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !category.trimmingCharacters(in: .whitespaces).isEmpty &&
        parsePositiveDouble(salePrice) != nil
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
                photoImage: $photoImage,
                steps: $steps
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
                            salePrice: parsePositiveDouble(salePrice) ?? 0,
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
    @Binding var photoImage: UIImage?
    @Binding var steps: [CookingStep]

    @State private var productName    = ""
    @State private var quantity       = ""
    @State private var unit           = "г"
    @State private var yieldFactor    = "1.0"
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
                TextField("Категория", text: $category)
                TextField("Цена продажи", text: $salePrice)
                    .keyboardType(.decimalPad)
                Stepper(cookTime == 0 ? "Время готовки: не задано" : "Время готовки: \(cookTime) мин",
                        value: $cookTime, in: 0...180, step: 5)
                Picker("Статус в меню", selection: $menuStatus) {
                    ForEach(DishMenuStatus.allCases, id: \.self) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
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
                        Text("\(dish.salePrice, specifier: "%.2f")").foregroundStyle(.chefAccent)
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
                                Text("\(template.ingredients.count) ингредиентов · \(template.salePrice, specifier: "%.2f")")
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
