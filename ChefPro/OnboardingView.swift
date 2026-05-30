import SwiftUI

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject var store: ChefProStore
    let onFinish: () -> Void

    /// Show the setup wizard when there are no employees yet (truly fresh install).
    /// Show the feature slides when demo data is loaded or employees already exist.
    private var showWizard: Bool {
        store.employees.isEmpty && store.restaurantName == "Demo Restaurant"
    }

    var body: some View {
        if showWizard {
            SetupWizardView(onFinish: onFinish)
                .environmentObject(store)
        } else {
            OnboardingSlidesView(onFinish: onFinish)
                .environmentObject(store)
        }
    }
}

// MARK: - Setup Wizard (manager first-run)

struct SetupWizardView: View {
    @EnvironmentObject var store: ChefProStore
    let onFinish: () -> Void

    @State private var step = 0

    // Step 1 — Restaurant
    @State private var restaurantName = ""
    @State private var city = ""

    // Step 2 — First employee
    @State private var employeeName = ""
    @State private var position = "Менеджер"
    @State private var pin = ""
    @State private var pinConfirm = ""
    @State private var pinMismatch = false

    // Step 3 — First dish (optional)
    @State private var dishName = ""
    @State private var dishPrice = ""
    @State private var dishAdded = false

    // Step 4 — Summary is computed

