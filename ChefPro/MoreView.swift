import SwiftUI

// MARK: - More

struct MoreView: View {
    @EnvironmentObject var store: ChefProStore

    var body: some View {
        NavigationStack {
            List {
                // ── Профиль ──────────────────────────────────────
                Section {
                    NavigationLink {
                        ProfileView().environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.orange).frame(width: 36, height: 36)
                                Text(String(store.profile.name.prefix(1)).uppercased())
                                    .font(.subheadline.bold()).foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(store.profile.name).font(.headline)
                                Text(store.profile.position).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Операции ────────────────────────────────────
                Section("Операции") {
                    NavigationLink {
                        ShiftView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Смена", systemImage: "clock.badge.checkmark.fill")
                            Spacer()
                            if store.currentShift != nil {
                                Text("Открыта")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        KitchenBoardView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Kitchen Board", systemImage: "rectangle.3.group.fill")
                            Spacer()
                            if store.kitchenOrders.contains(where: { $0.status != .ready }) {
                                Text("\(store.kitchenOrders.filter { $0.status != .ready }.count)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        WaiterModeView().environmentObject(store)
                    } label: { Label("Режим официанта", systemImage: "person.wave.2.fill") }

                    NavigationLink {
                        PermissionGate(permission: "Списания") { WriteOffsView() }
                            .environmentObject(store)
                    } label: { Label("Списания", systemImage: "trash.fill") }

                    NavigationLink {
                        KitchenModeView().environmentObject(store)
                    } label: { Label("Kitchen Mode", systemImage: "flame.fill") }

                    NavigationLink {
                        PurchasesView().environmentObject(store)
                    } label: { Label("Закупки", systemImage: "cart.fill") }
                }

                // ── Аналитика ───────────────────────────────────
                Section("Аналитика") {
                    NavigationLink {
                        AnalyticsView().environmentObject(store)
                    } label: { Label("Аналитика", systemImage: "chart.line.uptrend.xyaxis") }

                    NavigationLink {
                        SupplierAnalyticsView().environmentObject(store)
                    } label: { Label("Аналитика поставщиков", systemImage: "building.2.crop.circle.fill") }

                    NavigationLink {
                        MenuEngineeringView().environmentObject(store)
                    } label: { Label("Menu Engineering", systemImage: "chart.bar.xaxis") }

                    NavigationLink {
                        SalesView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Продажи", systemImage: "bag.fill")
                            Spacer()
                            if !store.sales.isEmpty {
                                Text("\(store.sales.count)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        PermissionGate(permission: "Отчеты") { ReportsView() }
                            .environmentObject(store)
                    } label: { Label("Отчеты", systemImage: "chart.bar.fill") }

                    NavigationLink {
                        ProfitLossView().environmentObject(store)
                    } label: { Label("P&L", systemImage: "chart.line.uptrend.xyaxis.circle.fill") }

                    NavigationLink {
                        FoodCostTrendView().environmentObject(store)
                    } label: { Label("Динамика Food Cost", systemImage: "waveform.path.ecg") }

                    NavigationLink {
                        PurchaseBudgetView().environmentObject(store)
                    } label: { Label("Бюджет закупок", systemImage: "chart.bar.doc.horizontal") }

                    NavigationLink {
                        PDFReportsView().environmentObject(store)
                    } label: { Label("PDF-отчеты", systemImage: "doc.richtext.fill") }

                    NavigationLink {
                        WriteOffReportView().environmentObject(store)
                    } label: { Label("Отчёт по списаниям", systemImage: "chart.bar.doc.horizontal.fill") }

                    NavigationLink {
                        CSVExportView().environmentObject(store)
                    } label: { Label("CSV-экспорт", systemImage: "tablecells") }

                    NavigationLink {
                        PurchaseForecastView().environmentObject(store)
                    } label: { Label("Прогноз закупок", systemImage: "chart.line.downtrend.xyaxis") }

                    NavigationLink {
                        BreakevenView().environmentObject(store)
                    } label: { Label("Точка безубыточности", systemImage: "chart.line.uptrend.xyaxis") }
                }

                // ── Инструменты ─────────────────────────────────
                Section("Инструменты") {
                    NavigationLink {
                        StockMovementsView().environmentObject(store)
                    } label: { Label("История движений", systemImage: "clock.arrow.circlepath") }

                    NavigationLink {
                        GlobalSearchView().environmentObject(store)
                    } label: { Label("Поиск", systemImage: "magnifyingglass") }

                    NavigationLink {
                        RecipeTemplatesView().environmentObject(store)
                    } label: { Label("Шаблоны техкарт", systemImage: "doc.text.fill") }

                    NavigationLink {
                        PriceCalculatorView().environmentObject(store)
                    } label: { Label("Калькулятор цены", systemImage: "percent") }

                    NavigationLink {
                        MarkupCalculatorView().environmentObject(store)
                    } label: { Label("Калькулятор наценки", systemImage: "arrow.up.right.circle.fill") }

                    NavigationLink {
                        ProfitabilityRankingView().environmentObject(store)
                    } label: { Label("Рейтинг прибыльности", systemImage: "trophy.fill") }

                    NavigationLink {
                        DishGalleryView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Галерея блюд", systemImage: "photo.stack.fill")
                            Spacer()
                            let cnt = store.dishes.filter { $0.photoFilename != nil }.count
                            if cnt > 0 {
                                Text("\(cnt)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.purple.opacity(0.15))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        ProductionPlanView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("План производства", systemImage: "calendar.badge.clock")
                            Spacer()
                            if !store.currentProductionPlan.isEmpty {
                                Text("\(store.currentProductionPlan.count)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        InventoryAuditView().environmentObject(store)
                    } label: { Label("Инвентаризация", systemImage: "list.clipboard.fill") }

                    NavigationLink {
                        BarcodeScannerView().environmentObject(store)
                    } label: { Label("QR / Barcode", systemImage: "barcode.viewfinder") }

                    NavigationLink {
                        UnitConverterView()
                    } label: { Label("Конвертер единиц", systemImage: "arrow.left.arrow.right") }

                    NavigationLink {
                        DigitalMenuView().environmentObject(store)
                    } label: { Label("Цифровое меню", systemImage: "menucard.fill") }
                }

                // ── Персонал ────────────────────────────────────
                Section("Персонал") {
                    NavigationLink {
                        WorkScheduleView().environmentObject(store)
                    } label: { Label("График работы", systemImage: "calendar.badge.clock") }

                    NavigationLink {
                        EmployeeActivityView().environmentObject(store)
                    } label: { Label("Активность сотрудников", systemImage: "person.badge.clock.fill") }

                    NavigationLink {
                        ShiftChecklistView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Чеклист смены", systemImage: "checklist")
                            Spacer()
                            let done = store.checklists.filter { $0.isCompleted }.count
                            let total = store.checklists.count
                            if total > 0 {
                                Text("\(done)/\(total)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(done == total ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                    .foregroundStyle(done == total ? Color.green : Color.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        NavigationStack {
                            MenuCollectionsView().environmentObject(store)
                        }
                    } label: { Label("Сборники меню", systemImage: "books.vertical.fill") }
                }

                // ── Закупки ─────────────────────────────────────
                Section("Закупки") {
                    NavigationLink {
                        SupplierAutoOrderView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Автозаказ поставщикам", systemImage: "cart.badge.plus")
                            Spacer()
                            if !store.purchaseList.isEmpty {
                                Text("\(store.purchaseList.count)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        TemperatureLogView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Температурный журнал", systemImage: "thermometer.medium")
                            Spacer()
                            if store.temperatureLogs.contains(where: { $0.isCritical }) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // ── Новые модули ────────────────────────────────
                Section("Гости и сервис") {
                    NavigationLink {
                        FloorPlanView().environmentObject(store)
                    } label: { Label("План зала", systemImage: "rectangle.split.3x3.fill") }

                    NavigationLink {
                        TableReservationView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Бронирование столиков", systemImage: "calendar.badge.plus")
                            Spacer()
                            let todayCount = store.todayReservations.filter { $0.status == .confirmed }.count
                            if todayCount > 0 {
                                Text("\(todayCount)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        LoyaltyView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Программа лояльности", systemImage: "star.circle.fill")
                            Spacer()
                            if !store.loyaltyCards.isEmpty {
                                Text("\(store.loyaltyCards.count)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        POSIntegrationView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Интеграция с кассой", systemImage: "server.rack")
                            Spacer()
                            if !store.posRecords.isEmpty {
                                Text("\(store.posRecords.count)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Section("Аналитика склада") {
                    NavigationLink {
                        ABCAnalysisView().environmentObject(store)
                    } label: { Label("ABC-анализ склада", systemImage: "chart.bar.doc.horizontal") }
                }

                // ── Управление ──────────────────────────────────
                Section("Управление") {
                    NavigationLink {
                        RestaurantSwitcherView().environmentObject(store)
                    } label: {
                        HStack {
                            Label("Рестораны", systemImage: "building.2.fill")
                            Spacer()
                            Text(store.restaurantName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    NavigationLink {
                        SuppliersView().environmentObject(store)
                    } label: { Label("Поставщики", systemImage: "truck.box.fill") }

                    NavigationLink {
                        PermissionGate(permission: "Настройки") { EmployeeListView() }
                            .environmentObject(store)
                    } label: { Label("Сотрудники", systemImage: "person.2.fill") }

                    NavigationLink {
                        BackupView().environmentObject(store)
                    } label: { Label("Резервная копия", systemImage: "externaldrive.fill") }

                    NavigationLink {
                        PermissionGate(permission: "Настройки") { SettingsView() }
                            .environmentObject(store)
                    } label: { Label("Настройки", systemImage: "gearshape.fill") }
                }
            }
            .navigationTitle("Еще")
        }
    }
}
