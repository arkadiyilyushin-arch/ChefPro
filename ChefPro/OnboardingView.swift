import SwiftUI

// MARK: - Онбординг

struct OnboardingView: View {
    @EnvironmentObject var store: ChefProStore
    let onFinish: () -> Void

    private var showWizard: Bool {
        store.employees.isEmpty && store.restaurantName == "Demo Restaurant"
    }

    var body: some View {
        if showWizard {
            SetupWizardView(onFinish: onFinish).environmentObject(store)
        } else {
            OnboardingSlidesView(onFinish: onFinish).environmentObject(store)
        }
    }
}

// MARK: - Визард первого запуска

struct SetupWizardView: View {
    @EnvironmentObject var store: ChefProStore
    let onFinish: () -> Void

    @State private var step = 0

    // Шаг 1 — Ресторан
    @State private var restaurantName = ""
    @State private var city = ""

    // Шаг 2 — Первый сотрудник
    @State private var employeeName = ""
    @State private var position = "Менеджер"
    @State private var pin = ""
    @State private var pinConfirm = ""
    @State private var pinMismatch = false

    // Шаг 3 — Первое блюдо
    @State private var dishName = ""
    @State private var dishPrice = ""
    @State private var dishAdded = false

    private var pinValid: Bool { pin.count == 4 && pin == pinConfirm }
    private var step1Valid: Bool { !restaurantName.trimmingCharacters(in: .whitespaces).isEmpty }
    private var step2Valid: Bool { !employeeName.trimmingCharacters(in: .whitespaces).isEmpty && pinValid }

    private let stepColors: [Color] = [.chefAccent, .blue, .green, .purple]
    private let stepIcons = ["building.2.fill", "person.badge.key.fill", "fork.knife.circle.fill", "checkmark.seal.fill"]

