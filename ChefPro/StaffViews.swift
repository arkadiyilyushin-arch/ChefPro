import SwiftUI

// MARK: - Employee Management

let allPermissions: [(name: String, icon: String)] = [
    ("Техкарты",  "book.fill"),
    ("Склад",     "shippingbox.fill"),
    ("Приемка",   "tray.and.arrow.down.fill"),
    ("Списания",  "trash.fill"),
    ("Отчеты",    "chart.bar.fill"),
    ("Настройки", "gearshape.fill")
]

struct EmployeeListView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd = false
    @State private var editingEmployee: Employee?

    var body: some View {
        List {
            ForEach(store.employees) { employee in
                Button {
                    editingEmployee = employee
                } label: {
                    EmployeeRowView(employee: employee, isCurrent: store.currentEmployeeID == employee.id)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { store.employees[$0] }.forEach { store.deleteEmployee($0) }
            }
        }
        .navigationTitle("Сотрудники")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditEmployeeView(employee: nil)
                .environmentObject(store)
        }
        .sheet(item: $editingEmployee) { emp in
            AddEditEmployeeView(employee: emp)
                .environmentObject(store)
        }
    }
}

struct EmployeeRowView: View {
    let employee: Employee
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.orange : Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Text(String(employee.name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(isCurrent ? .white : .primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(employee.name).font(.headline)
                    if isCurrent {
                        Text("Вы").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2)).foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                Text(employee.position).font(.subheadline).foregroundStyle(.secondary)
                if !employee.phone.isEmpty {
                    Text(employee.phone).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(employee.permissions.count) прав")
                    .font(.caption).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddEditEmployeeView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss

    let employee: Employee?

    @State private var name = ""
    @State private var position = ""
    @State private var phone = ""
    @State private var pin = ""
    @State private var permissions: Set<String> = []
    @State private var showDeleteAlert = false

    private var isEditing: Bool { employee != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        pin.count == 4 &&
        pin.allSatisfy(\.isNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Имя и фамилия", text: $name)
                    TextField("Должность", text: $position)
                    TextField("Телефон", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section {
                    HStack {
                        Text("PIN-код")
                        Spacer()
                        SecureField("4 цифры", text: $pin)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: pin) { _, val in
                                if val.count > 4 { pin = String(val.prefix(4)) }
                            }
                    }
                } footer: {
                    Text("PIN используется для входа в приложение")
                }

                Section("Права доступа") {
                    ForEach(allPermissions, id: \.name) { perm in
                        Toggle(isOn: Binding(
                            get: { permissions.contains(perm.name) },
                            set: { on in
                                if on { permissions.insert(perm.name) }
                                else  { permissions.remove(perm.name) }
                            }
                        )) {
                            Label(perm.name, systemImage: perm.icon)
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Удалить сотрудника")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Редактировать" : "Новый сотрудник")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Удалить сотрудника?", isPresented: $showDeleteAlert) {
                Button("Удалить", role: .destructive) {
                    if let emp = employee { store.deleteEmployee(emp) }
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это действие нельзя отменить")
            }
        }
        .onAppear { prefill() }
    }

    private func prefill() {
        guard let emp = employee else { return }
        name       = emp.name
        position   = emp.position
        phone      = emp.phone
        pin        = emp.pin
        permissions = Set(emp.permissions)
    }

    private func save() {
        let emp = Employee(
            id: employee?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            position: position.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            pin: pin,
            permissions: Array(permissions)
        )
        if isEditing { store.updateEmployee(emp) }
        else         { store.addEmployee(emp) }
        dismiss()
    }
}

// MARK: - Shift

struct ShiftView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showCloseAlert  = false
    @State private var showDigestShare = false
    @State private var digestText      = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                if let shift = store.currentShift {
                    // Открытая смена
                    BigCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ZStack {
                                    Circle().fill(Color.green.opacity(0.15)).frame(width: 50, height: 50)
                                    Image(systemName: "clock.fill").foregroundStyle(.green).font(.title2)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Смена открыта").font(.title3.bold())
                                    Text("Открыл: \(shift.openedBy)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            Divider()

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Начало").font(.caption).foregroundStyle(.secondary)
                                    Text(shift.openedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Длительность").font(.caption).foregroundStyle(.secondary)
                                    Text(shift.duration).font(.headline).foregroundStyle(.chefAccent)
                                }
                            }
                        }
                    }

                    SectionTitle(title: "За эту смену")
                    HStack {
                        shiftStat(title: "Производство", value: "\(store.productions.filter { $0.date >= shift.openedAt }.count)", icon: "flame.fill", color: .orange)
                        shiftStat(title: "Списания",     value: "\(store.writeOffs.filter  { $0.date >= shift.openedAt }.count)", icon: "trash.fill",  color: .red)
                    }
                    HStack {
                        shiftStat(title: "Приёмки",  value: "\(store.deliveries.filter  { $0.date >= shift.openedAt }.count)",           icon: "tray.fill",         color: .blue)
                        shiftStat(title: "Заказы KB", value: "\(store.closedKitchenOrders.filter { $0.readyAt ?? Date.distantPast >= shift.openedAt }.count)", icon: "checkmark.circle.fill", color: .green)
                    }

                    BigActionButton(title: "Закрыть смену", icon: "stop.circle.fill") {
                        showCloseAlert = true
                    }

                } else {
                    // Нет открытой смены
                    BigCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ZStack {
                                    Circle().fill(Color.gray.opacity(0.12)).frame(width: 50, height: 50)
                                    Image(systemName: "clock.slash").foregroundStyle(.secondary).font(.title2)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Смена не открыта").font(.title3.bold())
                                    Text("Нажмите кнопку ниже чтобы начать").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    BigActionButton(title: "Открыть смену", icon: "play.circle.fill") {
                        store.openShift()
                    }
                }

                // История смен
                if !store.shiftHistory.isEmpty {
                    SectionTitle(title: "История смен")
                    ForEach(store.shiftHistory) { shift in
                        BigCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(shift.openedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    Spacer()
                                    Text(shift.duration)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }
                                Text("Сотрудник: \(shift.openedBy)").font(.caption).foregroundStyle(.secondary)
                                Divider()
                                HStack {
                                    shiftHistoryStat(icon: "flame.fill",       color: .orange, value: shift.productionsCount, label: "произв.")
                                    Spacer()
                                    shiftHistoryStat(icon: "trash.fill",        color: .red,    value: shift.writeOffsCount,   label: "списаний")
                                    Spacer()
                                    shiftHistoryStat(icon: "tray.fill",         color: .blue,   value: shift.deliveriesCount,  label: "приёмок")
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.chefBackground)
        .navigationTitle("Смена")
        .alert("Закрыть смену?", isPresented: $showCloseAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Закрыть", role: .destructive) {
                if let shift = store.currentShift {
                    digestText = buildDigest(shift: shift)
                }
                store.closeShift()
                showDigestShare = true
            }
        } message: {
            Text("Смена будет зафиксирована в истории.")
        }
        .sheet(isPresented: $showDigestShare) {
            ShareSheet(items: [digestText])
        }
    }

    private func buildDigest(shift: Shift) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM yyyy"
        let since = shift.openedAt
        let prods    = store.productions.filter { $0.date >= since }
        let woffs    = store.writeOffs.filter   { $0.date >= since }
        let dels     = store.deliveries.filter  { $0.date >= since }
        let prodCost = prods.reduce(0.0) { $0 + $1.totalCost }
        let delCost  = dels.reduce(0.0)  { $0 + $1.price }
        var lines: [String] = [
            "📋 Дайджест смены — \(store.restaurantName)",
            "Дата: \(df.string(from: since))",
            "Сотрудник: \(shift.openedBy)",
            "Длительность: \(shift.duration)",
            "",
            "▪ Производство: \(prods.count) зап. · себестоимость \(String(format: "%.2f", prodCost))",
        ]
        let topDish = Dictionary(grouping: prods, by: \.dishName)
            .mapValues { $0.reduce(0) { $0 + $1.portions } }
            .sorted { $0.value > $1.value }.prefix(3)
        for d in topDish { lines.append("   · \(d.key): \(d.value) порц.") }
        lines += [
            "▪ Списания: \(woffs.count) шт.",
            "▪ Приёмки: \(dels.count) шт. · сумма \(String(format: "%.2f", delCost))",
            "",
            "⚠ Низкий остаток: \(store.lowStockItems.count) позиций",
        ]
        return lines.joined(separator: "\n")
    }

    private func shiftStat(title: String, value: String, icon: String, color: Color) -> some View {
        BigCard {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).foregroundStyle(color)
                Text(value).font(.title2.bold())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func shiftHistoryStat(icon: String, color: Color, value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.caption)
            Text("\(value) \(label)").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shift Checklist

struct ShiftChecklistView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedType: ChecklistType = .opening
    @State private var showAddItem = false
    @State private var newItemText = ""

    private var filteredItems: [ChecklistItem] {
        store.checklists.filter { $0.type == selectedType }
    }

    private var completedCount: Int { filteredItems.filter { $0.isCompleted }.count }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Тип", selection: $selectedType) {
                ForEach(ChecklistType.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.icon).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Progress
            VStack(spacing: 6) {
                HStack {
                    Text("\(completedCount)/\(filteredItems.count) выполнено")
                        .font(.subheadline.bold())
                        .foregroundStyle(selectedType.color)
                    Spacer()
                    Button("Сбросить") {
                        store.resetChecklists(for: selectedType)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                ProgressView(value: filteredItems.isEmpty ? 0 : Double(completedCount) / Double(filteredItems.count))
                    .tint(selectedType.color)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            List {
                ForEach(filteredItems) { item in
                    Button {
                        if !item.isCompleted {
                            store.completeChecklist(item, by: store.profile.name)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? selectedType.color : .secondary)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.text)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                    .strikethrough(item.isCompleted)
                                if item.isCompleted, !item.completedBy.isEmpty {
                                    Text("✓ \(item.completedBy)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { filteredItems[$0].id }
                    store.checklists.removeAll { ids.contains($0.id) }
                }

                Button {
                    showAddItem = true
                } label: {
                    Label("Добавить задачу", systemImage: "plus.circle")
                        .foregroundStyle(.chefAccent)
                }
            }
        }
        .navigationTitle("Чеклист смены")
        .sheet(isPresented: $showAddItem) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Задача", text: $newItemText)
                    }
                }
                .navigationTitle("Новая задача")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Отмена") { showAddItem = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Добавить") {
                            store.addChecklist(ChecklistItem(text: newItemText, type: selectedType, isDefault: false))
                            newItemText = ""; showAddItem = false
                        }
                        .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}

// MARK: - Work Schedule

struct WorkScheduleView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedDate = Date()
    @State private var showAddShift = false

    private var todayShifts: [WorkShift] {
        let cal = Calendar.current
        return store.workSchedule
            .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DatePicker("Дата", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                if todayShifts.isEmpty {
                    EmptyStateView(icon: "calendar.badge.clock", title: "Нет смен", subtitle: "На этот день смены не запланированы")
                        .padding()
                } else {
                    VStack(spacing: 10) {
                        ForEach(todayShifts) { shift in
                            BigCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(shift.employeeName).font(.headline)
                                        Spacer()
                                        Text(shift.duration)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color.chefAccent.opacity(0.15))
                                            .foregroundStyle(.chefAccent)
                                            .clipShape(Capsule())
                                    }
                                    HStack {
                                        Image(systemName: "clock").foregroundStyle(.secondary)
                                        Text("\(shift.startTime.formatted(date: .omitted, time: .shortened)) – \(shift.endTime.formatted(date: .omitted, time: .shortened))")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    if !shift.notes.isEmpty {
                                        Text(shift.notes).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteWorkShift(shift)
                                } label: { Label("Удалить", systemImage: "trash") }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("График работы")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddShift = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddShift) {
            AddWorkShiftView(date: selectedDate)
                .environmentObject(store)
        }
    }
}

struct AddWorkShiftView: View {
    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) var dismiss

    let date: Date
    @State private var selectedEmployeeID: UUID? = nil
    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime   = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notes = ""

    private var selectedEmployee: Employee? {
        store.employees.first(where: { $0.id == selectedEmployeeID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Сотрудник") {
                    if store.employees.isEmpty {
                        Text("Нет сотрудников").foregroundStyle(.secondary)
                    } else {
                        Picker("Сотрудник", selection: $selectedEmployeeID) {
                            Text("Выберите").tag(Optional<UUID>.none)
                            ForEach(store.employees) { emp in
                                Text(emp.name).tag(Optional(emp.id))
                            }
                        }
                    }
                }
                Section("Время") {
                    DatePicker("Начало", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Конец", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                Section("Заметки") {
                    TextField("Заметка", text: $notes)
                }
            }
            .navigationTitle("Добавить смену")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        guard let emp = selectedEmployee else { return }
                        let shift = WorkShift(
                            employeeID: emp.id,
                            employeeName: emp.name,
                            date: date,
                            startTime: startTime,
                            endTime: endTime,
                            notes: notes
                        )
                        store.addWorkShift(shift)
                        dismiss()
                    }
                    .disabled(selectedEmployeeID == nil)
                }
            }
        }
    }
}

// MARK: - Employee Activity

struct EmployeeActivityView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedPeriod = 0
    let periods = ["День", "Неделя", "Месяц"]

    private var since: Date {
        let cal = Calendar.current
        switch selectedPeriod {
        case 0: return cal.startOfDay(for: Date())
        case 1: return cal.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        default: return cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        }
    }

    private struct EmployeeStat: Identifiable {
        let id: UUID
        let name: String
        let productions: Int
        let writeOffs: Int
        let deliveries: Int
        let shifts: [WorkShift]
        var totalHours: Double {
            shifts.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) / 3600 }
        }
    }

    private var stats: [EmployeeStat] {
        store.employees.map { emp in
            let prods = store.productions.filter { $0.employee == emp.name && $0.date >= since }.count
            let woffs = store.writeOffs.filter { $0.employee == emp.name && $0.date >= since }.count
            let dels  = store.deliveries.filter { $0.acceptedBy == emp.name && $0.date >= since }.count
            let shifts = store.workSchedule.filter { $0.employeeID == emp.id && $0.date >= since }
            return EmployeeStat(id: emp.id, name: emp.name, productions: prods,
                                writeOffs: woffs, deliveries: dels, shifts: shifts)
        }
        .sorted { $0.productions + $0.writeOffs + $0.deliveries > $1.productions + $1.writeOffs + $1.deliveries }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Период", selection: $selectedPeriod) {
                    ForEach(0..<periods.count, id: \.self) { Text(periods[$0]) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if stats.isEmpty {
                    EmptyStateView(icon: "person.2", title: "Нет сотрудников", subtitle: "Добавьте сотрудников в систему")
                        .padding()
                } else {
                    ForEach(stats) { stat in
                        BigCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    ZStack {
                                        Circle().fill(Color.orange.opacity(0.15)).frame(width: 40, height: 40)
                                        Text(String(stat.name.prefix(1))).font(.headline.bold()).foregroundStyle(.orange)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stat.name).font(.headline)
                                        if let emp = store.employees.first(where: { $0.id == stat.id }) {
                                            Text(emp.position).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if stat.totalHours > 0 {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(String(format: "%.1f", stat.totalHours))ч")
                                                .font(.headline).foregroundStyle(.chefAccent)
                                            Text("смены").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Divider()
                                HStack(spacing: 0) {
                                    ActivityStatCell(value: stat.productions, label: "Производств", color: .green)
                                    Divider().frame(height: 32)
                                    ActivityStatCell(value: stat.writeOffs, label: "Списаний", color: .orange)
                                    Divider().frame(height: 32)
                                    ActivityStatCell(value: stat.deliveries, label: "Приёмок", color: .blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.chefBackground)
        .navigationTitle("Активность сотрудников")
    }
}

struct ActivityStatCell: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
