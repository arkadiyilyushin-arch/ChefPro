import SwiftUI

// MARK: - More

struct MoreView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(spacing: 20) {
                    MoreProfileCard(store: store)
                    MoreQuickGrid(store: store)
                    MoreSectionBlock(title: "Аналитика", color: .blue) {
                        MoreRow("Аналитика",            icon: "chart.line.uptrend.xyaxis",          color: .blue) { AnalyticsView().environmentObject(store) }
                        MoreRow("Menu Engineering",     icon: "chart.bar.xaxis",                    color: .blue) { MenuEngineeringView().environmentObject(store) }
                        MoreRow("Продажи",              icon: "bag.fill",                           color: .blue, badge: store.sales.isEmpty ? nil : "\(store.sales.count)") { SalesView().environmentObject(store) }
                        MoreRow("P&L",                  icon: "chart.line.uptrend.xyaxis.circle.fill", color: .blue) { ProfitLossView().environmentObject(store) }
                        MoreRow("Операц. расходы",      icon: "creditcard.fill",                    color: .blue, badge: store.operatingExpenses.isEmpty ? nil : "\(store.operatingExpenses.count)") { OperatingExpensesView().environmentObject(store) }
                        MoreRow("Динамика Food Cost",   icon: "waveform.path.ecg",                  color: .blue) { FoodCostTrendView().environmentObject(store) }
                        MoreRow("FC по периодам",       icon: "calendar.badge.clock",               color: .blue) { FoodCostByPeriodView().environmentObject(store) }
                        MoreRow("Топ-10 затрат",        icon: "flame.fill",                         color: .blue) { TopDishCostView().environmentObject(store) }
                        MoreRow("План vs Факт",         icon: "chart.bar.xaxis",                    color: .blue) { PlanVsFactView().environmentObject(store) }
                        MoreRow("Бюджет закупок",       icon: "chart.bar.doc.horizontal",           color: .blue) { PurchaseBudgetView().environmentObject(store) }
                        MoreRow("Поставщики (аналит.)", icon: "building.2.crop.circle.fill",        color: .blue) { SupplierAnalyticsView().environmentObject(store) }
                        MoreRow("ABC-анализ склада",    icon: "chart.bar.doc.horizontal",           color: .blue) { ABCAnalysisView().environmentObject(store) }
                        MoreRow("Точка безубыточности", icon: "chart.line.uptrend.xyaxis",          color: .blue) { BreakevenView().environmentObject(store) }
                        MoreRow("Отчеты",               icon: "chart.bar.fill",                     color: .blue) { PermissionGate(permission: "Отчеты") { ReportsView() }.environmentObject(store) }
                        MoreRow("PDF-отчеты",           icon: "doc.richtext.fill",                  color: .blue) { PDFReportsView().environmentObject(store) }
                        MoreRow("Отчёт по списаниям",   icon: "chart.bar.doc.horizontal.fill",      color: .blue) { WriteOffReportView().environmentObject(store) }
                        MoreRow("CSV-экспорт",          icon: "tablecells",                         color: .blue) { CSVExportView().environmentObject(store) }
                        MoreRow("Прогноз закупок",      icon: "chart.line.downtrend.xyaxis",        color: .blue) { PurchaseForecastView().environmentObject(store) }
                    }
                    MoreSectionBlock(title: "Инструменты", color: .orange) {
                        MoreRow("Срок годности",        icon: "calendar.badge.exclamationmark", color: .orange,
                                badge: store.expiringItems.isEmpty ? nil : "\(store.expiringItems.count)") { ExpiryWatchlistView().environmentObject(store) }
                        MoreRow("История движений",     icon: "clock.arrow.circlepath",         color: .orange) { StockMovementsView().environmentObject(store) }
                        MoreRow("Инвентаризация",       icon: "list.clipboard.fill",            color: .orange) { InventoryAuditView().environmentObject(store) }
                        MoreRow("Шаблоны техкарт",      icon: "doc.text.fill",                  color: .orange) { RecipeTemplatesView().environmentObject(store) }
                        MoreRow("Калькулятор цены",     icon: "percent",                         color: .orange) { PriceCalculatorView().environmentObject(store) }
                        MoreRow("Калькулятор наценки",  icon: "arrow.up.right.circle.fill",     color: .orange) { MarkupCalculatorView().environmentObject(store) }
                        MoreRow("Рейтинг прибыльности", icon: "trophy.fill",                    color: .orange) { ProfitabilityRankingView().environmentObject(store) }
                        MoreRow("Галерея блюд",         icon: "photo.stack.fill",               color: .orange,
                                badge: { let c = store.dishes.filter { $0.photoFilename != nil }.count; return c > 0 ? "\(c)" : nil }()) { DishGalleryView().environmentObject(store) }
                        MoreRow("План производства",    icon: "calendar.badge.clock",           color: .orange,
                                badge: store.currentProductionPlan.isEmpty ? nil : "\(store.currentProductionPlan.count)") { ProductionPlanView().environmentObject(store) }
                        MoreRow("Цифровое меню",        icon: "menucard.fill",                  color: .orange) { DigitalMenuView().environmentObject(store) }
                        MoreRow("Поиск",                icon: "magnifyingglass",                 color: .orange) { GlobalSearchView().environmentObject(store) }
                        MoreRow("QR / Barcode",         icon: "barcode.viewfinder",             color: .orange) { BarcodeScannerView().environmentObject(store) }
                        MoreRow("Конвертер единиц",     icon: "arrow.left.arrow.right",         color: .orange) { UnitConverterView() }
                    }
                    MoreSectionBlock(title: "Персонал", color: .purple) {
                        MoreRow("График работы",        icon: "calendar.badge.clock",       color: .purple) { WorkScheduleView().environmentObject(store) }
                        MoreRow("Активность",           icon: "person.badge.clock.fill",    color: .purple) { EmployeeActivityView().environmentObject(store) }
                        MoreRow("Чеклист смены",        icon: "checklist",                  color: .purple,
                                badge: {
                                    let done = store.checklists.filter { $0.isCompleted }.count
                                    let total = store.checklists.count
                                    return total > 0 ? "\(done)/\(total)" : nil
                                }()) { ShiftChecklistView().environmentObject(store) }
                        MoreRow("Сборники меню",        icon: "books.vertical.fill",        color: .purple) { NavigationStack { MenuCollectionsView().environmentObject(store) } }
                    }
                    MoreSectionBlock(title: "Гости и сервис", color: .teal) {
                        MoreRow("План зала",             icon: "rectangle.split.3x3.fill",  color: .teal) { FloorPlanView().environmentObject(store) }
                        MoreRow("Бронирование",          icon: "calendar.badge.plus",       color: .teal,
                                badge: {
                                    let c = store.todayReservations.filter { $0.status == .confirmed }.count
                                    return c > 0 ? "\(c)" : nil
                                }()) { TableReservationView().environmentObject(store) }
                        MoreRow("Программа лояльности",  icon: "star.circle.fill",          color: .teal,
                                badge: store.loyaltyCards.isEmpty ? nil : "\(store.loyaltyCards.count)") { LoyaltyView().environmentObject(store) }
                        MoreRow("Интеграция с кассой",   icon: "server.rack",               color: .teal,
                                badge: store.posRecords.isEmpty ? nil : "\(store.posRecords.count)") { POSIntegrationView().environmentObject(store) }
                    }
                    MoreSectionBlock(title: "Закупки", color: .green) {
                        MoreRow("Автозаказ",             icon: "cart.badge.plus",       color: .green,
                                badge: store.purchaseList.isEmpty ? nil : "\(store.purchaseList.count)") { SupplierAutoOrderView().environmentObject(store) }
                        MoreRow("Температурный журнал",  icon: "thermometer.medium",    color: .green,
                                badge: store.temperatureLogs.contains(where: { $0.isCritical }) ? "!" : nil) { TemperatureLogView().environmentObject(store) }
                    }
                    MoreSectionBlock(title: "Управление", color: Color(.systemGray)) {
                        MoreRow("Рестораны",      icon: "building.2.fill",                         color: Color(.systemGray),
                                badge: store.restaurantName.isEmpty ? nil : store.restaurantName) { RestaurantSwitcherView().environmentObject(store) }
                        MoreRow("Поставщики",     icon: "truck.box.fill",                           color: Color(.systemGray)) { SuppliersView().environmentObject(store) }
                        MoreRow("Сотрудники",     icon: "person.2.fill",                            color: Color(.systemGray)) { PermissionGate(permission: "Настройки") { EmployeeListView() }.environmentObject(store) }
                        MoreRow("Синхронизация",  icon: "arrow.triangle.2.circlepath.circle.fill",  color: Color(.systemGray),
                                badge: store.isSyncing ? "…" : store.syncError != nil ? "!" : nil) { SyncView().environmentObject(store) }
                        MoreRow("Резервная копия",icon: "externaldrive.fill",                       color: Color(.systemGray)) { BackupView().environmentObject(store) }
                        MoreRow("Настройки",      icon: "gearshape.fill",                           color: Color(.systemGray)) { PermissionGate(permission: "Настройки") { SettingsView() }.environmentObject(store) }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ещё")
        }
    }
}

