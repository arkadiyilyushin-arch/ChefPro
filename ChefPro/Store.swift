import SwiftUI
import UserNotifications
import CoreSpotlight
import WidgetKit

// MARK: - Undo Support

struct UndoableItem {
    enum ItemType { case dish, inventoryItem, writeOff, delivery, employee, supplier }
    let type: ItemType
    let description: String
    let restore: () -> Void
}

// MARK: - Store

final class ChefProStore: ObservableObject {
    @Published var dishes: [Dish] = [] { didSet { saveData() } }
    @Published var inventoryItems: [InventoryItem] = [] { didSet { saveData() } }
    @Published var deliveries: [Delivery] = [] { didSet { saveData() } }
    @Published var writeOffs: [WriteOff] = [] { didSet { saveData() } }
    @Published var productions: [Production] = [] { didSet { saveData() } }
    @Published var employees: [Employee] = [] { didSet { saveData() } }
    @Published var currentEmployeeID: UUID? = nil { didSet { saveData() } }
    @Published var kitchenOrders: [KitchenOrder] = [] { didSet { saveData() } }

    @Published var profile: UserProfile = UserProfile(
        name: "Иван Петров",
        position: "Шеф-повар",
        phone: "+47 000 00 000",
        permissions: ["Техкарты", "Склад", "Приемка", "Списания", "Отчеты", "Настройки"]
    ) { didSet { saveData() } }

    @Published var restaurantName: String = "Demo Restaurant" { didSet { saveData() } }
    @Published var appColorScheme: AppColorScheme = .system       { didSet { saveData() } }
    @Published var notificationsEnabled: Bool = false             { didSet { saveData() } }
    @Published var suppliers: [Supplier] = []                     { didSet { saveData() } }
    @Published var currentShift: Shift? = nil                     { didSet { saveData() } }
    @Published var shiftHistory: [Shift] = []                     { didSet { saveData() } }
    @Published var closedKitchenOrders: [KitchenOrder] = []       { didSet { saveData() } }
    @Published var sales: [Sale] = []                              { didSet { saveData() } }
    @Published var foodCostThreshold: Double = 35                   { didSet { saveData() } }
    @Published var currentProductionPlan: [PlanItem] = []           { didSet { saveData() } }
    @Published var purchaseBudget: Double = 0                       { didSet { saveData() } }
    @Published var monthlyRevenuePlan: Double = 0                   { didSet { saveData() } }
    @Published var monthlyFoodCostTarget: Double = 30               { didSet { saveData() } }
    @Published var expiryWarningDays: Int = 3                       { didSet { saveData() } }
    @Published var dailyDigestEnabled: Bool = false                 { didSet { saveData(); scheduleDailyDigest() } }
    @Published var haccpRemindersEnabled: Bool = false              { didSet { saveData(); scheduleHACCPReminders() } }
    @Published var haccpIntervalHours: Int = 4                      { didSet { saveData(); scheduleHACCPReminders() } }
    @Published var hasSeenOnboarding: Bool = false                  { didSet { saveData() } }
    @Published var checklists: [ChecklistItem] = []      { didSet { saveData() } }
    @Published var menuCollections: [MenuCollection] = [] { didSet { saveData() } }
    @Published var workSchedule: [WorkShift] = []         { didSet { saveData() } }
    @Published var temperatureLogs: [TemperatureLog] = [] { didSet { saveData() } }
    @Published var recipeVersions: [RecipeVersion] = []   { didSet { saveData() } }
    @Published var appLanguage: AppLanguage = .russian    { didSet { saveData() } }
    @Published var stockMovements: [StockMovement] = []   { didSet { saveData() } }

    @Published var reservations: [TableReservation] = []   { didSet { saveData() } }
    @Published var loyaltyCards:  [LoyaltyCard]       = []   { didSet { saveData() } }
    @Published var posRecords:    [POSSaleRecord]      = []   { didSet { saveData() } }

    @Published var isSyncing = false
    @Published var lastSyncDate: Date? = nil
    @Published var syncError: String? = nil

    @Published var undoItem: UndoableItem? = nil

    private let dishesKey = "chefpro_dishes_v2"
    private let inventoryKey = "chefpro_inventory_v2"
    private let deliveriesKey = "chefpro_deliveries_v2"
    private let writeOffsKey = "chefpro_writeoffs_v2"
    private let productionsKey = "chefpro_productions_v1"
    private let profileKey = "chefpro_profile_v2"
    private let employeesKey = "chefpro_employees_v2"
    private let currentEmployeeIDKey = "chefpro_current_employee_id_v2"
    private let lastSyncKey = "chefpro_last_sync_date"
    private let kitchenOrdersKey        = "chefpro_kitchen_orders_v1"
    private let closedKitchenOrdersKey  = "chefpro_closed_orders_v1"
    private let restaurantNameKey       = "chefpro_restaurant_name_v1"
    private let appColorSchemeKey       = "chefpro_color_scheme_v1"
    private let notificationsEnabledKey = "chefpro_notifications_v1"
    private let suppliersKey            = "chefpro_suppliers_v1"
    private let currentShiftKey         = "chefpro_current_shift_v1"
    private let shiftHistoryKey         = "chefpro_shift_history_v1"
    private let salesKey                = "chefpro_sales_v1"
    private let foodCostThresholdKey    = "chefpro_fc_threshold_v1"
    private let productionPlanKey       = "chefpro_plan_v1"
    private let purchaseBudgetKey           = "chefpro_purchase_budget_v1"
    private let monthlyRevenuePlanKey       = "chefpro_monthly_revenue_plan_v1"
    private let monthlyFoodCostTargetKey    = "chefpro_monthly_fc_target_v1"
    private let expiryWarningDaysKey        = "chefpro_expiry_warning_days_v1"
    private let dailyDigestKey          = "chefpro_daily_digest_v1"
    private let haccpRemindersKey       = "chefpro_haccp_reminders_v1"
    private let haccpIntervalHoursKey   = "chefpro_haccp_interval_v1"
    private let hasSeenOnboardingKey    = "chefpro_onboarding_v1"
    private let checklistsKey       = "chefpro_checklists_v1"
    private let collectionsKey      = "chefpro_collections_v1"
    private let workScheduleKey       = "chefpro_work_schedule_v1"
    private let temperatureLogsKey    = "chefpro_temp_logs_v1"
    private let appLanguageKey        = "chefpro_app_language_v1"
    private let recipeVersionsKey     = "chefpro_recipe_versions_v1"
    private let hasInitialDataKey     = "chefpro_has_initial_data_v1"
    private let stockMovementsKey     = "chefpro_stock_movements_v1"
    private let reservationsKey       = "chefpro_reservations_v1"
    private let loyaltyCardsKey       = "chefpro_loyalty_cards_v1"
    private let posRecordsKey         = "chefpro_pos_records_v1"

    // MARK: - Data Version Migration
    private let dataVersionKey    = "chefpro_data_version"
    private let currentDataVersion = 2

    // Prevents saveData() from firing during loadData() (every didSet would overwrite UserDefaults mid-load)
    private var isLoading = false
    // Prevents upload from triggering when we are writing downloaded data to properties
    private var isSyncingFromCloud = false
    private var uploadTask: Task<Void, Never>?

    init() {
        loadData()
        migrateIfNeeded()
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        if checklists.isEmpty { loadDefaultChecklists() }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        Task { await syncFromCloud() }
    }

    // MARK: - Data Version Migration

    private func migrateIfNeeded() {
        let savedVersion = UserDefaults.standard.integer(forKey: dataVersionKey)
        guard savedVersion < currentDataVersion else {
            // Even on current version — sync any semifinished that have no inventory item yet
            syncAllSemifinished()
            return
        }

        if savedVersion == 0 || savedVersion == 1 {
            saveData()
        }

        syncAllSemifinished()
        UserDefaults.standard.set(currentDataVersion, forKey: dataVersionKey)
    }

