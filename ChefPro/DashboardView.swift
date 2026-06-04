import SwiftUI
import Charts

// MARK: - Shared Views

struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String
    var icon: String = "circle.fill"
    var accent: Color = .chefAccent
    var tappable: Bool = false

    var body: some View {
        BigCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(accent)
                    Text(title)
                        .font(.headline)
                    Spacer()
                    if tappable {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(value)
                    .font(.system(size: 34, weight: .bold))
                    .minimumScaleFactor(0.7)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2)
            .bold()
            .padding(.top, 8)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3).bold()
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let title = actionTitle, let action = action {
                Button(action: action) {
                    Label(title, systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject var store: ChefProStore

    private var highFoodCostDishes: [Dish] {
        store.dishes.filter { store.foodCostPercent($0) > store.foodCostThreshold }
    }

    @State private var showQuickProduce     = false
    @State private var showRestaurantPicker = false

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Доброе утро" }
        if h < 17 { return "Добрый день" }
        return "Добрый вечер"
    }

    private var firstName: String {
        store.profile.name.components(separatedBy: " ").first ?? store.profile.name
    }

    private var shortDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: Date()).capitalized
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ── Offline banner ───────────────────────────────
                    OfflineStatusBanner().environmentObject(store)
                        .padding(.horizontal, -16)

                    // ── Приветствие ──────────────────────────────────
                    BigCard {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.orange, .red],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 52, height: 52)
                                Text(String(store.profile.name.prefix(1)).uppercased())
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(greeting), \(firstName) 👋")
                                    .font(.title3.bold())
                                Text(shortDate)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button {
                                    showRestaurantPicker = true
                                } label: {
                                    HStack(spacing: 4) {
                                        if !store.profile.position.isEmpty {
                                            Text(store.profile.position).font(.caption).foregroundStyle(.secondary)
                                            Text("·").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Text(store.restaurantName).font(.caption).foregroundStyle(.chefAccent)
                                        Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.chefAccent)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            syncIcon
                        }
                    }

                    // ── KPI Цели месяца ──────────────────────────────
                    if store.monthlyRevenuePlan > 0 {
                        BigCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Цели месяца", systemImage: "target")
                                    .font(.headline)

                                let revProgress = min(store.currentMonthRevenue / store.monthlyRevenuePlan, 1.0)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Выручка").font(.subheadline).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(store.currentMonthRevenue)) / \(Int(store.monthlyRevenuePlan)) ₽")
                                            .font(.caption.bold())
                                    }
                                    ProgressView(value: revProgress)
                                        .tint(revProgress >= 1.0 ? .green : .chefAccent)
                                }

                                if store.currentMonthAvgFoodCost > 0 {
                                    let fcColor: Color = store.currentMonthAvgFoodCost > store.monthlyFoodCostTarget ? .red : .green
                                    HStack {
                                        Text("Food Cost").font(.subheadline).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(String(format: "%.1f", store.currentMonthAvgFoodCost))% / цель \(String(format: "%.0f", store.monthlyFoodCostTarget))%")
                                            .font(.caption.bold())
                                            .foregroundStyle(fcColor)
                                    }
                                }
                            }
                        }
                    }

                    // ── Быстрые действия ─────────────────────────────
                    quickActionsRow

                    // ── Статистика — равная сетка 2×2 ────────────────
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        NavigationLink {
                            InventoryView().environmentObject(store)
                        } label: {
                            StatCard(
                                title: "Склад",
                                value: "\(store.inventoryItems.count)",
                                subtitle: store.lowStockItems.isEmpty ? "позиций" : "⚠ \(store.lowStockItems.count) заканч.",
                                icon: "shippingbox.fill",
                                accent: store.lowStockItems.isEmpty ? .chefAccent : .orange
                            )
                        }.buttonStyle(.plain)

                        NavigationLink {
                            TechCardsView().environmentObject(store)
                        } label: {
                            StatCard(title: "Техкарты", value: "\(store.dishes.count)", subtitle: "блюд",
                                     icon: "book.fill", accent: .chefAccent)
                        }.buttonStyle(.plain)

                        NavigationLink {
                            ReportsView().environmentObject(store)
                        } label: {
                            StatCard(title: "Производство", value: "\(store.productions.count)", subtitle: "операций",
                                     icon: "flame.fill", accent: .orange)
                        }.buttonStyle(.plain)

                        NavigationLink {
                            WriteOffsView().environmentObject(store)
                        } label: {
                            StatCard(title: "Списания", value: "\(store.writeOffs.count)", subtitle: "операций",
                                     icon: "trash.fill", accent: .red)
                        }.buttonStyle(.plain)
                    }

                    // ── Активные уведомления ─────────────────────────
                    alertsSection

                    // ── Смена ────────────────────────────────────────
                    if let shift = store.currentShift {
                        NavigationLink { ShiftView().environmentObject(store) } label: {
                            BigCard {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().fill(Color.green.opacity(0.15)).frame(width: 44, height: 44)
                                        Image(systemName: "clock.fill").foregroundStyle(.green).font(.title2)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Смена открыта").font(.headline)
                                        Text("с \(shift.openedAt.formatted(date: .omitted, time: .shortened)) · \(shift.duration)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }.buttonStyle(.plain)
                    }

                    // ── Брони сегодня ────────────────────────────────
                    if !store.todayReservations.isEmpty {
                        NavigationLink {
                            TableReservationView().environmentObject(store)
                        } label: {
                            BigCard {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().fill(Color.blue.opacity(0.12)).frame(width: 44, height: 44)
                                        Image(systemName: "calendar.badge.clock")
                                            .foregroundStyle(.blue).font(.title2)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Брони сегодня").font(.headline)
                                        let confirmed = store.todayReservations.filter { $0.status == .confirmed }.count
                                        let arrived   = store.todayReservations.filter { $0.status == .arrived }.count
                                        Text("\(confirmed) подтв. · \(arrived) пришли")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(store.todayReservations.count)")
                                        .font(.title2.bold()).foregroundStyle(.blue)
                                }
                            }
                        }.buttonStyle(.plain)
                    }

                    // ── Нужно заказать ───────────────────────────────
                    HStack {
                        Text("Нужно заказать")
                            .font(.title2).bold()
                        Spacer()
                        if !store.lowStockItems.isEmpty {
                            Text("\(store.lowStockItems.count) позиций")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)

                    if store.lowStockItems.isEmpty {
                        BigCard {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
                                Text("Все остатки в норме")
                                    .font(.headline)
                            }
                        }
                    } else {
                        ForEach(store.lowStockItems) { item in
                            NavigationLink {
                                InventoryDetailView(item: item).environmentObject(store)
                            } label: {
                                BigCard {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle().fill(Color.orange.opacity(0.12)).frame(width: 36, height: 36)
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(.orange).font(.subheadline)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name).font(.headline).foregroundStyle(.primary)
                                            Text("\(item.quantity, specifier: "%.1f") \(item.unit) — нужно пополнить")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color.chefBackground)
            .navigationTitle("Главная")
            .sheet(isPresented: $showQuickProduce) {
                QuickProduceView().environmentObject(store)
            }
            .sheet(isPresented: $showRestaurantPicker) {
                RestaurantSwitcherView().environmentObject(store)
            }
        }
    }

    // ── Быстрые действия ─────────────────────────────────────────────────
    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionButton(icon: "flame.fill",      label: "Производство", color: .orange) { showQuickProduce = true }
                NavigationLink {
                    AddWriteOffView().environmentObject(store)
                } label: {
                    QuickActionLabel(icon: "trash.fill", label: "Списание", color: .red)
                }
                NavigationLink {
                    AddDeliveryView().environmentObject(store)
                } label: {
                    QuickActionLabel(icon: "tray.and.arrow.down.fill", label: "Приёмка", color: .blue)
                }
                NavigationLink {
                    KitchenBoardView().environmentObject(store)
                } label: {
                    QuickActionLabel(icon: "rectangle.3.group.fill", label: "Kitchen", color: .purple)
                }
                NavigationLink {
                    TableReservationView().environmentObject(store)
                } label: {
                    QuickActionLabel(icon: "calendar.badge.plus", label: "Бронь", color: .teal)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    // ── Алерты (срок годности, food cost) ────────────────────────────────
    @ViewBuilder
    private var alertsSection: some View {
        if !store.expiringItems.isEmpty {
            NavigationLink { ExpiryWatchlistView().environmentObject(store) } label: {
                alertBanner(
                    icon: "calendar.badge.exclamationmark",
                    color: .purple,
                    title: "Срок годности",
                    subtitle: {
                        let expired  = store.expiringItems.filter(\.isExpired).count
                        let expiring = store.expiringItems.filter(\.isExpiringSoon).count
                        return expired > 0 ? "\(expired) просрочено · \(expiring) истекает" : "\(expiring) позиций истекает через ≤3 дня"
                    }(),
                    subtitleColor: store.expiringItems.filter(\.isExpired).isEmpty ? .secondary : .red
                )
            }.buttonStyle(.plain)
        }

        if !highFoodCostDishes.isEmpty {
            NavigationLink { TechCardsView().environmentObject(store) } label: {
                alertBanner(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    title: "Высокий Food Cost",
                    subtitle: "\(highFoodCostDishes.count) блюд превышает \(Int(store.foodCostThreshold))%",
                    subtitleColor: .secondary
                )
            }.buttonStyle(.plain)
        }
    }

    private func alertBanner(icon: String, color: Color, title: String, subtitle: String, subtitleColor: Color) -> some View {
        BigCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icon).foregroundStyle(color).font(.title2)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(subtitleColor)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var syncIcon: some View {
        if store.isSyncing {
            ProgressView().scaleEffect(0.8)
        } else if store.syncError != nil {
            Image(systemName: "exclamationmark.icloud").foregroundStyle(.orange).font(.title3)
        } else if store.lastSyncDate != nil {
            Image(systemName: "checkmark.icloud.fill").foregroundStyle(.green).font(.title3)
        } else {
            Image(systemName: "icloud.slash").foregroundStyle(.secondary).font(.title3)
        }
    }
}

// MARK: - StatCard (равные размеры в сетке)

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    var icon: String = "circle.fill"
    var accent: Color = .chefAccent

    var body: some View {
        BigCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(accent.opacity(0.12)).frame(width: 34, height: 34)
                        Image(systemName: icon).foregroundStyle(accent).font(.subheadline.bold())
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold())
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        }
    }
}

// MARK: - Quick Action кнопки

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionLabel(icon: icon, label: label, color: color)
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionLabel: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title2)
            }
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .frame(width: 70)
    }
}
