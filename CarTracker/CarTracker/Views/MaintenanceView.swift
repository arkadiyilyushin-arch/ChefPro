import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var vm: ExpenseViewModel
    @State private var showAdd = false
    @State private var editingItem: MaintenanceItem? = nil

    var overdueCount: Int {
        vm.currentMaintenanceItems.filter { $0.isOverdue(currentMileage: vm.lastMileage) }.count
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        if overdueCount > 0 {
                            alertBanner
                        }
                        if vm.currentMaintenanceItems.isEmpty {
                            emptyState
                        } else {
                            itemsList
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 90)
                }

                addButton
            }
            .navigationTitle("Плановое ТО")
            .sheet(isPresented: $showAdd) {
                AddMaintenanceView().environmentObject(vm)
            }
            .sheet(item: $editingItem) { item in
                AddMaintenanceView(editingItem: item).environmentObject(vm)
            }
        }
    }

    private var alertBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Просрочено: \(overdueCount) вида ТО")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Требуется техническое обслуживание")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private var itemsList: some View {
        VStack(spacing: 10) {
            ForEach(vm.currentMaintenanceItems.sorted {
                let a = $0.isOverdue(currentMileage: vm.lastMileage)
                let b = $1.isOverdue(currentMileage: vm.lastMileage)
                if a != b { return a }
                return ($0.remainingKm(currentMileage: vm.lastMileage) ?? 999999)
                     < ($1.remainingKm(currentMileage: vm.lastMileage) ?? 999999)
            }) { item in
                MaintenanceRowView(item: item, currentMileage: vm.lastMileage)
                    .onTapGesture { editingItem = item }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let idx = vm.currentMaintenanceItems.firstIndex(where: { $0.id == item.id }) {
                                vm.deleteMaintenance(at: IndexSet([idx]))
                            }
                        } label: { Label("Удалить", systemImage: "trash") }

                        Button { editingItem = item } label: {
                            Label("Изменить", systemImage: "pencil")
                        }.tint(.blue)

                        Button {
                            var updated = item
                            updated.lastServiceMileage = vm.lastMileage
                            updated.lastServiceDate = Date()
                            vm.updateMaintenance(updated)
                        } label: {
                            Label("Выполнено", systemImage: "checkmark")
                        }.tint(.green)
                    }
                    .padding(.horizontal, 16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 50)
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Нет записей ТО")
                .font(.title2.bold())
            Text("Добавьте плановые работы\nдля отслеживания сроков")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Шаблоны
            VStack(spacing: 8) {
                Text("Быстро добавить:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(defaultMaintenanceTemplates, id: \.title) { tpl in
                        Button {
                            guard let carId = vm.selectedCarId else { return }
                            let item = MaintenanceItem(
                                title: tpl.title, icon: tpl.icon,
                                intervalKm: tpl.km > 0 ? tpl.km : nil,
                                intervalDays: tpl.days > 0 ? tpl.days : nil,
                                carId: carId
                            )
                            vm.addMaintenance(item)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tpl.icon).font(.caption)
                                Text(tpl.title).font(.caption.bold()).lineLimit(1)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private var addButton: some View {
        Button { showAdd = true } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .accentColor.opacity(0.4), radius: 12, y: 4)
        }
        .padding(.trailing, 20).padding(.bottom, 24)
        .disabled(vm.selectedCar == nil)
    }
}

// MARK: - Row

struct MaintenanceRowView: View {
    let item: MaintenanceItem
    let currentMileage: Int

    var urgency: UrgencyLevel { item.urgencyLevel(currentMileage: currentMileage) }

    var urgencyColor: Color {
        switch urgency {
        case .ok:      return .green
        case .soon:    return .orange
        case .overdue: return .red
        }
    }

