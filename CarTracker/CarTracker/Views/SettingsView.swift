import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case system = "Системная"
    case light  = "Светлая"
    case dark   = "Тёмная"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
}

class AppSettings: ObservableObject {
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "app_theme") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "app_theme") ?? ""
        theme = AppTheme(rawValue: saved) ?? .system
    }
}

struct SettingsView: View {
    @EnvironmentObject var vm: ExpenseViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationView {
            List {
                // Тема
                Section("Внешний вид") {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            withAnimation { settings.theme = theme }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(settings.theme == theme
                                              ? Color.accentColor.opacity(0.15)
                                              : Color(.tertiarySystemGroupedBackground))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: theme.icon)
                                        .foregroundColor(settings.theme == theme ? .accentColor : .secondary)
                                        .font(.subheadline)
                                }
                                Text(theme.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if settings.theme == theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                // Автомобили
                Section("Автомобили") {
                    ForEach(vm.cars) { car in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: car.colorHex).opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "car.fill")
                                        .foregroundColor(Color(hex: car.colorHex))
                                        .font(.caption)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(car.displayName).font(.subheadline)
                                Text("\(car.year)" + (car.licensePlate.isEmpty ? "" : " · \(car.licensePlate)"))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if car.id == vm.selectedCarId {
                                Text("Активный")
                                    .font(.caption2.bold())
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Данные
                Section("Данные") {
                    HStack {
                        Label("Записей", systemImage: "doc.text")
                        Spacer()
                        Text("\(vm.expenses.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Автомобилей", systemImage: "car.2")
                        Spacer()
                        Text("\(vm.cars.count)")
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить все данные", systemImage: "trash")
                    }
                }

                Section("О приложении") {
                    HStack {
                        Label("Версия", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Настройки")
            .alert("Удалить все данные?", isPresented: $showDeleteAlert) {
                Button("Удалить", role: .destructive) {
                    vm.expenses.removeAll()
                    vm.cars.removeAll()
                    vm.selectedCarId = nil
                    UserDefaults.standard.removeObject(forKey: "saved_cars")
                    UserDefaults.standard.removeObject(forKey: "saved_expenses")
                    UserDefaults.standard.removeObject(forKey: "selected_car_id")
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все автомобили и записи будут удалены безвозвратно.")
            }
        }
    }
}