// MARK: - Profile Card

private struct MoreProfileCard: View {
    let store: ChefProStore

    var body: some View {
        NavigationLink {
            ProfileView().environmentObject(store)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                    Text(String(store.profile.name.prefix(1)).uppercased())
                        .font(.title3.bold()).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.profile.name).font(.headline).foregroundStyle(.primary)
                    Text(store.profile.position).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Launch Grid

private struct MoreQuickGrid: View {
    let store: ChefProStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Быстрый доступ")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                QuickTile(icon: "clock.badge.checkmark.fill", label: "Смена", color: .green,
                          badge: store.currentShift != nil ? "●" : nil) { ShiftView().environmentObject(store) }
                QuickTile(icon: "rectangle.3.group.fill", label: "Kitchen Board", color: .orange,
                          badge: {
                              let c = store.kitchenOrders.filter { $0.status != .ready }.count
                              return c > 0 ? "\(c)" : nil
                          }()) { KitchenBoardView().environmentObject(store) }
                QuickTile(icon: "list.bullet.rectangle.portrait.fill", label: "Стоп/Гоу", color: .red) {
                    StopGoListView().environmentObject(store)
                }
                QuickTile(icon: "person.wave.2.fill", label: "Официант", color: .blue) {
                    WaiterModeView().environmentObject(store)
                }
                QuickTile(icon: "trash.fill", label: "Списания", color: .pink) {
                    PermissionGate(permission: "Списания") { WriteOffsView() }.environmentObject(store)
                }
                QuickTile(icon: "cart.fill", label: "Закупки", color: .teal) {
                    PurchasesView().environmentObject(store)
                }
                QuickTile(icon: "flame.fill", label: "Kitchen Mode", color: .indigo) {
                    KitchenModeView().environmentObject(store)
                }
                QuickTile(icon: "calendar.badge.exclamationmark", label: "Срок годности", color: .red,
                          badge: store.expiringItems.isEmpty ? nil : "\(store.expiringItems.count)") {
                    ExpiryWatchlistView().environmentObject(store)
                }
                QuickTile(icon: "magnifyingglass", label: "Поиск", color: .gray) {
                    GlobalSearchView().environmentObject(store)
                }
            }
        }
    }
}