    var body: some View {
        ZStack {
            // Адаптивный фон
            LinearGradient(
                colors: [stepColors[step].opacity(0.12), Color(.systemGroupedBackground)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: step)

            VStack(spacing: 0) {
                // Прогресс-бар
                HStack(spacing: 6) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i <= step ? stepColors[min(step, 3)] : Color(.systemGray5))
                            .frame(height: 5)
                            .animation(.spring(response: 0.4), value: step)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 6)

                Text("Шаг \(step + 1) из 4")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                TabView(selection: $step) {
                    wizardStep1.tag(0)
                    wizardStep2.tag(1)
                    wizardStep3.tag(2)
                    wizardStep4.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
        }
    }

    // MARK: Шаг 1 — Ресторан

    private var wizardStep1: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    stepIcon("building.2.fill", color: .chefAccent)

                    VStack(spacing: 6) {
                        Text("Ваш ресторан")
                            .font(.title2.bold())
                        Text("Укажите название заведения")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        inputField("Название ресторана", placeholder: "Ресторан «Берёзка»", text: $restaurantName, required: true)
                        inputField("Город", placeholder: "Москва", text: $city)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
            }

            wizardFooter(
                nextLabel: "Далее",
                nextEnabled: step1Valid,
                nextColor: .chefAccent,
                onBack: nil,
                onNext: {
                    store.restaurantName = restaurantName.trimmingCharacters(in: .whitespaces)
                    withAnimation { step = 1 }
                }
            )
        }
    }

    // MARK: Шаг 2 — Первый сотрудник

    private var wizardStep2: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    stepIcon("person.badge.key.fill", color: .blue)

                    VStack(spacing: 6) {
                        Text("Первый сотрудник")
                            .font(.title2.bold())
                        Text("Создайте учётную запись менеджера")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        inputField("Имя и фамилия", placeholder: "Иван Петров", text: $employeeName, required: true)
                        inputField("Должность", placeholder: "Менеджер", text: $position)

                        // PIN
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PIN-код (4 цифры) *")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            SecureField("••••", text: $pin)
                                .keyboardType(.numberPad)
                                .font(.title3.bold())
                                .multilineTextAlignment(.center)
                                .frame(height: 50)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onChange(of: pin) { pin = String(pin.prefix(4).filter { $0.isNumber }) }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Подтвердите PIN *")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            SecureField("••••", text: $pinConfirm)
                                .keyboardType(.numberPad)
                                .font(.title3.bold())
                                .multilineTextAlignment(.center)
                                .frame(height: 50)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onChange(of: pinConfirm) {
                                    pinConfirm = String(pinConfirm.prefix(4).filter { $0.isNumber })
                                    pinMismatch = !pinConfirm.isEmpty && pinConfirm != pin
                                }
                            if pinMismatch {
                                Text("PIN-коды не совпадают")
                                    .font(.caption.bold()).foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20).padding(.bottom, 20)
            }

            wizardFooter(
                nextLabel: "Далее",
                nextEnabled: step2Valid,
                nextColor: .blue,
                onBack: { withAnimation { step = 0 } },
                onNext: {
                    let emp = Employee(
                        name: employeeName.trimmingCharacters(in: .whitespaces),
                        position: position.isEmpty ? "Менеджер" : position,
                        phone: "", pin: pin,
                        permissions: ["Техкарты","Склад","Приемка","Списания","Отчеты","Настройки"]
                    )
                    store.addEmployee(emp)
                    store.currentEmployeeID = emp.id
                    store.profile = UserProfile(
                        name: emp.name, position: emp.position,
                        phone: emp.phone, permissions: emp.permissions
                    )
                    withAnimation { step = 2 }
                }
            )
        }
    }

    // MARK: Шаг 3 — Первое блюдо

    private var wizardStep3: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    stepIcon("fork.knife.circle.fill", color: .green)

                    VStack(spacing: 6) {
                        Text("Первое блюдо")
                            .font(.title2.bold())
                        Text("Необязательно — можно добавить позже")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }

                    if !dishAdded {
                        VStack(spacing: 14) {
                            inputField("Название блюда", placeholder: "Борщ классический", text: $dishName)
                            inputField("Цена продажи (₽)", placeholder: "0.00", text: $dishPrice, keyboardType: .decimalPad)

                            Button {
                                let name = dishName.trimmingCharacters(in: .whitespaces)
                                guard !name.isEmpty else { return }
                                store.dishes.append(Dish(
                                    name: name,
                                    category: "Основные блюда",
                                    salePrice: parsePositiveDouble(dishPrice) ?? 0,
                                    ingredients: []
                                ))
                                dishAdded = true
                            } label: {
                                Label("Добавить блюдо", systemImage: "plus.circle.fill")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity).frame(height: 48)
                                    .background(Color.green.opacity(0.12))
                                    .foregroundStyle(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green, lineWidth: 1.5))
                            }
                            .disabled(dishName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                        .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48)).foregroundStyle(.green)
                            Text("«\(dishName)» добавлено!")
                                .font(.headline)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 20).padding(.bottom, 20)
            }

            wizardFooter(
                nextLabel: "Готово",
                nextEnabled: true,
                nextColor: .green,
                onBack: { withAnimation { step = 1 } },
                onNext: { withAnimation { step = 3 } },
                skipLabel: dishAdded ? nil : "Пропустить",
                onSkip: { withAnimation { step = 3 } }
            )
        }
    }

    // MARK: Шаг 4 — Итог

    private var wizardStep4: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    stepIcon("checkmark.seal.fill", color: .purple)

                    VStack(spacing: 6) {
                        Text("Всё готово!")
                            .font(.title2.bold())
                        Text(store.restaurantName)
                            .font(.title3.bold())
                            .foregroundStyle(.chefAccent)
                    }

                    // Итоговый список
                    VStack(spacing: 0) {
                        summaryRow(icon: "building.2.fill", color: .chefAccent,
                                   title: "Заведение", value: store.restaurantName)
                        Divider().padding(.leading, 52)
                        if let emp = store.currentEmployee {
                            summaryRow(icon: "person.fill.checkmark", color: .blue,
                                       title: "Менеджер", value: "\(emp.name), \(emp.position)")
                            Divider().padding(.leading, 52)
                        }
                        summaryRow(icon: "lock.fill", color: .orange,
                                   title: "PIN-код", value: "Настроен")
                        if dishAdded && !dishName.isEmpty {
                            Divider().padding(.leading, 52)
                            summaryRow(icon: "fork.knife.circle.fill", color: .green,
                                       title: "Первое блюдо", value: dishName)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20).padding(.bottom, 20)
            }

            VStack(spacing: 12) {
                Button(action: onFinish) {
                    Label("Начать работу", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Color.chefAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
            .padding(.top, 8)
        }
    }

    // MARK: - Вспомогательные компоненты

    private func stepIcon(_ name: String, color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.12)).frame(width: 100, height: 100)
            Circle().fill(color.opacity(0.08)).frame(width: 120, height: 120)
            Image(systemName: name)
                .font(.system(size: 46))
                .foregroundStyle(color)
        }
    }

    private func inputField(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        required: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(label).font(.caption.bold()).foregroundStyle(.secondary)
                if required { Text("*").font(.caption.bold()).foregroundStyle(.red) }
            }
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func summaryRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.caption.bold()).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.bold()).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    @ViewBuilder
    private func wizardFooter(
        nextLabel: String,
        nextEnabled: Bool,
        nextColor: Color,
        onBack: (() -> Void)?,
        onNext: @escaping () -> Void,
        skipLabel: String? = nil,
        onSkip: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 10) {
            Button(action: onNext) {
                Text(nextLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(nextEnabled ? nextColor : Color(.systemGray5))
                    .foregroundStyle(nextEnabled ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!nextEnabled)
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            HStack {
                if let onBack {
                    Button("← Назад", action: onBack)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let skipLabel, let onSkip {
                    Button(skipLabel, action: onSkip)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 44)
        .padding(.top, 8)
    }
}

// MARK: - Слайды для существующих пользователей

struct OnboardingPage {
    let icon: String
    let gradient: [Color]
    let title: String
    let body: String
    let features: [String]
}

struct OnboardingSlidesView: View {
    @EnvironmentObject var store: ChefProStore
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(icon: "fork.knife.circle.fill", gradient: [.orange, .red],
                       title: "Добро пожаловать\nв ChefPro",
                       body: "Полное управление рестораном в одном приложении",
                       features: ["📦 Склад и закупки", "📊 Аналитика и P&L", "👨‍🍳 Команда и смены"]),
        OnboardingPage(icon: "book.fill", gradient: [.blue, .purple],
                       title: "Техкарты и рецепты",
                       body: "Создавайте рецепты, считайте food cost автоматически",
                       features: ["🧮 Автоподсчёт себестоимости", "🌡 HACCP и температуры", "📸 Фото пошагово"]),
        OnboardingPage(icon: "shippingbox.fill", gradient: [.green, .teal],
                       title: "Склад под контролем",
                       body: "Остатки, срок годности, автозаказ поставщикам",
                       features: ["⚠️ Уведомления о низком остатке", "📅 Контроль срока годности", "🏷 Штрихкоды"]),
        OnboardingPage(icon: "rectangle.3.group.fill", gradient: [.purple, .pink],
                       title: "Kitchen Board",
                       body: "Доска для кухни — заказы в реальном времени",
                       features: ["⏱ Таймеры по заказам", "🔔 Уведомления готовности", "📋 Режим официанта"]),
        OnboardingPage(icon: "chart.line.uptrend.xyaxis", gradient: [.red, .orange],
                       title: "Аналитика и P&L",
                       body: "Food cost, выручка, Menu Engineering",
                       features: ["💰 P&L по периодам", "🏆 Рейтинг прибыльности", "📈 ABC-анализ склада"]),
        OnboardingPage(icon: "star.circle.fill", gradient: [.yellow, .orange],
                       title: "Всё для гостей",
                       body: "Бронирование, лояльность и интеграция с кассой",
                       features: ["📅 Бронирование столиков", "⭐️ Программа лояльности", "🖥 Интеграция POS"]),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: pages[page].gradient.map { $0.opacity(0.13) } + [Color(.systemBackground)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: page)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Пропустить") { onFinish() }
                        .font(.subheadline).foregroundStyle(.secondary).padding()
                }

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        slideContent(pages[i], isActive: i == page).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: page)

                VStack(spacing: 18) {
                    // Точки прогресса
                    HStack(spacing: 7) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? Color.chefAccent : Color(.systemGray5))
                                .frame(width: i == page ? 22 : 7, height: 7)
                                .animation(.spring(response: 0.3), value: page)
                        }
                    }

                    if page < pages.count - 1 {
                        Button {
                            withAnimation(.spring()) { page += 1 }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Далее")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(LinearGradient(colors: pages[page].gradient, startPoint: .leading, endPoint: .trailing))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                store.populateDemoData(); onFinish()
                            } label: {
                                Label("Загрузить демо-данные", systemImage: "doc.text.magnifyingglass")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity).frame(height: 48)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(.chefAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.chefAccent.opacity(0.4), lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)

                            Button(action: onFinish) {
                                HStack(spacing: 8) {
                                    Text("Начать работу")
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
    }

    @ViewBuilder
    private func slideContent(_ p: OnboardingPage, isActive: Bool) -> some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: p.gradient.map { $0.opacity(0.18) },
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(LinearGradient(colors: p.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: p.gradient[0].opacity(0.4), radius: 18, x: 0, y: 8)
                Image(systemName: p.icon)
                    .font(.system(size: 46)).foregroundStyle(.white)
            }
            .scaleEffect(isActive ? 1 : 0.82)
            .opacity(isActive ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)

            VStack(spacing: 10) {
                Text(p.title)
                    .font(.title.bold()).multilineTextAlignment(.center).padding(.horizontal, 24)
                Text(p.body)
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 36)
            }

            VStack(spacing: 8) {
                ForEach(p.features, id: \.self) { f in
                    Text(f)
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }

            Spacer()
            Spacer()
        }
    }
}
