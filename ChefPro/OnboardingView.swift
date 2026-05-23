import SwiftUI

// MARK: - Onboarding

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [(icon: String, color: Color, title: String, body: String)] = [
        ("fork.knife.circle.fill",      .orange, "Добро пожаловать в ChefPro",    "Управление рестораном в одном приложении — склад, производство, аналитика и команда."),
        ("book.fill",                   .blue,   "Техкарты и рецепты",            "Создавайте рецепты с ингредиентами, считайте food cost автоматически и задавайте время готовки."),
        ("shippingbox.fill",            .green,  "Склад и закупки",               "Отслеживайте остатки, срок годности, единицы заказа. Приложение сообщит, что нужно заказать."),
        ("rectangle.3.group.fill",      .purple, "Kitchen Board",                 "Канбан-доска для кухни с таймерами по каждому заказу. Статус меняется одним тапом."),
        ("chart.line.uptrend.xyaxis",   .red,    "Аналитика и P&L",              "Food cost, динамика продаж, Menu Engineering и P&L — всё в реальном времени."),
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        let p = pages[i]
                        VStack(spacing: 28) {
                            Spacer()
                            ZStack {
                                Circle().fill(p.color.opacity(0.15)).frame(width: 140, height: 140)
                                Image(systemName: p.icon)
                                    .font(.system(size: 64)).foregroundStyle(p.color)
                            }
                            VStack(spacing: 14) {
                                Text(p.title)
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                Text(p.body)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            Spacer()
                            Spacer()
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 12) {
                    if page < pages.count - 1 {
                        Button {
                            withAnimation { page += 1 }
                        } label: {
                            Text("Далее")
                                .font(.headline)
                                .frame(maxWidth: .infinity).frame(height: 56)
                                .background(Color.chefAccent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        Button("Пропустить") { onFinish() }
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Button {
                            onFinish()
                        } label: {
                            Text("Начать работу")
                                .font(.headline)
                                .frame(maxWidth: .infinity).frame(height: 56)
                                .background(Color.chefAccent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
