import SwiftUI
import UIKit

// MARK: - Quick Action Support

struct QuickActionShortcut: Identifiable {
    let id = UUID()
    let type: String
}

// MARK: - App Root

struct ContentView: View {
    @StateObject private var store = ChefProStore()

    var body: some View {
        Group {
            if store.isLoggedIn {
                MainAppView()
                    .environmentObject(store)
            } else {
                LoginView()
                    .environmentObject(store)
            }
        }
        .undoBanner()
        .environmentObject(store)
        .tint(.chefAccent)
        .preferredColorScheme(store.appColorScheme.colorScheme)
    }
}

struct MainAppView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var showOnboarding = false
    @State private var deepLinkedDish: Dish? = nil
    @State private var showDeepLinkedDish = false
    @State private var quickActionShortcut: QuickActionShortcut? = nil

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadMainView()
                    .environmentObject(store)
            } else {
                iPhoneTabView()
                    .environmentObject(store)
            }
        }
        .onAppear {
            if !store.hasSeenOnboarding { showOnboarding = true }
        }
        .onOpenURL { url in
            guard url.scheme == "chefpro", url.host == "dish",
                  let uuidString = url.pathComponents.last,
                  let uuid = UUID(uuidString: uuidString),
                  let dish = store.dishes.first(where: { $0.id == uuid }) else { return }
            deepLinkedDish = dish
            showDeepLinkedDish = true
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onFinish: {
                store.hasSeenOnboarding = true
                showOnboarding = false
            })
            .environmentObject(store)
        }
        .sheet(isPresented: $showDeepLinkedDish) {
            if let dish = deepLinkedDish {
                NavigationStack {
                    DishDetailView(dish: dish)
                        .environmentObject(store)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if let action = AppDelegate.shortcutAction {
                quickActionShortcut = QuickActionShortcut(type: action)
                AppDelegate.shortcutAction = nil
            }
        }
        .sheet(item: $quickActionShortcut) { shortcut in
            NavigationStack {
                switch shortcut.type {
                case "com.chefpro.kitchenboard":
                    KitchenBoardView().environmentObject(store)
                case "com.chefpro.lowstock":
                    InventoryView().environmentObject(store)
                case "com.chefpro.addwriteoff":
                    AddWriteOffView { writeOff in store.addWriteOff(writeOff) }
                        .environmentObject(store)
                case "com.chefpro.waiter":
                    WaiterModeView().environmentObject(store)
                default:
                    DashboardView().environmentObject(store)
                }
            }
        }
    }
}

// MARK: - iPhone Tab View (unchanged)

struct iPhoneTabView: View {
    @EnvironmentObject var store: ChefProStore

    var body: some View {
        TabView {
            DashboardView()
                .environmentObject(store)
                .tabItem { Label(store.appLanguage == .english ? "Home" : "Главная", systemImage: "house.fill") }

            PermissionGate(permission: "Техкарты") {
                TechCardsView()
            }
            .environmentObject(store)
            .tabItem { Label(store.appLanguage == .english ? "Recipes" : "Техкарты", systemImage: "book.fill") }

            PermissionGate(permission: "Склад") {
                InventoryView()
            }
            .environmentObject(store)
            .tabItem { Label(store.appLanguage == .english ? "Inventory" : "Склад", systemImage: "shippingbox.fill") }

            PermissionGate(permission: "Приемка") {
                DeliveriesView()
            }
            .environmentObject(store)
            .tabItem { Label(store.appLanguage == .english ? "Deliveries" : "Приемка", systemImage: "tray.and.arrow.down.fill") }

            MoreView()
                .environmentObject(store)
                .tabItem { Label(store.appLanguage == .english ? "More" : "Еще", systemImage: "ellipsis.circle.fill") }
        }
    }
}

// MARK: - iPad Split View

