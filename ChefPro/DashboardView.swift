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

    @State private var showQuickProduce = false

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    // ── Приветствие ──────────────────────────────────
                    BigCard {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 54, height: 54)
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
                                HStack(spacing: 4) {
                                    if !store.profile.position.isEmpty {
                                        Text(store.profile.position)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("·")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(store.restaurantName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            // Компактный статус синхронизации
                            syncIcon
                        }
                    }

                    // ── KPI Цели месяца ─────────────────────────────────
                    if store.monthlyRevenuePlan > 0 {
                        BigCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Цели месяца", systemImage: "target")
                                    .font(.headline)

                                // Revenue progress
                                let revProgress = min(store.currentMonthRevenue / store.monthlyRevenuePlan, 1.0)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Выручка")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(store.currentMonthRevenue)) / \(Int(store.monthlyRevenuePlan)) ₽")
                                            .font(.caption.bold())
                                    }
                                    ProgressView(value: revProgress)
                                        .tint(revProgress >= 1.0 ? .green : .chefAccent)
                                }

                                // Food Cost target
                                if store.currentMonthAvgFoodCost > 0 {
                                    let fcColor: Color = store.currentMonthAvgFoodCost > store.monthlyFoodCostTarget ? .red : .green
                                    HStack {
                                        Text("Food Cost")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(String(format: "%.1f", store.currentMonthAvgFoodCost))% / цель \(String(format: "%.0f", store.monthlyFoodCostTarget))%")
                                            .font(.caption.bold())
                                            .foregroundStyle(fcColor)
                                    }
                                }
                            }
                        }
                    }

                    // ── Карточки-статистика (кликабельные) ──────────
                    HStack {
                        NavigationLink {
                            InventoryView().environmentObject(store)
                        } label: {
                            InfoCard(
                                title: "Склад",
                                value: "\(store.inventoryItems.count)",
                                subtitle: store.lowStockItems.isEmpty ? "позиций" : "⚠ \(store.lowStockItems.count) заканч.",
                                icon: "shippingbox.fill",
                                accent: store.lowStockItems.isEmpty ? .chefAccent : .orange,
                                tappable: true
                            )
                        }.buttonStyle(.plain)

                        NavigationLink {
                            TechCardsView().environmentObject(store)
                        } label: {
                            InfoCard(title: "Техкарты", value: "\(store.dishes.count)", subtitle: "блюд", icon: "book.fill", tappable: true)
                        }.buttonStyle(.plain)
                    }

                    HStack {
                        NavigationLink {
                            ReportsView().environmentObject(store)
                        } label: {
                            InfoCard(title: "Производство", value: "\(store.productions.count)", subtitle: "операций", icon: "flame.fill", tappable: true)
                        }.buttonStyle(.plain)

                        NavigationLink {
                            WriteOffsView().environmentObject(store)
                        } label: {
                            InfoCard(title: "Списания", value: "\(store.writeOffs.count)", subtitle: "операций", icon: "trash.fill", tappable: true)
                        }.buttonStyle(.plain)
                    }

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

                    // ── Быстрое производство ─────────────────────────
                    if !store.dishes.isEmpty {
                        Button {
                            showQuickProduce = true
                        } label: {
                            BigCard {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().fill(Color.orange.opacity(0.15)).frame(width: 44, height: 44)
                                        Image(systemName: "flame.fill").foregroundStyle(.orange).font(.title2)
                                    }
                                    Text("Быстрое производство").font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // ── Срок годности ────────────────────────────────
                    if !store.expiringItems.isEmpty {
                        NavigationLink { InventoryView().environmentObject(store) } label: {
                            BigCard {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().fill(Color.purple.opacity(0.12)).frame(width: 44, height: 44)
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .foregroundStyle(.purple).font(.title2)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Срок годности").font(.headline)
                                        let expired  = store.expiringItems.filter(\.isExpired).count
                                        let expiring = store.expiringItems.filter(\.isExpiringSoon).count
                                        if expired > 0 {
                                            Text("\(expired) просрочено · \(expiring) истекает").font(.caption).foregroundStyle(.red)
                                        } else {
                                            Text("\(expiring) позиций истекает через ≤3 дня").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }.buttonStyle(.plain)
                    }

                    // ── Food Cost Warning ────────────────────────────
                    if !highFoodCostDishes.isEmpty {
                        NavigationLink { TechCardsView().environmentObject(store) } label: {
                            BigCard {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().fill(Color.red.opacity(0.12)).frame(width: 44, height: 44)
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.red).font(.title2)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Высокий Food Cost").font(.headline)
                                        Text("\(highFoodCostDishes.count) блюд превышает \(Int(store.foodCostThreshold))%")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }.buttonStyle(.plain)
                    }

                    // ── Нужно заказать ───────────────────────────────
                    SectionTitle(title: "Нужно заказать")

                    if store.lowStockItems.isEmpty {
                        BigCard {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("Все остатки в норме").font(.headline)
                            }
                        }
                    } else {
                        ForEach(store.lowStockItems) { item in
                            NavigationLink {
                                InventoryDetailView(item: item).environmentObject(store)
                            } label: {
                                BigCard {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
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
        }
    }

    @ViewBuilder
    private var syncIcon: some View {
        if store.isSyncing {
            ProgressView().scaleEffect(0.8)
        } else if store.syncError != nil {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.orange)
                .font(.title3)
        } else if store.lastSyncDate != nil {
            Image(systemName: "checkmark.icloud.fill")
                .foregroundStyle(.green)
                .font(.title3)
        } else {
            Image(systemName: "icloud.slash")
                .foregroundStyle(.secondary)
                .font(.title3)
        }
    }
}