private struct QuickTile<Destination: View>: View {
    let icon: String
    let label: String
    let color: Color
    var badge: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 44, height: 44)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Block (collapsible)

private struct MoreSectionBlock<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: () -> Content
    @State private var expanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, 16)
                content()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - More Row

private struct MoreRow<Destination: View>: View {
    let label: String
    let icon: String
    let color: Color
    var badge: String?
    @ViewBuilder let destination: () -> Destination

    init(_ label: String, icon: String, color: Color, badge: String? = nil, @ViewBuilder destination: @escaping () -> Destination) {
        self.label = label
        self.icon = icon
        self.color = color
        self.badge = badge
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(color)
                    }
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption.bold())
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)

        Divider().padding(.leading, 60)
    }
}

// MARK: - Expiry Watchlist

struct ExpiryWatchlistView: View {
    @EnvironmentObject var store: ChefProStore

    private var expiredItems: [InventoryItem] {
        store.inventoryItems.filter { $0.isExpired }.sorted { $0.name < $1.name }
    }
    private var expiringSoonItems: [InventoryItem] {
        store.inventoryItems.filter { $0.isExpiringSoon }.sorted {
            ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture)
        }
    }

    var body: some View {
        List {
            if expiredItems.isEmpty && expiringSoonItems.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "Всё в порядке",
                    subtitle: "Продуктов с истекающим сроком годности нет."
                )
                .listRowBackground(Color.clear)
            }

            if !expiredItems.isEmpty {
                Section {
                    ForEach(expiredItems) { item in
                        ExpiryItemRow(item: item, isExpired: true)
                    }
                } header: {
                    Label("Просрочено (\(expiredItems.count))", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            if !expiringSoonItems.isEmpty {
                Section {
                    ForEach(expiringSoonItems) { item in
                        ExpiryItemRow(item: item, isExpired: false)
                    }
                } header: {
                    Label("Истекает скоро (\(expiringSoonItems.count))", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Срок годности")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct ExpiryItemRow: View {
    let item: InventoryItem
    let isExpired: Bool

    private var daysText: String {
        guard let d = item.expiryDate else { return "" }
        if isExpired {
            let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
            return "Просрочено \(days) дн. назад"
        } else {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
            return days == 0 ? "Истекает сегодня" : "Истекает через \(days) дн."
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isExpired ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(isExpired ? .red : .orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                Text(item.category).font(.caption).foregroundStyle(.secondary)
                Text(daysText)
                    .font(.caption.bold())
                    .foregroundStyle(isExpired ? .red : .orange)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.quantity, specifier: "%.1f") \(item.unit)")
                    .font(.subheadline.bold())
                if let d = item.expiryDate {
                    Text(d.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