    private var pinValid: Bool { pin.count == 4 && pin == pinConfirm }
    private var step1Valid: Bool { !restaurantName.trimmingCharacters(in: .whitespaces).isEmpty }
    private var step2Valid: Bool { !employeeName.trimmingCharacters(in: .whitespaces).isEmpty && pinValid }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 6) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i <= step ? Color.chefAccent : Color(.tertiarySystemBackground))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
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

    // MARK: Step 1 — Restaurant

    private var wizardStep1: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    ZStack {
                        Circle().fill(Color.chefAccent.opacity(0.15)).frame(width: 110, height: 110)
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.chefAccent)
                    }

                    VStack(spacing: 8) {
                        Text("Ваш ресторан")
                            .font(.title2.bold())
                        Text("Укажите название заведения")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Название ресторана *")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("Например: Ресторан «Берёзка»", text: $restaurantName)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Город (необязательно)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("Москва", text: $city)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }

            wizardNavBar(
                backLabel: nil,
                nextLabel: "Далее",
                nextEnabled: step1Valid,
                onBack: nil,
                onNext: {
                    store.restaurantName = restaurantName.trimmingCharacters(in: .whitespaces)
                    withAnimation { step = 1 }
                }
            )
        }
    }

    // MARK: Step 2 — First employee

    private var wizardStep2: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    ZStack {
                        Circle().fill(Color.blue.opacity(0.15)).frame(width: 110, height: 110)
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 8) {
                        Text("Первый сотрудник")
                            .font(.title2.bold())
                        Text("Создайте учётную запись менеджера")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Имя и фамилия *")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("Иван Петров", text: $employeeName)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Должность")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("Менеджер", text: $position)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("PIN-код (4 цифры) *")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            SecureField("••••", text: $pin)
                                .keyboardType(.numberPad)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onChange(of: pin) {
                                    pin = String(pin.prefix(4).filter { $0.isNumber })
                                }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Подтвердите PIN *")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            SecureField("••••", text: $pinConfirm)
                                .keyboardType(.numberPad)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onChange(of: pinConfirm) {
                                    pinConfirm = String(pinConfirm.prefix(4).filter { $0.isNumber })
                                    pinMismatch = !pinConfirm.isEmpty && pinConfirm != pin
                                }
                            if pinMismatch {
                                Text("PIN-коды не совпадают")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }

            wizardNavBar(
                backLabel: "Назад",
                nextLabel: "Далее",
                nextEnabled: step2Valid,
                onBack: { withAnimation { step = 0 } },
                onNext: {
                    let emp = Employee(
                        name: employeeName.trimmingCharacters(in: .whitespaces),
                        position: position.isEmpty ? "Менеджер" : position,
                        phone: "",
                        pin: pin,
                        permissions: ["Техкарты", "Склад", "Приемка", "Списания", "Отчеты", "Настройки"]
                    )
                    store.addEmployee(emp)
                    store.currentEmployeeID = emp.id
                    store.profile = UserProfile(
                        name: emp.name,
                        position: emp.position,
                        phone: emp.phone,
                        permissions: emp.permissions
                    )
                    withAnimation { step = 2 }
                }
            )
        }
    }

    // MARK: Step 3 — First dish (optional)

    private var wizardStep3: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    ZStack {
                        Circle().fill(Color.green.opacity(0.15)).frame(width: 110, height: 110)
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 8) {
                        Text("Первое блюдо")
                            .font(.title2.bold())
                        Text("Добавьте первое блюдо или пропустите — вы сможете сделать это позже")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    if !dishAdded {
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Название блюда")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                TextField("Борщ классический", text: $dishName)
                                    .padding(14)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Цена продажи (₽)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $dishPrice)
                                    .keyboardType(.decimalPad)
                                    .padding(14)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                let trimmedName = dishName.trimmingCharacters(in: .whitespaces)
                                guard !trimmedName.isEmpty else { return }
                                let price = parsePositiveDouble(dishPrice) ?? 0
                                let newDish = Dish(
                                    name: trimmedName,
                                    category: "Основные блюда",
                                    salePrice: price,
                                    ingredients: []
                                )
                                store.dishes.append(newDish)
                                dishAdded = true
                            } label: {
                                Label("Добавить блюдо", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.chefAccent.opacity(0.15))
                                    .foregroundStyle(.chefAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.chefAccent, lineWidth: 1.5))
                            }
                            .disabled(dishName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.green)
                            Text("«\(dishName)» добавлено!")
                                .font(.headline)
                        }
                    }

                    Spacer()
                }
            }

            wizardNavBar(
                backLabel: "Назад",
                nextLabel: "Готово",
                nextEnabled: true,
                onBack: { withAnimation { step = 1 } },
                onNext: { withAnimation { step = 3 } },
                skipLabel: dishAdded ? nil : "Добавить позже",
                onSkip: { withAnimation { step = 3 } }
            )
        }
    }

    // MARK: Step 4 — Summary

    private var wizardStep4: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 24)

                    ZStack {
                        Circle().fill(Color.chefAccent.opacity(0.15)).frame(width: 110, height: 110)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.chefAccent)
                    }

                    VStack(spacing: 8) {
                        Text("Добро пожаловать в ChefPro!")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(store.restaurantName)
                            .font(.title3)
                            .foregroundStyle(.chefAccent)
                            .bold()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Что настроено:")
                            .font(.headline)
                            .padding(.bottom, 4)

                        SetupRow(icon: "building.2.fill", color: .chefAccent,
                                 text: "Ресторан «\(store.restaurantName)»")

                        if let emp = store.currentEmployee {
                            SetupRow(icon: "person.fill.checkmark", color: .blue,
                                     text: "\(emp.name), \(emp.position)")
                        }

                        if dishAdded && !dishName.isEmpty {
                            SetupRow(icon: "fork.knife.circle.fill", color: .green,
                                     text: "Первое блюдо: \(dishName)")
                        }

                        SetupRow(icon: "lock.fill", color: .orange,
                                 text: "PIN-код для входа настроен")
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }

            VStack(spacing: 12) {
                Button {
                    onFinish()
                } label: {
                    Text("Начать работу")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.chefAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Nav bar helper

    @ViewBuilder
    private func wizardNavBar(
        backLabel: String?,
        nextLabel: String,
        nextEnabled: Bool,
        onBack: (() -> Void)?,
        onNext: @escaping () -> Void,
        skipLabel: String? = nil,
        onSkip: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 10) {
            Button(action: onNext) {
                Text(nextLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(nextEnabled ? Color.chefAccent : Color(.tertiarySystemBackground))
                    .foregroundStyle(nextEnabled ? Color.white : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(!nextEnabled)

            HStack {
                if let backLabel, let onBack {
                    Button(backLabel, action: onBack)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let skipLabel, let onSkip {
                    Button(skipLabel, action: onSkip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .padding(.top, 8)
    }
}

private struct SetupRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Feature Slides 2.0

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
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "fork.knife.circle.fill",
            gradient: [.orange, .red],
            title: "Добро пожаловать\nв ChefPro",
            body: "Полное управление рестораном в одном приложении",
            features: ["📦 Склад и закупки", "📊 Аналитика и P&L", "👨‍🍳 Команда и смены"]
        ),
        OnboardingPage(
            icon: "book.fill",
            gradient: [.blue, .purple],
            title: "Техкарты и рецепты",
            body: "Создавайте рецепты, считайте food cost автоматически",
            features: ["🧮 Автоподсчёт себестоимости", "🌡 HACCP и температуры", "📸 Фото пошагово"]
        ),
        OnboardingPage(
            icon: "shippingbox.fill",
            gradient: [.green, .teal],
            title: "Склад под контролем",
            body: "Остатки, срок годности, автозаказ поставщикам",
            features: ["⚠️ Уведомления о низком остатке", "📅 Контроль срока годности", "🏷 Штрихкоды"]
        ),
        OnboardingPage(
            icon: "rectangle.3.group.fill",
            gradient: [.purple, .pink],
            title: "Kitchen Board",
            body: "Канбан-доска для кухни — заказы в реальном времени",
            features: ["⏱ Таймеры по заказам", "🔔 Уведомления готовности", "📋 Режим официанта"]
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            gradient: [.red, .orange],
            title: "Аналитика и P&L",
            body: "Food cost, выручка, Menu Engineering — всё в реальном времени",
            features: ["💰 P&L по периодам", "🏆 Рейтинг прибыльности", "📈 ABC-анализ склада"]
        ),
        OnboardingPage(
            icon: "star.circle.fill",
            gradient: [.yellow, .orange],
            title: "Всё для гостей",
            body: "Бронирование, лояльность и интеграция с кассой",
            features: ["📅 Бронирование столиков", "⭐️ Программа лояльности", "🖥 Интеграция POS"]
        ),
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: pages[page].gradient.map { $0.opacity(0.15) } + [Color(.systemBackground)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: page)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Пропустить") { onFinish() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                // Slide content
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        slideContent(pages[i], isActive: i == page)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: page)

                // Dots + buttons
                VStack(spacing: 20) {
                    // Custom dots
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? Color.chefAccent : Color(.tertiarySystemBackground))
                                .frame(width: i == page ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: page)
                        }
                    }

                    if page < pages.count - 1 {
                        Button {
                            withAnimation(.spring()) { page += 1 }
                        } label: {
                            HStack {
                                Text("Далее")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(
                                LinearGradient(colors: pages[page].gradient,
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button {
                                store.populateDemoData()
                                onFinish()
                            } label: {
                                Label("Загрузить демо-данные", systemImage: "doc.text.magnifyingglass")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity).frame(height: 52)
                                    .background(Color.chefAccent.opacity(0.12))
                                    .foregroundStyle(.chefAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.chefAccent, lineWidth: 1.5))
                            }
                            Button {
                                onFinish()
                            } label: {
                                Text("Начать работу →")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity).frame(height: 56)
                                    .background(
                                        LinearGradient(colors: [.orange, .red],
                                                       startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                            }
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
        VStack(spacing: 24) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: p.gradient.map { $0.opacity(0.2) },
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 150, height: 150)
                Circle()
                    .fill(LinearGradient(colors: p.gradient,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                    .shadow(color: p.gradient[0].opacity(0.4), radius: 20, x: 0, y: 10)
                Image(systemName: p.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isActive ? 1.0 : 0.8)
            .opacity(isActive ? 1.0 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)

            VStack(spacing: 12) {
                Text(p.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(p.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            // Feature pills
            VStack(spacing: 8) {
                ForEach(p.features, id: \.self) { f in
                    Text(f)
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }

            Spacer()
            Spacer()
        }
    }
}