    /// Ensures every semi-finished dish has a corresponding InventoryItem.
    private func syncAllSemifinished() {
        for dish in dishes where dish.dishType == .semifinished {
            if !inventoryItems.contains(where: { $0.sourceDishID == dish.id }) {
                syncSemifinishedInventoryItem(for: dish)
            }
        }
    }

    // MARK: - Error Logging

    /// Logs a non-fatal error. In release builds this should forward to Crashlytics.
    func logError(_ error: Error, context: String) {
        #if !DEBUG
        // TODO: Uncomment after adding FirebaseCrashlytics target (see CRASHLYTICS_SETUP.md):
        // Crashlytics.crashlytics().record(error: error)
        #endif
        print("[\(context)] Error: \(error)")
    }

    var isLoggedIn: Bool {
        currentEmployee != nil
    }

    var currentEmployee: Employee? {
        guard let currentEmployeeID else { return nil }
        return employees.first { $0.id == currentEmployeeID }
    }

    var totalDeliverySum: Double {
        deliveries.reduce(0) { $0 + $1.price }
    }

    var currentMonthRevenue: Double {
        let calendar = Calendar.current
        let now = Date()
        return shiftHistory
            .filter { calendar.isDate($0.openedAt, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.revenue }
    }

    var currentMonthAvgFoodCost: Double {
        let calendar = Calendar.current
        let now = Date()
        let shifts = shiftHistory.filter {
            calendar.isDate($0.openedAt, equalTo: now, toGranularity: .month) && $0.foodCostForShift > 0
        }
        guard !shifts.isEmpty else { return 0 }
        return shifts.reduce(0) { $0 + $1.foodCostForShift } / Double(shifts.count)
    }

    var lowStockItems: [InventoryItem] {
        inventoryItems.filter { $0.isLowStock }
    }

    var expiringItems: [InventoryItem] {
        inventoryItems.filter { $0.isExpired || $0.isExpiringSoon }.sorted {
            ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture)
        }
    }

    var purchaseList: [InventoryItem] {
        inventoryItems.filter { $0.isLowStock }.sorted { $0.name < $1.name }
    }

    var dishCategories: [String] {
        Array(Set(dishes.map { $0.category })).sorted()
    }

    var inventoryCategories: [String] {
        Array(Set(inventoryItems.map { $0.category })).sorted()
    }

    func hasPermission(_ permission: String) -> Bool {
        profile.permissions.contains(permission)
    }

    func login(employee: Employee, pin: String) -> Bool {
        guard employees.contains(where: { $0.id == employee.id }),
              employee.pin == pin else { return false }
        currentEmployeeID = employee.id
        profile = UserProfile(
            name: employee.name,
            position: employee.position,
            phone: employee.phone,
            permissions: employee.permissions
        )
        return true
    }

    func logout() {
        currentEmployeeID = nil
    }

    func addEmployee(_ employee: Employee) {
        employees.append(employee)
    }

    func updateEmployee(_ employee: Employee) {
        guard let index = employees.firstIndex(where: { $0.id == employee.id }) else { return }
        employees[index] = employee
        if currentEmployeeID == employee.id {
            profile = UserProfile(
                name: employee.name,
                position: employee.position,
                phone: employee.phone,
                permissions: employee.permissions
            )
        }
    }

    func deleteEmployee(_ employee: Employee) {
        employees.removeAll { $0.id == employee.id }
        if currentEmployeeID == employee.id { logout() }
    }

    // MARK: Kitchen Orders
    func addKitchenOrder(_ order: KitchenOrder) {
        kitchenOrders.append(order)
    }

    func advanceOrderStatus(_ order: KitchenOrder) {
        guard let idx = kitchenOrders.firstIndex(where: { $0.id == order.id }),
              let next = kitchenOrders[idx].status.next else { return }
        kitchenOrders[idx].status = next
        switch next {
        case .cooking: kitchenOrders[idx].cookingStartedAt = Date()
        case .ready:   kitchenOrders[idx].readyAt = Date()
        default: break
        }
    }

    func deleteKitchenOrder(_ order: KitchenOrder) {
        kitchenOrders.removeAll { $0.id == order.id }
    }

    func inventoryItem(forBarcode code: String) -> InventoryItem? {
        guard !code.isEmpty else { return nil }
        return inventoryItems.first { $0.barcode == code }
    }

    func archiveKitchenOrder(_ order: KitchenOrder) {
        kitchenOrders.removeAll { $0.id == order.id }
        closedKitchenOrders.insert(order, at: 0)
        if closedKitchenOrders.count > 100 {
            closedKitchenOrders = Array(closedKitchenOrders.prefix(100))
        }
    }

    // MARK: Shift
    func openShift() {
        currentShift = Shift(openedAt: Date(), openedBy: profile.name)
    }

    func closeShift() {
        guard var shift = currentShift else { return }
        shift.closedAt = Date()
        let since = shift.openedAt
        shift.productionsCount    = productions.filter { $0.date >= since }.count
        shift.writeOffsCount      = writeOffs.filter { $0.date >= since }.count
        shift.deliveriesCount     = deliveries.filter { $0.date >= since }.count
        shift.totalProductionCost = productions.filter { $0.date >= since }.reduce(0) { $0 + $1.totalCost }
        shift.totalDeliveryCost   = deliveries.filter { $0.date >= since }.reduce(0) { $0 + $1.price }
        shiftHistory.insert(shift, at: 0)
        currentShift = nil
    }

    func closeShiftWithRevenue(cashRevenue: Double, cardRevenue: Double, guestsCount: Int) {
        guard var shift = currentShift else { return }
        shift.closedAt = Date()
        let since = shift.openedAt
        shift.productionsCount    = productions.filter { $0.date >= since }.count
        shift.writeOffsCount      = writeOffs.filter { $0.date >= since }.count
        shift.deliveriesCount     = deliveries.filter { $0.date >= since }.count
        shift.totalProductionCost = productions.filter { $0.date >= since }.reduce(0) { $0 + $1.totalCost }
        shift.totalDeliveryCost   = deliveries.filter { $0.date >= since }.reduce(0) { $0 + $1.price }
        shift.cashRevenue  = cashRevenue
        shift.cardRevenue  = cardRevenue
        shift.revenue      = cashRevenue + cardRevenue
        shift.guestsCount  = guestsCount
        if shift.revenue > 0 {
            shift.foodCostForShift = (shift.totalProductionCost / shift.revenue) * 100
        }
        shiftHistory.insert(shift, at: 0)
        currentShift = nil
    }

    // MARK: Photo Storage

