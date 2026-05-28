import SwiftUI

// MARK: - Loyalty Program

struct LoyaltyView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd       = false
    @State private var searchText    = ""
    @State private var selectedCard: LoyaltyCard? = nil
    @State private var showAddPurchase = false
    @State private var purchaseCard: LoyaltyCard? = nil

    private var filtered: [LoyaltyCard] {
        if searchText.isEmpty { return store.loyaltyCards.sorted { $0.totalSpent > $1.totalSpent } }
        return store.loyaltyCards.filter {
            $0.guestName.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.contains(searchText) ||
            $0.cardNumber.contains(searchText)
        }
    }

    private var totalMembers:  Int    { store.loyaltyCards.count }
    private var totalPoints:   Int    { store.loyaltyCards.reduce(0) { $0 + $1.points } }
    private var totalSpent:    Double { store.loyaltyCards.reduce(0) { $0 + $1.totalSpent } }
    private var goldPlatinum:  Int    { store.loyaltyCards.filter { $0.tier == .gold || $0.tier == .platinum }.count }

    var body: some View {
        NavigationStack {
            List {
                // ── Stats ─────────────────────────────────────
                Section {
                    HStack(spacing: 0) {
                        statCell(icon: "person.2.fill",   value: "\(totalMembers)", label: "Гостей",   color: .blue)
                        Divider()
                        statCell(icon: "star.fill",        value: "\(totalPoints)", label: "Баллов",   color: .yellow)
                        Divider()
                        statCell(icon: "crown.fill",       value: "\(goldPlatinum)", label: "VIP",     color: .orange)
                    }
                    .frame(height: 70)
                }

                // ── Tier distribution ─────────────────────────
                Section("Уровни") {
                    ForEach(LoyaltyTier.allCases, id: \.self) { tier in
                        let count = store.loyaltyCards.filter { $0.tier == tier }.count
                        HStack {
                            Image(systemName: tier.icon).foregroundStyle(tier.color)
                            Text(tier.rawValue)
                            Text("—").foregroundStyle(.secondary)
                            Text("скидка \(tier.discount)%").foregroundStyle(.secondary).font(.caption)
                            Spacer()
                            if count > 0 {
                                Text("\(count) чел.")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(tier.color.opacity(0.15))
                                    .foregroundStyle(tier.color)
                                    .clipShape(Capsule())
                            } else {
                                Text("—").foregroundStyle(.secondary).font(.caption)
                            }
                        }
                    }
                }

                // ── Cards ─────────────────────────────────────
                Section("Карты гостей") {
                    if filtered.isEmpty {
                        Text(store.loyaltyCards.isEmpty ? "Нет карт" : "Не найдено")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    ForEach(filtered) { card in
                        LoyaltyCardRow(card: card)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedCard = card }
                            .swipeActions(edge: .leading) {
                                Button {
                                    purchaseCard = card
                                    showAddPurchase = true
                                } label: {
                                    Label("Начислить", systemImage: "plus.circle.fill")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.deleteLoyaltyCard(card)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Имя, телефон или номер карты")
            .navigationTitle("Программа лояльности")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddLoyaltyCardView { card in store.addLoyaltyCard(card) }
            }
            .sheet(item: $selectedCard) { card in
                LoyaltyCardDetailView(card: card)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAddPurchase) {
                if let card = purchaseCard {
                    AddLoyaltyPurchaseView(card: card) { amount, desc in
                        store.addPurchaseToLoyalty(cardID: card.id, amount: amount, description: desc)
                    }
                }
            }
        }
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Card Row

struct LoyaltyCardRow: View {
    let card: LoyaltyCard

    var body: some View {
        HStack(spacing: 12) {
            // Tier icon
            ZStack {
                Circle()
                    .fill(card.tier.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: card.tier.icon)
                    .foregroundStyle(card.tier.color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.guestName).font(.headline)
                HStack(spacing: 6) {
                    Text(card.tier.rawValue).foregroundStyle(card.tier.color).font(.caption.bold())
                    Text("·").foregroundStyle(.secondary)
                    Text(card.phone.isEmpty ? card.cardNumber : card.phone)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(card.points) б.")
                    .font(.subheadline.bold())
                    .foregroundStyle(.chefAccent)
                Text("\(Int(card.totalSpent)) ₽")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Card Detail

struct LoyaltyCardDetailView: View {
    let card: LoyaltyCard
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss
    @State private var showRedeem = false
    @State private var showAddPurchase = false
    @State private var redeemPoints = ""

    private var currentCard: LoyaltyCard {
        store.loyaltyCards.first { $0.id == card.id } ?? card
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Card visual ────────────────────────────
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                colors: [currentCard.tier.color, currentCard.tier.color.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: currentCard.tier.icon)
                                    .font(.title2)
                                Text(currentCard.tier.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text("скидка \(currentCard.tier.discount)%")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.white)

                            Spacer()

                            Text(currentCard.guestName)
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            HStack {
                                Text(currentCard.cardNumber)
                                    .font(.caption)
                                Spacer()
                                Text(currentCard.phone)
                                    .font(.caption)
                            }
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(20)
                    }
                    .frame(height: 180)
                    .padding(.horizontal)

                    // ── Points & stats ─────────────────────────
                    HStack(spacing: 0) {
                        infoCell(value: "\(currentCard.points)", label: "Баллов", color: .chefAccent)
                        Divider()
                        infoCell(value: "\(Int(currentCard.totalSpent)) ₽", label: "Потрачено", color: .green)
                        Divider()
                        infoCell(value: "\(currentCard.visitsCount)", label: "Визитов", color: .blue)
                    }
                    .frame(height: 70)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Next tier progress
                    if currentCard.tier != .platinum {
                        let tiers = LoyaltyTier.allCases
                        if let idx = tiers.firstIndex(of: currentCard.tier), idx + 1 < tiers.count {
                            let next = tiers[idx + 1]
                            let progress = currentCard.totalSpent / next.minSpent
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("До уровня \(next.rawValue)")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("\(Int(next.minSpent - currentCard.totalSpent)) ₽")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: min(progress, 1.0))
                                    .tint(next.color)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }

                    // ── Actions ────────────────────────────────
                    HStack(spacing: 12) {
                        Button {
                            showAddPurchase = true
                        } label: {
                            Label("Начислить баллы", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            showRedeem = true
                        } label: {
                            Label("Списать баллы", systemImage: "minus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)

                    // ── Transaction history ────────────────────
                    if !currentCard.transactions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("История").font(.headline)
                                .padding(.horizontal).padding(.bottom, 8)

                            ForEach(currentCard.transactions.prefix(20)) { tx in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tx.description.isEmpty ? "Покупка" : tx.description)
                                            .font(.subheadline)
                                        Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(tx.points > 0 ? "+\(tx.points) б." : "\(tx.points) б.")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(tx.points > 0 ? .green : .red)
                                        Text("\(Int(abs(tx.amount))) ₽")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                Divider().padding(.leading)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Карта гостя")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddPurchase) {
                AddLoyaltyPurchaseView(card: currentCard) { amount, desc in
                    store.addPurchaseToLoyalty(cardID: currentCard.id, amount: amount, description: desc)
                }
            }
            .sheet(isPresented: $showRedeem) {
                RedeemPointsView(card: currentCard) { points in
                    store.redeemLoyaltyPoints(cardID: currentCard.id, points: points)
                }
            }
        }
    }

    private func infoCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Loyalty Card

struct AddLoyaltyCardView: View {
    let onSave: (LoyaltyCard) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name  = ""
    @State private var phone = ""
    @State private var email = ""

    private func generateCardNumber() -> String {
        let n = Int.random(in: 100_000_000...999_999_999)
        return "CP-\(n)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Данные гостя") {
                    TextField("Имя", text: $name)
                    TextField("Телефон", text: $phone).keyboardType(.phonePad)
                    TextField("Email (необязательно)", text: $email).keyboardType(.emailAddress)
                }
                Section {
                    Text("Карта создастся автоматически на уровне Бронза.\nНакопив 10 000 ₽ — переход на Серебро.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Новая карта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        guard !name.isEmpty else { return }
                        let card = LoyaltyCard(
                            cardNumber: generateCardNumber(),
                            guestName: name,
                            phone: phone,
                            email: email
                        )
                        onSave(card)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Purchase

struct AddLoyaltyPurchaseView: View {
    let card: LoyaltyCard
    let onSave: (Double, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var amount      = ""
    @State private var description = ""

    private var parsedAmount: Double { Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var earnedPoints: Int    { Int(parsedAmount / 100) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Гость") {
                    HStack {
                        Image(systemName: card.tier.icon).foregroundStyle(card.tier.color)
                        Text(card.guestName).bold()
                        Spacer()
                        Text("Баллов: \(card.points)").foregroundStyle(.secondary).font(.caption)
                    }
                }
                Section("Покупка") {
                    HStack {
                        TextField("Сумма покупки", text: $amount)
                            .keyboardType(.decimalPad)
                        Text("₽").foregroundStyle(.secondary)
                    }
                    TextField("Комментарий (необязательно)", text: $description)
                }
                if parsedAmount > 0 {
                    Section("Начислится") {
                        HStack {
                            Text("Баллов")
                            Spacer()
                            Text("+\(earnedPoints) б.").font(.headline).foregroundStyle(.green)
                        }
                        HStack {
                            Text("Скидка за текущий уровень")
                            Spacer()
                            Text("\(card.tier.discount)%").foregroundStyle(card.tier.color)
                        }
                    }
                }
            }
            .navigationTitle("Начислить баллы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Начислить") {
                        guard parsedAmount > 0 else { return }
                        onSave(parsedAmount, description)
                        dismiss()
                    }
                    .disabled(parsedAmount <= 0)
                }
            }
        }
    }
}

// MARK: - Redeem Points

struct RedeemPointsView: View {
    let card: LoyaltyCard
    let onRedeem: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pointsStr = ""

    private var points: Int { Int(pointsStr) ?? 0 }
    private var discount: Double { Double(points) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Доступно баллов") {
                    HStack {
                        Text("\(card.points) б.")
                            .font(.title2.bold())
                            .foregroundStyle(.chefAccent)
                        Text("= \(card.points) ₽")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Списать") {
                    HStack {
                        TextField("Количество баллов", text: $pointsStr)
                            .keyboardType(.numberPad)
                        Text("б.").foregroundStyle(.secondary)
                    }
                    if points > 0 {
                        HStack {
                            Text("Скидка на чек")
                            Spacer()
                            Text("\(Int(discount)) ₽").foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Списать баллы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Списать") {
                        guard points > 0, points <= card.points else { return }
                        onRedeem(points)
                        dismiss()
                    }
                    .disabled(points <= 0 || points > card.points)
                }
            }
        }
    }
}
