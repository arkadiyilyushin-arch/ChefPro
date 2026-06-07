import SwiftUI

struct ContentView: View {
    @StateObject var vm = ExpenseViewModel()
    @StateObject var settings = AppSettings()
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if vm.cars.isEmpty {
                onboardingView
            } else {
                mainTabView
            }
        }
        .environmentObject(vm)
        .environmentObject(settings)
        .preferredColorScheme(settings.theme.colorScheme)
    }

    // MARK: - Онбординг

    private var onboardingView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.15), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 120, height: 120)
                        Image(systemName: "car.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.accentColor)
                    }

                    Text("CarTracker")
                        .font(.system(size: 36, weight: .black, design: .rounded))

                    Text("Учёт расходов на автомобиль:\nтопливо, сервис и многое другое")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    featureRow(icon: "fuelpump.fill", color: .orange,
                               title: "Топливо", subtitle: "Расход и средняя стоимость")
                    featureRow(icon: "wrench.and.screwdriver.fill", color: .blue,
                               title: "Сервис", subtitle: "Ремонт и техобслуживание")
                    featureRow(icon: "ellipsis.circle.fill", color: .purple,
                               title: "Прочее", subtitle: "Штрафы, мойка, страховка")
                    featureRow(icon: "speedometer", color: .green,
                               title: "Пробег", subtitle: "История и средний расход")
                }
                .padding(.horizontal)

                Spacer()

                AddCarButton()
                    .environmentObject(vm)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Основной экран

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            ExpenseListView()
                .environmentObject(vm)
                .tabItem { Label("Расходы", systemImage: "list.bullet.rectangle") }
                .tag(0)

            StatisticsView()
                .environmentObject(vm)
                .tabItem { Label("Статистика", systemImage: "chart.pie.fill") }
                .tag(1)

            CarSelectionView()
                .environmentObject(vm)
                .tabItem { Label("Автомобили", systemImage: "car.2.fill") }
                .tag(2)

            SettingsView()
                .environmentObject(vm)
                .environmentObject(settings)
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(.accentColor)
    }
}

struct AddCarButton: View {
    @EnvironmentObject var vm: ExpenseViewModel
    @State private var showAdd = false

    var body: some View {
        Button {
            showAdd = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill").font(.title3)
                Text("Добавить автомобиль").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .accentColor.opacity(0.4), radius: 12, y: 4)
        }
        .sheet(isPresented: $showAdd) {
            AddCarView().environmentObject(vm)
        }
    }
}
