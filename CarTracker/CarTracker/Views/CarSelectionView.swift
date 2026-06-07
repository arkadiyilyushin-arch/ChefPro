import SwiftUI

struct CarSelectionView: View {
    @EnvironmentObject var vm: ExpenseViewModel
    @State private var showAddCar = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.cars.isEmpty {
                    emptyState
                } else {
                    carList
                }
            }
            .navigationTitle("Мои автомобили")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddCar = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showAddCar) {
                AddCarView()
                    .environmentObject(vm)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.2.fill")
                .font(.system(size: 70))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Нет автомобилей")
                .font(.title2.bold())
            Text("Добавьте свой первый автомобиль\nдля учёта расходов")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddCar = true
            } label: {
                Label("Добавить автомобиль", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var carList: some View {
        List {
            ForEach(vm.cars) { car in
                CarRowView(car: car, isSelected: car.id == vm.selectedCarId)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            vm.selectCar(car)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: vm.deleteCar)

            Button {
                showAddCar = true
            } label: {
                Label("Добавить автомобиль", systemImage: "plus.circle")
                    .foregroundColor(.accentColor)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

struct CarRowView: View {
    let car: Car
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: car.colorHex).opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: car.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(car.displayName)
                    .font(.headline)
                HStack {
                    Text(String(car.year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !car.licensePlate.isEmpty {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(car.licensePlate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: isSelected ? .accentColor.opacity(0.2) : .clear, radius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}

struct AddCarView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: ExpenseViewModel

    @State private var brand = ""
    @State private var model = ""
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var licensePlate = ""
    @State private var selectedColor = "#4A90E2"
    @State private var showBrandPicker = false

    let carColors = ["#E74C3C","#E67E22","#F1C40F","#2ECC71","#1ABC9C",
                     "#3498DB","#9B59B6","#34495E","#ECF0F1","#2C3E50"]

    var isValid: Bool { !brand.isEmpty && !model.isEmpty }

    var body: some View {
        NavigationView {
            Form {
                Section("Марка и модель") {
                    Button {
                        showBrandPicker = true
                    } label: {
                        HStack {
                            Text("Марка")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(brand.isEmpty ? "Выбрать" : brand)
                                .foregroundColor(brand.isEmpty ? .secondary : .accentColor)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    TextField("Модель", text: $model)
                }

                Section("Год выпуска") {
                    Stepper("\(year) г.", value: $year, in: 1980...Calendar.current.component(.year, from: Date()))
                }

                Section("Гос. номер (необязательно)") {
                    TextField("А000АА 000", text: $licensePlate)
                        .textInputAutocapitalization(.characters)
                }

                Section("Цвет значка") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(carColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == hex ? 3 : 0)
                                )
                                .shadow(color: Color(hex: hex).opacity(0.5), radius: selectedColor == hex ? 6 : 0)
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Новый автомобиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let car = Car(brand: brand, model: model, year: year,
                                     licensePlate: licensePlate, colorHex: selectedColor)
                        vm.addCar(car)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .bold()
                }
            }
            .sheet(isPresented: $showBrandPicker) {
                BrandPickerView(selected: $brand)
            }
        }
    }
}

struct BrandPickerView: View {
    @Binding var selected: String
    @Environment(\.dismiss) var dismiss
    @State private var search = ""

    var filtered: [String] {
        search.isEmpty ? popularCarBrands : popularCarBrands.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationView {
            List(filtered, id: \.self) { brand in
                HStack {
                    Text(brand)
                    Spacer()
                    if selected == brand {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selected = brand
                    dismiss()
                }
            }
            .searchable(text: $search, prompt: "Поиск марки")
            .navigationTitle("Марка автомобиля")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