    var statusText: String {
        if let rem = item.remainingKm(currentMileage: currentMileage) {
            if rem < 0 { return "Просрочено на \(abs(rem)) км" }
            return "Осталось \(rem) км"
        }
        if let next = item.nextServiceDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0
            if days < 0 { return "Просрочено на \(abs(days)) дн." }
            return "Через \(days) дн."
        }
        return "Не настроено"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(urgencyColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: item.icon)
                    .foregroundColor(urgencyColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.headline)

                HStack(spacing: 6) {
                    Circle()
                        .fill(urgencyColor)
                        .frame(width: 7, height: 7)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let last = item.lastServiceDate {
                    Text("Последнее: \(last.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let next = item.nextServiceMileage {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(next.formatted())")
                        .font(.subheadline.bold())
                        .foregroundColor(urgencyColor)
                    Text("км")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(urgency == .overdue ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Add/Edit

struct AddMaintenanceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: ExpenseViewModel

    var editingItem: MaintenanceItem? = nil

    @State private var title = ""
    @State private var icon = "wrench.and.screwdriver.fill"
    @State private var intervalKm = ""
    @State private var intervalDays = ""
    @State private var lastMileage = ""
    @State private var lastDate = Date()
    @State private var hasKmInterval = true
    @State private var hasDateInterval = false
    @State private var note = ""

    let icons = ["drop.fill","aqi.medium","circle.circle","car.rear.and.tire.marks",
                 "doc.badge.checkmark","bolt.fill","thermometer.medium","wrench.and.screwdriver.fill",
                 "gear","oilcan.fill","fanblades.fill","battery.100"]

    var isValid: Bool { !title.isEmpty }

    var body: some View {
        NavigationView {
            Form {
                Section("Название") {
                    TextField("Например: Замена масла", text: $title)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(icons, id: \.self) { ic in
                                Button {
                                    icon = ic
                                } label: {
                                    Image(systemName: ic)
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(icon == ic ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                                        .foregroundColor(icon == ic ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Toggle("По пробегу", isOn: $hasKmInterval)
                    if hasKmInterval {
                        HStack {
                            TextField("Интервал", text: $intervalKm)
                                .keyboardType(.numberPad)
                            Text("км")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            TextField("Последний пробег", text: $lastMileage)
                                .keyboardType(.numberPad)
                            Text("км")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: { Text("Интервал по пробегу") }

                Section {
                    Toggle("По дате", isOn: $hasDateInterval)
                    if hasDateInterval {
                        HStack {
                            TextField("Интервал", text: $intervalDays)
                                .keyboardType(.numberPad)
                            Text("дней")
                                .foregroundColor(.secondary)
                        }
                        DatePicker("Последняя дата", selection: $lastDate, displayedComponents: .date)
                    }
                } header: { Text("Интервал по дате") }

                Section("Примечание") {
                    TextField("Необязательно...", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(editingItem == nil ? "Новое ТО" : "Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { prefill() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.bold().disabled(!isValid)
                }
            }
        }
    }

    private func prefill() {
        guard let e = editingItem else { return }
        title = e.title
        icon = e.icon
        note = e.note
        if let k = e.intervalKm    { intervalKm = String(k); hasKmInterval = true }
        if let d = e.intervalDays  { intervalDays = String(d); hasDateInterval = true }
        if let m = e.lastServiceMileage { lastMileage = String(m) }
        if let dt = e.lastServiceDate  { lastDate = dt }
    }

    private func save() {
        guard let carId = vm.selectedCarId else { return }
        var item = editingItem ?? MaintenanceItem(title: title, icon: icon, carId: carId)
        item.title = title
        item.icon = icon
        item.note = note
        item.intervalKm = hasKmInterval ? Int(intervalKm) : nil
        item.intervalDays = hasDateInterval ? Int(intervalDays) : nil
        item.lastServiceMileage = hasKmInterval ? Int(lastMileage) : nil
        item.lastServiceDate = hasDateInterval ? lastDate : nil

        if editingItem != nil { vm.updateMaintenance(item) } else { vm.addMaintenance(item) }
        dismiss()
    }
}