    private func resizeImage(_ data: Data, maxDimension: CGFloat = 1024) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            // Already small enough, just compress
            return image.jpegData(compressionQuality: 0.8) ?? data
        }
        let ratio = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    func saveDishPhoto(_ image: UIImage, for dish: Dish) {
        guard let rawData = image.jpegData(compressionQuality: 1.0) else { return }
        let data = resizeImage(rawData)
        let filename = "dish_\(dish.id.uuidString).jpg"
        let url = FileManager.default.documentsURL.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        if let idx = dishes.firstIndex(where: { $0.id == dish.id }) {
            dishes[idx].photoFilename = filename
        }
    }

    func loadDishPhoto(for dish: Dish) -> UIImage? {
        guard let filename = dish.photoFilename else { return nil }
        let url = FileManager.default.documentsURL.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    func deleteDishPhoto(for dish: Dish) {
        guard let filename = dish.photoFilename else { return }
        let url = FileManager.default.documentsURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        if let idx = dishes.firstIndex(where: { $0.id == dish.id }) {
            dishes[idx].photoFilename = nil
        }
    }

    // MARK: Step Photo Storage
    func saveStepPhoto(_ image: UIImage, for step: CookingStep, in dish: Dish) {
        guard let rawData = image.jpegData(compressionQuality: 1.0) else { return }
        let data = resizeImage(rawData)
        let filename = "step_\(step.id.uuidString).jpg"
        let url = FileManager.default.documentsURL.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        if let di = dishes.firstIndex(where: { $0.id == dish.id }),
           let si = dishes[di].steps.firstIndex(where: { $0.id == step.id }) {
            dishes[di].steps[si].photoFilename = filename
        }
    }

    func loadStepPhoto(for step: CookingStep) -> UIImage? {
        guard let filename = step.photoFilename else { return nil }
        let url = FileManager.default.documentsURL.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    func deleteStepPhoto(for step: CookingStep, in dish: Dish) {
        guard let filename = step.photoFilename else { return }
        let url = FileManager.default.documentsURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        if let di = dishes.firstIndex(where: { $0.id == dish.id }),
           let si = dishes[di].steps.firstIndex(where: { $0.id == step.id }) {
            dishes[di].steps[si].photoFilename = nil
        }
    }

    // MARK: Checklist CRUD
    func addChecklist(_ item: ChecklistItem) { checklists.append(item) }
    func updateChecklist(_ item: ChecklistItem) {
        if let i = checklists.firstIndex(where: { $0.id == item.id }) { checklists[i] = item }
    }
    func deleteChecklist(_ item: ChecklistItem) { checklists.removeAll { $0.id == item.id } }
    func resetChecklists(for type: ChecklistType) {
        for i in checklists.indices where checklists[i].type == type {
            checklists[i].isCompleted = false
            checklists[i].completedBy = ""
            checklists[i].completedAt = nil
        }
    }
    func completeChecklist(_ item: ChecklistItem, by employee: String) {
        if let i = checklists.firstIndex(where: { $0.id == item.id }) {
            checklists[i].isCompleted = true
            checklists[i].completedBy = employee
            checklists[i].completedAt = Date()
        }
    }

    private func loadDefaultChecklists() {
        let openingItems = [
            "Проверить температуру холодильников",
            "Принять доставку и проверить товар",
            "Подготовить рабочие станции",
            "Проверить наличие всех ингредиентов",
            "Включить оборудование и проверить работу",
            "Провести брифинг команды"
        ]
        let closingItems = [
            "Списать остатки по итогам смены",
            "Убрать и продезинфицировать рабочие места",
            "Проверить и отключить оборудование",
            "Закрыть холодильники и морозильные камеры",
            "Провести инвентаризацию на конец дня",
            "Оформить отчет о смене"
        ]
        for text in openingItems {
            checklists.append(ChecklistItem(text: text, type: .opening))
        }
        for text in closingItems {
            checklists.append(ChecklistItem(text: text, type: .closing))
        }
    }

    // MARK: Menu Collections CRUD
    func addCollection(_ c: MenuCollection) { menuCollections.append(c) }
    func updateCollection(_ c: MenuCollection) {
        if let i = menuCollections.firstIndex(where: { $0.id == c.id }) { menuCollections[i] = c }
    }
    func deleteCollection(_ c: MenuCollection) { menuCollections.removeAll { $0.id == c.id } }

    // MARK: Work Schedule CRUD
    func addWorkShift(_ s: WorkShift) { workSchedule.append(s) }
    func updateWorkShift(_ s: WorkShift) {
        if let i = workSchedule.firstIndex(where: { $0.id == s.id }) { workSchedule[i] = s }
    }
    func deleteWorkShift(_ s: WorkShift) { workSchedule.removeAll { $0.id == s.id } }

    // MARK: Backup
    func exportBackup() -> URL? {
        let backup = AppBackup(
            restaurantName: restaurantName,
            dishes: dishes,
            inventoryItems: inventoryItems,
            deliveries: deliveries,
            writeOffs: writeOffs,
            productions: productions,
            employees: employees,
            suppliers: suppliers,
            sales: sales,
            checklists: checklists,
            menuCollections: menuCollections,
            workSchedule: workSchedule,
            temperatureLogs: temperatureLogs,
            shiftHistory: shiftHistory
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(backup) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let filename = "ChefPro_backup_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return url
    }

    // MARK: iCloud Sync

    private var iCloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("chefpro_backup.json")
    }

    func syncToiCloud() {
        guard let url = iCloudURL,
              let backupURL = exportBackup() else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try? FileManager.default.copyItem(at: backupURL, to: url)
        UserDefaults.standard.set(Date(), forKey: "icloud_last_sync")
    }

    func syncFromiCloud(completion: @escaping (Bool) -> Void) {
        guard let url = iCloudURL,
              FileManager.default.fileExists(atPath: url.path) else {
            completion(false); return
        }
        DispatchQueue.global().async {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                do {
                    try self.importBackup(from: url)
                    UserDefaults.standard.set(Date(), forKey: "icloud_last_sync")
                    completion(true)
                } catch {
                    self.logError(error, context: "importBackup/iCloud")
                    completion(false)
                }
            }
        }
    }

    func importBackup(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackup.self, from: data)
        // backup.version is available for future format migrations.
        // Currently versions 1 and 2 share the same field layout;
        // add version-specific transforms here when introducing breaking changes.
        isSyncingFromCloud = true
        restaurantName   = backup.restaurantName
        dishes           = backup.dishes
        inventoryItems   = backup.inventoryItems
        deliveries       = backup.deliveries
        writeOffs        = backup.writeOffs
        productions      = backup.productions
        employees        = backup.employees
        suppliers        = backup.suppliers
        sales            = backup.sales
        checklists       = backup.checklists
        menuCollections  = backup.menuCollections
        workSchedule     = backup.workSchedule
        temperatureLogs  = backup.temperatureLogs
        shiftHistory     = backup.shiftHistory
        isSyncingFromCloud = false
        hapticNotification(.success)
    }

    // MARK: Spotlight
    func indexSpotlight() {
        var items: [CSSearchableItem] = []

        for dish in dishes {
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = dish.name
            attrs.contentDescription = "\(dish.category) · \(String(format: "%.2f", dish.salePrice)) · FC \(String(format: "%.1f", foodCostPercent(dish)))%"
            attrs.keywords = [dish.category, "блюдо", "техкарта"] + dish.allergens
            if let filename = dish.photoFilename {
                attrs.thumbnailURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            }
            let item = CSSearchableItem(
                uniqueIdentifier: "chefpro.dish.\(dish.id.uuidString)",
                domainIdentifier: "dishes",
                attributeSet: attrs
            )
            items.append(item)
        }

        for inv in inventoryItems {
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = inv.name
            attrs.contentDescription = "\(inv.category) · \(String(format: "%.1f", inv.quantity)) \(inv.unit)\(inv.isLowStock ? " · ⚠ Мало" : "")"
            attrs.keywords = [inv.category, "склад", "продукт"]
            let item = CSSearchableItem(
                uniqueIdentifier: "chefpro.inv.\(inv.id.uuidString)",
                domainIdentifier: "inventory",
                attributeSet: attrs
            )
            items.append(item)
        }

        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    func removeSpotlightIndex() {
        CSSearchableIndex.default().deleteAllSearchableItems { _ in }
    }

    // MARK: HACCP Reminders
    func scheduleHACCPReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["chefpro-haccp-reminder"])
        guard notificationsEnabled && haccpRemindersEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "HACCP: Запишите температуру"
        content.body  = "Время зафиксировать температуру холодильников и морозильников"
        content.sound = .default
        content.categoryIdentifier = "HACCP"
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Double(haccpIntervalHours) * 3600,
            repeats: true
        )
        center.add(UNNotificationRequest(
            identifier: "chefpro-haccp-reminder",
            content: content,
            trigger: trigger
        ))
    }

    // MARK: Recipe Versions
    func saveRecipeVersion(for dish: Dish, notes: String = "") {
        let version = RecipeVersion(
            dishID: dish.id,
            dishName: dish.name,
            savedBy: profile.name,
            ingredients: dish.ingredients,
            steps: dish.steps,
            salePrice: dish.salePrice,
            cookTime: dish.cookTime,
            notes: notes
        )
        recipeVersions.insert(version, at: 0)
        if recipeVersions.count > 50 { recipeVersions = Array(recipeVersions.prefix(50)) }
    }

    func versions(for dish: Dish) -> [RecipeVersion] {
        recipeVersions.filter { $0.dishID == dish.id }
    }

    func restoreVersion(_ version: RecipeVersion) {
        guard let idx = dishes.firstIndex(where: { $0.id == version.dishID }) else { return }
        dishes[idx].ingredients = version.ingredients
        dishes[idx].steps       = version.steps
        dishes[idx].salePrice   = version.salePrice
        dishes[idx].cookTime    = version.cookTime
        haptic(.medium)
    }

    func shiftsForEmployee(_ employeeID: UUID, in period: DateInterval) -> [WorkShift] {
        workSchedule.filter { $0.employeeID == employeeID && period.contains($0.date) }
    }

    // MARK: Temperature Log CRUD
    func addTemperatureLog(_ log: TemperatureLog) { temperatureLogs.insert(log, at: 0) }
    func deleteTemperatureLog(_ log: TemperatureLog) { temperatureLogs.removeAll { $0.id == log.id } }

    var temperatureLocations: [String] {
        let custom = Array(Set(temperatureLogs.map { $0.location })).sorted()
        let defaults = ["Холодильник 1", "Холодильник 2", "Морозильник"]
        return Array(Set(defaults + custom)).sorted()
    }

    func latestLog(for location: String) -> TemperatureLog? {
        temperatureLogs.filter { $0.location == location }.first
    }

    func toggleFavorite(_ dish: Dish) {
        guard let idx = dishes.firstIndex(where: { $0.id == dish.id }) else { return }
        dishes[idx].isFavorite.toggle()
    }

    // MARK: Sales
    func addSale(_ sale: Sale)    { sales.append(sale) }
    func deleteSale(_ sale: Sale) { sales.removeAll { $0.id == sale.id } }

    // MARK: Production Plan
    func addPlanItem(_ item: PlanItem)    { currentProductionPlan.append(item) }
    func removePlanItem(_ item: PlanItem) { currentProductionPlan.removeAll { $0.id == item.id } }
    func clearProductionPlan()            { currentProductionPlan.removeAll() }

    @discardableResult
    func executeProductionPlan() -> Int {
        var executed = 0
        for planItem in currentProductionPlan {
            guard let dish = dishes.first(where: { $0.id == planItem.dishID }) else { continue }
            if produceDish(dish, portions: planItem.portions) {
                sales.append(Sale(dishName: dish.name, portions: planItem.portions, date: Date(), employee: profile.name))
                executed += 1
            }
        }
        currentProductionPlan.removeAll()
        return executed
    }

    // MARK: Reservations
    func addReservation(_ r: TableReservation)    { reservations.append(r) }
    func updateReservation(_ r: TableReservation) { if let i = reservations.firstIndex(where: { $0.id == r.id }) { reservations[i] = r } }
    func deleteReservation(_ r: TableReservation) { reservations.removeAll { $0.id == r.id } }

    var todayReservations: [TableReservation] {
        let cal = Calendar.current
        return reservations
            .filter { cal.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    // MARK: Loyalty
    func addLoyaltyCard(_ c: LoyaltyCard)    { loyaltyCards.append(c) }
    func updateLoyaltyCard(_ c: LoyaltyCard) { if let i = loyaltyCards.firstIndex(where: { $0.id == c.id }) { loyaltyCards[i] = c } }
    func deleteLoyaltyCard(_ c: LoyaltyCard) { loyaltyCards.removeAll { $0.id == c.id } }

    func addPurchaseToLoyalty(cardID: UUID, amount: Double, description: String = "") {
        guard let idx = loyaltyCards.firstIndex(where: { $0.id == cardID }) else { return }
        let pts = Int(amount / 100)   // 1 балл за каждые 100₽
        let tx = LoyaltyTransaction(amount: amount, points: pts, description: description)
        loyaltyCards[idx].transactions.insert(tx, at: 0)
        loyaltyCards[idx].totalSpent  += amount
        loyaltyCards[idx].points      += pts
        loyaltyCards[idx].visitsCount += 1
        hapticNotification(.success)
    }

    func redeemLoyaltyPoints(cardID: UUID, points: Int) {
        guard let idx = loyaltyCards.firstIndex(where: { $0.id == cardID }),
              loyaltyCards[idx].points >= points else { return }
        let amount = Double(points)   // 1 балл = 1₽
        let tx = LoyaltyTransaction(amount: -amount, points: -points, description: "Списание баллов")
        loyaltyCards[idx].transactions.insert(tx, at: 0)
        loyaltyCards[idx].points -= points
        haptic(.medium)
    }

    func loyaltyCard(forPhone phone: String) -> LoyaltyCard? {
        loyaltyCards.first { $0.phone == phone }
    }

    // MARK: POS Records
    func addPOSRecord(_ r: POSSaleRecord)  { posRecords.append(r) }
    func deletePOSRecord(_ r: POSSaleRecord) { posRecords.removeAll { $0.id == r.id } }

    func importPOSRecords(_ records: [POSSaleRecord]) {
        posRecords.append(contentsOf: records)
        // Auto-create sales entries
        for record in records {
            sales.append(Sale(dishName: record.dishName, portions: record.quantity, date: record.date, employee: "POS Import"))
        }
        hapticNotification(.success)
    }

    // MARK: Suppliers
    func addSupplier(_ s: Supplier)    { suppliers.append(s) }
    func updateSupplier(_ s: Supplier) { if let i = suppliers.firstIndex(where: { $0.id == s.id }) { suppliers[i] = s } }
    func deleteSupplier(_ s: Supplier) { suppliers.removeAll { $0.id == s.id } }

    // MARK: Notifications
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async { self?.notificationsEnabled = granted }
        }
    }

    func scheduleNotificationsForLowStock() {
        guard notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for item in lowStockItems {
            let content = UNMutableNotificationContent()
            content.title = "Нужно заказать: \(item.name)"
            content.body  = "Осталось \(String(format: "%.1f", item.quantity)) \(item.unit), минимум \(String(format: "%.1f", item.minQuantity)) \(item.unit)"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            center.add(UNNotificationRequest(identifier: "lowstock-\(item.id)", content: content, trigger: trigger))
        }
        scheduleExpiryNotifications()
        scheduleDailyDigest()
    }

    func scheduleExpiryNotifications() {
        guard notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let warningDate = Calendar.current.date(byAdding: .day, value: expiryWarningDays, to: Date()) ?? Date()
        for item in inventoryItems {
            guard let expiry = item.expiryDate, expiry > Date(), expiry <= warningDate else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Срок годности: \(item.name)"
            let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
            content.body  = days == 0 ? "Истекает сегодня!" : "Истекает через \(days) дн."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            center.add(UNNotificationRequest(identifier: "expiry-\(item.id)", content: content, trigger: trigger))
        }
    }

    func scheduleDailyDigest() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["chefpro-daily-digest"])
        guard notificationsEnabled && dailyDigestEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Дайджест — \(restaurantName)"
        var parts: [String] = []
        if !lowStockItems.isEmpty  { parts.append("⚠ Заканчивается: \(lowStockItems.count) поз.") }
        if !expiringItems.isEmpty  { parts.append("📅 Срок годности: \(expiringItems.count) поз.") }
        if parts.isEmpty           { parts.append("✅ Всё в порядке") }
        content.body  = parts.joined(separator: " · ")
        content.sound = .default
        var dc = DateComponents(); dc.hour = 8; dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        center.add(UNNotificationRequest(identifier: "chefpro-daily-digest", content: content, trigger: trigger))
    }

    // MARK: Low Stock Notifications

    /// Schedules a local notification for each item that has fallen below its minimum quantity.
    /// Uses UserDefaults to track which items already received a notification today so we don't spam.
    func checkLowStockAndNotify() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            // Load the set of item IDs that were already notified today
            let today = Calendar.current.startOfDay(for: Date())
            let udKey = "chefpro_lowstock_notified_\(today.timeIntervalSince1970)"
            var notifiedIDs = Set(UserDefaults.standard.stringArray(forKey: udKey) ?? [])

            for item in self.inventoryItems {
                guard item.minQuantity > 0, item.quantity <= item.minQuantity else { continue }
                let idString = item.id.uuidString
                guard !notifiedIDs.contains(idString) else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Низкий остаток"
                content.body  = "\(item.name): осталось \(String(format: "%.1f", item.quantity)) \(item.unit)"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "lowstock_\(item.id.uuidString)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
                notifiedIDs.insert(idString)
            }

            UserDefaults.standard.set(Array(notifiedIDs), forKey: udKey)
        }
    }

    /// Removes a pending low-stock notification when an item's stock is replenished.
    func clearLowStockNotification(for item: InventoryItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["lowstock_\(item.id.uuidString)"]
        )
    }

    func calculateDishCost(_ dish: Dish) -> Double {
        dish.ingredients.reduce(0) { total, ingredient in
            // 1. Check if ingredient is a semi-finished product (another dish)
            if let semifinished = dishes.first(where: {
                $0.dishType == .semifinished &&
                $0.name.lowercased() == ingredient.productName.lowercased()
            }) {
                let sfCost = calculateDishCost(semifinished)  // recursive call
                let weight = semifinished.portionWeight > 0 ? semifinished.portionWeight : 1.0
                let rawQty = ingredient.yieldFactor > 0 ? ingredient.quantity / ingredient.yieldFactor : ingredient.quantity
                return total + (rawQty / weight) * sfCost
            }
            // 2. Otherwise look up inventory item
            guard let item = inventoryItems.first(where: {
                $0.name.lowercased() == ingredient.productName.lowercased()
            }) else {
                return total
            }
            let rawQty = ingredient.yieldFactor > 0 ? ingredient.quantity / ingredient.yieldFactor : ingredient.quantity
            let convertedQuantity = convert(quantity: rawQty, from: ingredient.unit, to: item.unit)
            return total + (convertedQuantity * item.pricePerUnit)
        }
    }

    func foodCostPercent(_ dish: Dish) -> Double {
        guard dish.salePrice > 0 else { return 0 }
        return calculateDishCost(dish) / dish.salePrice * 100
    }

    func canProduce(dish: Dish, portions: Int) -> Bool {
        for ingredient in dish.ingredients {
            guard let index = inventoryItems.firstIndex(where: {
                $0.name.lowercased() == ingredient.productName.lowercased()
            }) else {
                return false
            }

            let item = inventoryItems[index]
            let needed = convert(quantity: ingredient.quantity * Double(portions), from: ingredient.unit, to: item.unit)

            if item.quantity < needed {
                return false
            }
        }

        return true
    }

    func produceDish(_ dish: Dish, portions: Int) -> Bool {
        guard portions >= 1 else { return false }
        guard canProduce(dish: dish, portions: portions) else {
            hapticNotification(.error)
            return false
        }

        // Snapshot cost at current prices before any inventory is modified
        let snapshotCost = calculateDishCost(dish) * Double(portions)

        for ingredient in dish.ingredients {
            if let index = inventoryItems.firstIndex(where: {
                $0.name.lowercased() == ingredient.productName.lowercased()
            }) {
                let item = inventoryItems[index]
                let needed = convert(quantity: ingredient.quantity * Double(portions), from: ingredient.unit, to: item.unit)
                inventoryItems[index].quantity -= needed

                stockMovements.append(StockMovement(
                    itemName: item.name,
                    itemID: item.id,
                    type: .production,
                    quantity: needed,
                    unit: item.unit,
                    note: "Производство: \(dish.name) x\(portions)"
                ))

                let writeOff = WriteOff(
                    productName: item.name,
                    quantity: needed,
                    unit: item.unit,
                    reason: "Автосписание: \(dish.name) x\(portions)",
                    employee: profile.name,
                    date: Date()
                )
                writeOffs.append(writeOff)
            }
        }

        let production = Production(
            dishName: dish.name,
            portions: portions,
            totalCost: snapshotCost,
            date: Date(),
            employee: profile.name
        )

        productions.append(production)

        // Если это полуфабрикат — добавить выход на склад
        if dish.dishType == .semifinished && dish.portionWeight > 0 {
            let produced = dish.portionWeight * Double(portions)
            if let idx = inventoryItems.firstIndex(where: { $0.sourceDishID == dish.id }) {
                inventoryItems[idx].quantity += produced
            }
        }

        checkLowStockAndNotify()
        hapticNotification(.success)
        return true
    }

    func convert(quantity: Double, from sourceUnit: String, to targetUnit: String) -> Double {
        if sourceUnit == targetUnit { return quantity }

        if sourceUnit == "г" && targetUnit == "кг" { return quantity / 1000 }
        if sourceUnit == "кг" && targetUnit == "г" { return quantity * 1000 }
        if sourceUnit == "мл" && targetUnit == "л" { return quantity / 1000 }
        if sourceUnit == "л" && targetUnit == "мл" { return quantity * 1000 }

        // Incompatible standard units (e.g. г↔мл) — return 0 to avoid silently wrong cost calculations
        let standardUnits: Set<String> = ["г", "кг", "мл", "л", "шт"]
        if standardUnits.contains(sourceUnit) && standardUnits.contains(targetUnit) {
            return 0
        }

        return quantity
    }

    func addDelivery(_ delivery: Delivery) {
        haptic(.light)
        deliveries.append(delivery)

        let movement = StockMovement(
            itemName: delivery.productName,
            type: .delivery,
            quantity: delivery.quantity,
            unit: delivery.unit,
            date: delivery.date,
            note: "От: \(delivery.supplier)"
        )
        stockMovements.append(movement)

        let deliveryPricePerUnit = delivery.quantity > 0 ? delivery.price / delivery.quantity : 0

        if let index = inventoryItems.firstIndex(where: {
            $0.name.lowercased() == delivery.productName.lowercased() && $0.unit == delivery.unit
        }) {
            if deliveryPricePerUnit > 0 {
                let currentValue = inventoryItems[index].quantity * inventoryItems[index].pricePerUnit
                let newValue     = delivery.quantity * deliveryPricePerUnit
                let combinedQty  = inventoryItems[index].quantity + delivery.quantity
                inventoryItems[index].pricePerUnit = combinedQty > 0 ? (currentValue + newValue) / combinedQty : deliveryPricePerUnit
                inventoryItems[index].priceHistory.append(PricePoint(date: delivery.date, price: deliveryPricePerUnit))
            }
            inventoryItems[index].quantity += delivery.quantity
            // Clear low stock notification if quantity is now above minimum
            let updatedItem = inventoryItems[index]
            if updatedItem.quantity > updatedItem.minQuantity {
                clearLowStockNotification(for: updatedItem)
            }
        } else {
            var newItem = InventoryItem(
                name: delivery.productName,
                category: delivery.category.isEmpty ? "Без категории" : delivery.category,
                quantity: delivery.quantity,
                unit: delivery.unit,
                minQuantity: 1,
                pricePerUnit: deliveryPricePerUnit
            )
            if deliveryPricePerUnit > 0 {
                newItem.priceHistory = [PricePoint(date: delivery.date, price: deliveryPricePerUnit)]
            }
            inventoryItems.append(newItem)
        }
    }

    func addWriteOff(_ writeOff: WriteOff) {
        haptic(.medium)
        writeOffs.append(writeOff)

        let movement = StockMovement(
            itemName: writeOff.productName,
            type: .writeOff,
            quantity: writeOff.quantity,
            unit: writeOff.unit,
            date: writeOff.date,
            note: writeOff.reason
        )
        stockMovements.append(movement)

        if let index = inventoryItems.firstIndex(where: {
            $0.name.lowercased() == writeOff.productName.lowercased() && $0.unit == writeOff.unit
        }) {
            // Allow inventory to go negative so accounting discrepancies are visible, not silently hidden
            inventoryItems[index].quantity -= writeOff.quantity
        }
        checkLowStockAndNotify()
    }

    // MARK: Haptics

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    func addDish(_ dish: Dish) {
        dishes.append(dish)
        if dish.dishType == .semifinished {
            syncSemifinishedInventoryItem(for: dish)
        }
        haptic(.medium)
    }

    func updateDish(_ updatedDish: Dish) {
        guard let index = dishes.firstIndex(where: { $0.id == updatedDish.id }) else { return }
        let oldDish = dishes[index]
        dishes[index] = updatedDish

        if updatedDish.dishType == .semifinished {
            // Create or update the inventory item
            syncSemifinishedInventoryItem(for: updatedDish)
        } else if oldDish.dishType == .semifinished {
            // Was semifinished, now changed to dish — remove from inventory
            inventoryItems.removeAll { $0.sourceDishID == updatedDish.id }
        }
        haptic(.medium)
    }

    func deleteDish(_ dish: Dish) {
        dishes.removeAll { $0.id == dish.id }
        if dish.dishType == .semifinished {
            inventoryItems.removeAll { $0.sourceDishID == dish.id }
        }
        haptic(.heavy)
    }

    /// Creates or updates the InventoryItem linked to a semi-finished dish.
    private func syncSemifinishedInventoryItem(for dish: Dish) {
        let unit = dish.portionWeightUnit.isEmpty ? "г" : dish.portionWeightUnit
        let costPerUnit = dish.portionWeight > 0
            ? calculateDishCost(dish) / dish.portionWeight
            : calculateDishCost(dish)

        if let idx = inventoryItems.firstIndex(where: { $0.sourceDishID == dish.id }) {
            // Update existing
            inventoryItems[idx].name = dish.name
            inventoryItems[idx].unit = unit
            inventoryItems[idx].pricePerUnit = costPerUnit
        } else {
            // Create new
            let item = InventoryItem(
                name: dish.name,
                category: "Полуфабрикаты",
                quantity: 0,
                unit: unit,
                minQuantity: 0,
                pricePerUnit: costPerUnit,
                sourceDishID: dish.id
            )
            inventoryItems.append(item)
        }
    }

    func updateInventoryItem(_ updatedItem: InventoryItem) {
        if let index = inventoryItems.firstIndex(where: { $0.id == updatedItem.id }) {
            inventoryItems[index] = updatedItem
        }
    }

    func deleteInventoryItem(_ item: InventoryItem) {
        inventoryItems.removeAll { $0.id == item.id }
    }

    func resetDemoData() {
        dishes.removeAll()
        inventoryItems.removeAll()
        deliveries.removeAll()
        writeOffs.removeAll()
        productions.removeAll()
        employees.removeAll()
        currentEmployeeID = nil
        profile = UserProfile(
            name: "Иван Петров",
            position: "Шеф-повар",
            phone: "+47 000 00 000",
            permissions: ["Техкарты", "Склад", "Приемка", "Списания", "Отчеты", "Настройки"]
        )
        loadDemoEmployees()
        loadDemoData()
    }

    private func loadDemoEmployees() {
        employees = [
            Employee(name: "Иван Петров", position: "Шеф-повар", phone: "+47 000 00 000", pin: "1111", permissions: ["Техкарты", "Склад", "Приемка", "Списания", "Отчеты", "Настройки"]),
            Employee(name: "Анна Смирнова", position: "Су-шеф", phone: "+47 111 11 111", pin: "2222", permissions: ["Техкарты", "Склад", "Списания", "Отчеты"]),
            Employee(name: "Олег Иванов", position: "Кладовщик", phone: "+47 222 22 222", pin: "3333", permissions: ["Склад", "Приемка", "Списания"]),
            Employee(name: "Мария Кузнецова", position: "Администратор", phone: "+47 333 33 333", pin: "4444", permissions: ["Отчеты", "Настройки"])
        ]
    }

    /// Public method to load comprehensive demo data if store is empty.
    func populateDemoData() {
        guard dishes.isEmpty && inventoryItems.isEmpty else { return }
        loadExtendedDemoData()
    }

    private func loadExtendedDemoData() {
        inventoryItems = [
            InventoryItem(name: "Мука", category: "Бакалея", quantity: 10, unit: "кг", minQuantity: 3, pricePerUnit: 1.2),
            InventoryItem(name: "Молоко", category: "Молочные продукты", quantity: 8, unit: "л", minQuantity: 2, pricePerUnit: 1.5),
            InventoryItem(name: "Яйца", category: "Молочные продукты", quantity: 30, unit: "шт", minQuantity: 12, pricePerUnit: 0.4),
            InventoryItem(name: "Масло сливочное", category: "Молочные продукты", quantity: 2, unit: "кг", minQuantity: 0.5, pricePerUnit: 12.0),
            InventoryItem(name: "Говядина", category: "Мясо", quantity: 5, unit: "кг", minQuantity: 2, pricePerUnit: 22.0),
            InventoryItem(name: "Помидоры", category: "Овощи", quantity: 4, unit: "кг", minQuantity: 1, pricePerUnit: 2.5),
            InventoryItem(name: "Сыр", category: "Молочные продукты", quantity: 2, unit: "кг", minQuantity: 0.5, pricePerUnit: 9.5),
            InventoryItem(name: "Сахар", category: "Бакалея", quantity: 5, unit: "кг", minQuantity: 1, pricePerUnit: 1.0),
            InventoryItem(name: "Рис", category: "Бакалея", quantity: 12, unit: "кг", minQuantity: 5, pricePerUnit: 2.2),
            InventoryItem(name: "Лосось", category: "Рыба", quantity: 4, unit: "кг", minQuantity: 3, pricePerUnit: 18.5),
            InventoryItem(name: "Курица", category: "Мясо", quantity: 8, unit: "кг", minQuantity: 5, pricePerUnit: 6.8),
            InventoryItem(name: "Нори", category: "Суши", quantity: 50, unit: "шт", minQuantity: 10, pricePerUnit: 0.25),
            InventoryItem(name: "Салат", category: "Овощи", quantity: 6, unit: "кг", minQuantity: 2, pricePerUnit: 3.1),
            InventoryItem(name: "Соус", category: "Соусы", quantity: 3, unit: "кг", minQuantity: 1, pricePerUnit: 5.4),
            InventoryItem(name: "Маскарпоне", category: "Молочные продукты", quantity: 1.5, unit: "кг", minQuantity: 0.5, pricePerUnit: 14.0),
            InventoryItem(name: "Кофе эспрессо", category: "Напитки", quantity: 1, unit: "л", minQuantity: 0.3, pricePerUnit: 6.0),
            InventoryItem(name: "Тесто для пиццы", category: "Бакалея", quantity: 3, unit: "кг", minQuantity: 1, pricePerUnit: 4.0)
        ]

        dishes = [
            Dish(
                name: "Борщ",
                category: "Супы",
                salePrice: 8.90,
                ingredients: [
                    RecipeIngredient(productName: "Говядина", quantity: 200, unit: "г"),
                    RecipeIngredient(productName: "Помидоры", quantity: 100, unit: "г"),
                    RecipeIngredient(productName: "Масло сливочное", quantity: 20, unit: "г")
                ],
                cookTime: 90
            ),
            Dish(
                name: "Пицца Маргарита",
                category: "Пицца",
                salePrice: 13.50,
                ingredients: [
                    RecipeIngredient(productName: "Тесто для пиццы", quantity: 250, unit: "г"),
                    RecipeIngredient(productName: "Помидоры", quantity: 150, unit: "г"),
                    RecipeIngredient(productName: "Сыр", quantity: 100, unit: "г")
                ],
                cookTime: 20
            ),
            Dish(
                name: "Тирамису",
                category: "Десерты",
                salePrice: 9.90,
                ingredients: [
                    RecipeIngredient(productName: "Маскарпоне", quantity: 250, unit: "г"),
                    RecipeIngredient(productName: "Яйца", quantity: 3, unit: "шт"),
                    RecipeIngredient(productName: "Сахар", quantity: 80, unit: "г"),
                    RecipeIngredient(productName: "Кофе эспрессо", quantity: 100, unit: "мл")
                ],
                cookTime: 30
            ),
            Dish(
                name: "Стейк Рибай",
                category: "Горячее",
                salePrice: 32.00,
                ingredients: [
                    RecipeIngredient(productName: "Говядина", quantity: 350, unit: "г"),
                    RecipeIngredient(productName: "Масло сливочное", quantity: 30, unit: "г")
                ],
                cookTime: 15
            ),
            Dish(
                name: "Паста Карбонара",
                category: "Паста",
                salePrice: 14.90,
                ingredients: [
                    RecipeIngredient(productName: "Яйца", quantity: 2, unit: "шт"),
                    RecipeIngredient(productName: "Сыр", quantity: 60, unit: "г"),
                    RecipeIngredient(productName: "Масло сливочное", quantity: 20, unit: "г")
                ],
                cookTime: 20
            ),
            Dish(
                name: "Филадельфия ролл",
                category: "Суши",
                salePrice: 14.90,
                ingredients: [
                    RecipeIngredient(productName: "Рис", quantity: 120, unit: "г"),
                    RecipeIngredient(productName: "Лосось", quantity: 60, unit: "г"),
                    RecipeIngredient(productName: "Сыр", quantity: 35, unit: "г"),
                    RecipeIngredient(productName: "Нори", quantity: 1, unit: "шт")
                ]
            ),
            Dish(
                name: "Цезарь с курицей",
                category: "Салаты",
                salePrice: 12.50,
                ingredients: [
                    RecipeIngredient(productName: "Курица", quantity: 120, unit: "г"),
                    RecipeIngredient(productName: "Салат", quantity: 80, unit: "г"),
                    RecipeIngredient(productName: "Соус", quantity: 40, unit: "г"),
                    RecipeIngredient(productName: "Сыр", quantity: 20, unit: "г")
                ]
            )
        ]

        suppliers = [
            Supplier(name: "ООО Продукты", phone: "+7 800 555 0101", email: "info@ooo-produkty.ru", notes: "Основной поставщик сухих продуктов"),
            Supplier(name: "ИП Молочник", phone: "+7 800 555 0202", email: "molochnik@mail.ru", notes: "Молочная продукция и яйца")
        ]

        if employees.isEmpty {
            employees = [
                Employee(name: "Иван Иванов", position: "Шеф-повар", phone: "+7 900 000 0001", pin: "1111",
                         permissions: ["Техкарты", "Склад", "Приемка", "Списания", "Отчеты", "Настройки"])
            ]
        }

        deliveries = [
            Delivery(supplier: "ООО Продукты", productName: "Мука", quantity: 10, unit: "кг", price: 12.0, date: Date(), acceptedBy: "Иван Иванов")
        ]

        writeOffs = []
        productions = []
    }

    private func loadDemoData() {
        inventoryItems = [
            InventoryItem(name: "Рис", category: "Бакалея", quantity: 12, unit: "кг", minQuantity: 5, pricePerUnit: 2.2),
            InventoryItem(name: "Лосось", category: "Рыба", quantity: 4, unit: "кг", minQuantity: 3, pricePerUnit: 18.5),
            InventoryItem(name: "Курица", category: "Мясо", quantity: 8, unit: "кг", minQuantity: 5, pricePerUnit: 6.8),
            InventoryItem(name: "Сыр", category: "Молочные продукты", quantity: 2, unit: "кг", minQuantity: 3, pricePerUnit: 9.5),
            InventoryItem(name: "Нори", category: "Суши", quantity: 50, unit: "шт", minQuantity: 10, pricePerUnit: 0.25),
            InventoryItem(name: "Салат", category: "Овощи", quantity: 6, unit: "кг", minQuantity: 2, pricePerUnit: 3.1),
            InventoryItem(name: "Соус", category: "Соусы", quantity: 3, unit: "кг", minQuantity: 1, pricePerUnit: 5.4)
        ]

        dishes = [
            Dish(
                name: "Филадельфия ролл",
                category: "Суши",
                salePrice: 14.90,
                ingredients: [
                    RecipeIngredient(productName: "Рис", quantity: 120, unit: "г"),
                    RecipeIngredient(productName: "Лосось", quantity: 60, unit: "г"),
                    RecipeIngredient(productName: "Сыр", quantity: 35, unit: "г"),
                    RecipeIngredient(productName: "Нори", quantity: 1, unit: "шт")
                ]
            ),
            Dish(
                name: "Цезарь с курицей",
                category: "Салаты",
                salePrice: 12.50,
                ingredients: [
                    RecipeIngredient(productName: "Курица", quantity: 120, unit: "г"),
                    RecipeIngredient(productName: "Салат", quantity: 80, unit: "г"),
                    RecipeIngredient(productName: "Соус", quantity: 40, unit: "г"),
                    RecipeIngredient(productName: "Сыр", quantity: 20, unit: "г")
                ]
            )
        ]

        deliveries = [
            Delivery(supplier: "Fresh Fish", productName: "Лосось", quantity: 5, unit: "кг", price: 92.50, date: Date(), acceptedBy: "Кладовщик")
        ]

        writeOffs = []
        productions = []
    }

    private func saveData() {
        guard !isLoading else { return }
        save(dishes, key: dishesKey)
        save(inventoryItems, key: inventoryKey)
        save(deliveries, key: deliveriesKey)
        save(writeOffs, key: writeOffsKey)
        save(productions, key: productionsKey)
        save(profile, key: profileKey)
        save(employees, key: employeesKey)
        save(kitchenOrders, key: kitchenOrdersKey)
        save(closedKitchenOrders, key: closedKitchenOrdersKey)
        save(suppliers, key: suppliersKey)
        save(currentShift, key: currentShiftKey)
        save(shiftHistory, key: shiftHistoryKey)
        save(sales, key: salesKey)
        save(currentProductionPlan, key: productionPlanKey)
        UserDefaults.standard.set(foodCostThreshold,    forKey: foodCostThresholdKey)
        UserDefaults.standard.set(purchaseBudget,       forKey: purchaseBudgetKey)
        UserDefaults.standard.set(monthlyRevenuePlan,   forKey: monthlyRevenuePlanKey)
        UserDefaults.standard.set(monthlyFoodCostTarget, forKey: monthlyFoodCostTargetKey)
        UserDefaults.standard.set(expiryWarningDays,    forKey: expiryWarningDaysKey)
        UserDefaults.standard.set(dailyDigestEnabled,   forKey: dailyDigestKey)
        UserDefaults.standard.set(haccpRemindersEnabled, forKey: haccpRemindersKey)
        UserDefaults.standard.set(haccpIntervalHours,    forKey: haccpIntervalHoursKey)
        UserDefaults.standard.set(hasSeenOnboarding,    forKey: hasSeenOnboardingKey)
        UserDefaults.standard.set(restaurantName,       forKey: restaurantNameKey)
        UserDefaults.standard.set(appColorScheme.rawValue, forKey: appColorSchemeKey)
        UserDefaults.standard.set(notificationsEnabled, forKey: notificationsEnabledKey)

        if let currentEmployeeID {
            UserDefaults.standard.set(currentEmployeeID.uuidString, forKey: currentEmployeeIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: currentEmployeeIDKey)
        }

        save(checklists, key: checklistsKey)
        save(menuCollections, key: collectionsKey)
        save(workSchedule, key: workScheduleKey)
        save(temperatureLogs, key: temperatureLogsKey)
        save(recipeVersions, key: recipeVersionsKey)
        save(stockMovements, key: stockMovementsKey)
        save(reservations, key: reservationsKey)
        save(loyaltyCards,  key: loyaltyCardsKey)
        save(posRecords,    key: posRecordsKey)
        UserDefaults.standard.set(appLanguage.rawValue, forKey: appLanguageKey)
        writeWidgetSharedData()
        indexSpotlight()
        checkLowStockAndNotify()
        scheduleUpload()
        syncToiCloud()
    }

    // MARK: - Widget Shared Data

    /// Writes summary data to the shared App Group UserDefaults so the widget extension can read it.
    private func writeWidgetSharedData() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.ChefPro") else { return }

        // Average food cost across all active dishes with a non-zero sale price
        let activeDishes = dishes.filter { $0.salePrice > 0 }
        let avgFoodCost: Double
        if activeDishes.isEmpty {
            avgFoodCost = 0
        } else {
            let total = activeDishes.reduce(0.0) { $0 + foodCostPercent($1) }
            avgFoodCost = total / Double(activeDishes.count)
        }

        sharedDefaults.set(avgFoodCost, forKey: "widget_food_cost_percent")
        sharedDefaults.set(lowStockItems.count, forKey: "widget_low_stock_count")
        sharedDefaults.set(restaurantName, forKey: "widget_restaurant_name")

        // Ask WidgetKit to reload all timelines so the widget reflects fresh data
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // Debounced auto-upload: waits 4 s after the last change before sending to Firestore
    private func scheduleUpload() {
        guard !isSyncingFromCloud else { return }
        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await self.syncToCloud()
        }
    }

    @MainActor
    func syncToCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        do {
            try await ChefProFirebaseService.shared.uploadAll(
                dishes: dishes,
                inventoryItems: inventoryItems,
                deliveries: deliveries,
                writeOffs: writeOffs,
                productions: productions,
                employees: employees,
                profile: profile
            )
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
        } catch {
            syncError = error.localizedDescription
            logError(error, context: "syncToCloud")
        }
        isSyncing = false
    }

    @MainActor
    func syncFromCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        isSyncingFromCloud = true
        syncError = nil
        do {
            let data = try await ChefProFirebaseService.shared.downloadAll()
            if !data.dishes.isEmpty        { dishes = data.dishes }
            if !data.inventoryItems.isEmpty { inventoryItems = data.inventoryItems }
            if !data.deliveries.isEmpty    { deliveries = data.deliveries }
            if !data.writeOffs.isEmpty     { writeOffs = data.writeOffs }
            if !data.productions.isEmpty   { productions = data.productions }
            if !data.employees.isEmpty     { employees = data.employees }
            if let p = data.profile        { profile = p }
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
        } catch {
            syncError = error.localizedDescription
            logError(error, context: "syncFromCloud")
        }
        isSyncingFromCloud = false
        isSyncing = false
    }

    private func loadData() {
        isLoading = true
        defer { isLoading = false }
        dishes = load([Dish].self, key: dishesKey) ?? []
        inventoryItems = load([InventoryItem].self, key: inventoryKey) ?? []
        deliveries = load([Delivery].self, key: deliveriesKey) ?? []
        writeOffs = load([WriteOff].self, key: writeOffsKey) ?? []
        productions = load([Production].self, key: productionsKey) ?? []
        profile = load(UserProfile.self, key: profileKey) ?? profile
        employees = load([Employee].self, key: employeesKey) ?? []
        kitchenOrders       = load([KitchenOrder].self, key: kitchenOrdersKey) ?? []
        closedKitchenOrders = load([KitchenOrder].self, key: closedKitchenOrdersKey) ?? []
        suppliers           = load([Supplier].self, key: suppliersKey) ?? []
        currentShift        = load(Shift.self, key: currentShiftKey)
        shiftHistory        = load([Shift].self, key: shiftHistoryKey) ?? []
        sales               = load([Sale].self, key: salesKey) ?? []
        currentProductionPlan = load([PlanItem].self, key: productionPlanKey) ?? []
        let storedThreshold = UserDefaults.standard.double(forKey: foodCostThresholdKey)
        foodCostThreshold   = storedThreshold > 0 ? storedThreshold : 35
        purchaseBudget      = UserDefaults.standard.double(forKey: purchaseBudgetKey)
        monthlyRevenuePlan  = UserDefaults.standard.double(forKey: monthlyRevenuePlanKey)
        let fc = UserDefaults.standard.double(forKey: monthlyFoodCostTargetKey)
        monthlyFoodCostTarget = fc > 0 ? fc : 30
        let storedDays      = UserDefaults.standard.integer(forKey: expiryWarningDaysKey)
        expiryWarningDays   = storedDays > 0 ? storedDays : 3
        dailyDigestEnabled  = UserDefaults.standard.bool(forKey: dailyDigestKey)
        haccpRemindersEnabled = UserDefaults.standard.bool(forKey: haccpRemindersKey)
        let storedHACCP = UserDefaults.standard.integer(forKey: haccpIntervalHoursKey)
        haccpIntervalHours = storedHACCP > 0 ? storedHACCP : 4
        hasSeenOnboarding   = UserDefaults.standard.bool(forKey: hasSeenOnboardingKey)
        restaurantName      = UserDefaults.standard.string(forKey: restaurantNameKey) ?? "Demo Restaurant"
        notificationsEnabled = UserDefaults.standard.bool(forKey: notificationsEnabledKey)
        if let raw = UserDefaults.standard.string(forKey: appColorSchemeKey),
           let scheme = AppColorScheme(rawValue: raw) { appColorScheme = scheme }

        checklists      = load([ChecklistItem].self, key: checklistsKey) ?? []
        menuCollections = load([MenuCollection].self, key: collectionsKey) ?? []
        workSchedule    = load([WorkShift].self, key: workScheduleKey) ?? []
        temperatureLogs = load([TemperatureLog].self, key: temperatureLogsKey) ?? []
        recipeVersions  = load([RecipeVersion].self, key: recipeVersionsKey) ?? []
        stockMovements  = load([StockMovement].self, key: stockMovementsKey) ?? []
        reservations    = load([TableReservation].self, key: reservationsKey) ?? []
        loyaltyCards    = load([LoyaltyCard].self,      key: loyaltyCardsKey) ?? []
        posRecords      = load([POSSaleRecord].self,     key: posRecordsKey) ?? []
        if let raw = UserDefaults.standard.string(forKey: appLanguageKey),
           let lang = AppLanguage(rawValue: raw) { appLanguage = lang }
        if let idString = UserDefaults.standard.string(forKey: currentEmployeeIDKey) {
            currentEmployeeID = UUID(uuidString: idString)
        }
    }

    private func save<T: Codable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