struct iPadMainView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedSection: AppSection? = .dashboard

    enum AppSection: String, Identifiable {
        // Главное
        case dashboard  = "Главная"
        case techCards  = "Техкарты"
        case inventory  = "Склад"
        case deliveries = "Приёмка"
        // Операции
        case shift      = "Смена"
        case kitchenBoard = "Kitchen Board"
        case waiterMode = "Режим официанта"
        case purchases  = "Закупки"
        case writeOffs  = "Списания"
        case kitchenMode = "Kitchen Mode"
        // Аналитика
        case analytics  = "Аналитика"
        case sales      = "Продажи"
        case reports    = "Отчёты"
        case profitLoss = "P&L"
        case foodCostTrend = "Динамика Food Cost"
        case pdfReports = "PDF отчёты"
        case writeOffReport = "Отчёт по списаниям"
        case csvExport  = "CSV экспорт"
        case supplierAnalytics = "Аналитика поставщиков"
        // Инструменты
        case stockMovements = "История движений"
        case markupCalc = "Калькулятор наценки"
        case unitConverter = "Конвертер единиц"
        case audit      = "Инвентаризация"
        case menuEng    = "Menu Engineering"
        // Персонал
        case employees  = "Сотрудники"
        case schedule   = "Расписание"
        case suppliers  = "Поставщики"
        // Система
        case profile    = "Профиль"
        case checklists = "Чеклисты"
        case temperature = "Температурный журнал"
        case settings   = "Настройки"
        case backup     = "Резервная копия"
        // Новые модули
        case reservations = "Бронирование"
        case loyalty      = "Лояльность"
        case posIntegration = "Касса"
        case abcAnalysis  = "ABC-анализ"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard:      return "house.fill"
            case .techCards:      return "book.fill"
            case .inventory:      return "shippingbox.fill"
            case .deliveries:     return "tray.and.arrow.down.fill"
            case .shift:          return "clock.badge.checkmark.fill"
            case .kitchenBoard:   return "rectangle.3.group.fill"
            case .waiterMode:     return "person.wave.2.fill"
            case .purchases:      return "cart.fill"
            case .writeOffs:      return "trash.fill"
            case .kitchenMode:    return "flame.fill"
            case .analytics:      return "chart.bar.fill"
            case .sales:          return "bag.fill"
            case .reports:        return "chart.bar.doc.horizontal"
            case .profitLoss:     return "chart.line.uptrend.xyaxis.circle.fill"
            case .foodCostTrend:  return "waveform.path.ecg"
            case .pdfReports:     return "doc.richtext.fill"
            case .writeOffReport: return "chart.bar.doc.horizontal.fill"
            case .csvExport:      return "tablecells"
            case .supplierAnalytics: return "building.2.crop.circle.fill"
            case .stockMovements: return "clock.arrow.circlepath"
            case .markupCalc:     return "arrow.up.right.circle.fill"
            case .unitConverter:  return "arrow.left.arrow.right"
            case .audit:          return "list.clipboard.fill"
            case .menuEng:        return "chart.bar.xaxis"
            case .employees:      return "person.2.fill"
            case .schedule:       return "calendar"
            case .suppliers:      return "building.2.fill"
            case .profile:        return "person.circle.fill"
            case .checklists:     return "checklist"
            case .temperature:    return "thermometer.medium"
            case .settings:       return "gear"
            case .backup:         return "externaldrive.fill"
            case .reservations:   return "calendar.badge.plus"
            case .loyalty:        return "star.circle.fill"
            case .posIntegration: return "server.rack"
            case .abcAnalysis:    return "chart.bar.doc.horizontal"
            }
        }
    }

    // Sidebar groups
    private let mainSections: [AppSection] = [.dashboard, .techCards, .inventory, .deliveries]
    private let opsSections:  [AppSection] = [.shift, .kitchenBoard, .waiterMode, .purchases, .writeOffs, .kitchenMode]
    private let analyticsSections: [AppSection] = [.analytics, .sales, .reports, .profitLoss, .foodCostTrend, .pdfReports, .writeOffReport, .csvExport, .supplierAnalytics, .abcAnalysis]
    private let toolsSections: [AppSection] = [.stockMovements, .markupCalc, .unitConverter, .audit, .menuEng]
    private let staffSections: [AppSection] = [.employees, .schedule, .suppliers]
    private let guestSections: [AppSection] = [.reservations, .loyalty, .posIntegration]
    private let systemSections: [AppSection] = [.profile, .checklists, .temperature, .settings, .backup]

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Главное") {
                    ForEach(mainSections) { s in sidebarRow(s) }
                }
                Section("Операции") {
                    ForEach(opsSections) { s in sidebarRow(s) }
                }
                Section("Аналитика") {
                    ForEach(analyticsSections) { s in sidebarRow(s) }
                }
                Section("Инструменты") {
                    ForEach(toolsSections) { s in sidebarRow(s) }
                }
                Section("Персонал") {
                    ForEach(staffSections) { s in sidebarRow(s) }
                }
                Section("Гости и сервис") {
                    ForEach(guestSections) { s in sidebarRow(s) }
                }
                Section("Система") {
                    ForEach(systemSections) { s in sidebarRow(s) }
                }
            }
            .navigationTitle("ChefPro")
            .listStyle(.sidebar)
        } detail: {
            detailView(for: selectedSection ?? .dashboard)
        }
    }

    @ViewBuilder
    private func sidebarRow(_ section: AppSection) -> some View {
        HStack {
            Label(section.rawValue, systemImage: section.icon)
            Spacer()
            // Badges
            if section == .shift, store.currentShift != nil {
                Text("Открыта").font(.caption.bold())
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.green.opacity(0.15)).foregroundStyle(.green)
                    .clipShape(Capsule())
            }
            if section == .kitchenBoard {
                let active = store.kitchenOrders.filter { $0.status != .ready }.count
                if active > 0 {
                    Text("\(active)").font(.caption.bold())
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2)).foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
            if section == .inventory, !store.lowStockItems.isEmpty {
                Text("⚠ \(store.lowStockItems.count)").font(.caption.bold())
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15)).foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .tag(section)
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        switch section {
        case .dashboard:      DashboardView().environmentObject(store)
        case .techCards:      PermissionGate(permission: "Техкарты") { TechCardsView() }.environmentObject(store)
        case .inventory:      PermissionGate(permission: "Склад") { InventoryView() }.environmentObject(store)
        case .deliveries:     PermissionGate(permission: "Приемка") { DeliveriesView() }.environmentObject(store)
        case .shift:          ShiftView().environmentObject(store)
        case .kitchenBoard:   KitchenBoardView().environmentObject(store)
        case .waiterMode:     WaiterModeView().environmentObject(store)
        case .purchases:      PurchasesView().environmentObject(store)
        case .writeOffs:      PermissionGate(permission: "Списания") { WriteOffsView() }.environmentObject(store)
        case .kitchenMode:    KitchenModeView().environmentObject(store)
        case .analytics:      AnalyticsView().environmentObject(store)
        case .sales:          SalesView().environmentObject(store)
        case .reports:        PermissionGate(permission: "Отчеты") { ReportsView() }.environmentObject(store)
        case .profitLoss:     ProfitLossView().environmentObject(store)
        case .foodCostTrend:  FoodCostTrendView().environmentObject(store)
        case .pdfReports:     PDFReportsView().environmentObject(store)
        case .writeOffReport: WriteOffReportView().environmentObject(store)
        case .csvExport:      CSVExportView().environmentObject(store)
        case .supplierAnalytics: SupplierAnalyticsView().environmentObject(store)
        case .stockMovements: StockMovementsView().environmentObject(store)
        case .markupCalc:     MarkupCalculatorView().environmentObject(store)
        case .unitConverter:  UnitConverterView()
        case .audit:          InventoryAuditView().environmentObject(store)
        case .menuEng:        MenuEngineeringView().environmentObject(store)
        case .employees:      EmployeeListView().environmentObject(store)
        case .schedule:       WorkScheduleView().environmentObject(store)
        case .suppliers:      SuppliersView().environmentObject(store)
        case .profile:        ProfileView().environmentObject(store)
        case .checklists:     ShiftChecklistView().environmentObject(store)
        case .temperature:    TemperatureLogView().environmentObject(store)
        case .settings:       SettingsView().environmentObject(store)
        case .backup:         BackupView().environmentObject(store)
        case .reservations:   TableReservationView().environmentObject(store)
        case .loyalty:        LoyaltyView().environmentObject(store)
        case .posIntegration: POSIntegrationView().environmentObject(store)
        case .abcAnalysis:    ABCAnalysisView().environmentObject(store)
        }
    }
}

struct PermissionGate<Content: View>: View {
    @EnvironmentObject var store: ChefProStore
    let permission: String
    let content: () -> Content

    var body: some View {
        if store.hasPermission(permission) {
            content()
        } else {
            NoAccessView(permission: permission)
        }
    }
}

struct NoAccessView: View {
    let permission: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                Text("Нет доступа")
                    .font(.largeTitle)
                    .bold()
                Text("Для раздела \"\(permission)\" нужно выдать право доступа.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(permission)
        }
    }
}

#Preview {
    ContentView()
}
