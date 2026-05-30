import SwiftUI

// MARK: - Table Reservation View

struct TableReservationView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showAdd = false
    @State private var selectedDate = Date()
    @State private var editingReservation: TableReservation? = nil

    private var displayedReservations: [TableReservation] {
        let cal = Calendar.current
        return store.reservations
            .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    private var upcomingCount: Int {
        store.reservations.filter {
            $0.status == .confirmed && $0.date > Date()
        }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Date selector ──────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(-1..<14) { offset in
                            let date = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
                            dayChip(date)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(.secondarySystemBackground))

                Divider()

                // ── Reservation list ───────────────────────────
                if displayedReservations.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                        Text("Нет броней на этот день")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(displayedReservations) { res in
                            ReservationRow(reservation: res)
                                .contentShape(Rectangle())
                                .onTapGesture { editingReservation = res }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        var updated = res
                                        updated.status = .arrived
                                        store.updateReservation(updated)
                                    } label: {
                                        Label("Пришли", systemImage: "person.fill.checkmark")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.deleteReservation(res)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                    Button {
                                        var updated = res
                                        updated.status = .cancelled
                                        store.updateReservation(updated)
                                    } label: {
                                        Label("Отменить", systemImage: "xmark")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Бронирование столиков")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if upcomingCount > 0 {
                        Label("\(upcomingCount) предстоящих", systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddReservationView(presetDate: selectedDate) { res in
                    store.addReservation(res)
                }
                .environmentObject(store)
            }
            .sheet(item: $editingReservation) { res in
                EditReservationView(reservation: res) { updated in
                    store.updateReservation(updated)
                }
                .environmentObject(store)
            }
        }
    }

    private func dayChip(_ date: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isToday    = cal.isDateInToday(date)
        let count = store.reservations.filter { cal.isDate($0.date, inSameDayAs: date) && $0.status == .confirmed }.count

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text(dayOfWeek(date)).font(.caption2).foregroundStyle(isSelected ? .white : .secondary)
                Text(dayNumber(date)).font(.subheadline.bold()).foregroundStyle(isSelected ? .white : (isToday ? .chefAccent : .primary))
                if count > 0 {
                    Circle().fill(isSelected ? Color.white.opacity(0.8) : Color.chefAccent)
                        .frame(width: 6, height: 6)
                } else {
                    Circle().fill(Color.clear).frame(width: 6, height: 6)
                }
            }
            .frame(width: 44)
            .padding(.vertical, 6)
            .background(isSelected ? Color.chefAccent : (isToday ? Color.chefAccent.opacity(0.1) : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func dayOfWeek(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EE"
        return f.string(from: d).prefix(2).uppercased()
    }

    private func dayNumber(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: d)
    }
}

// MARK: - Reservation Row

struct ReservationRow: View {
    let reservation: TableReservation

    private var timeRange: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let start = f.string(from: reservation.date)
        let end   = f.string(from: reservation.endDate)
        return "\(start) – \(end)"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Status indicator
            Circle()
                .fill(reservation.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(reservation.guestName).font(.headline)
                    Spacer()
                    Label("Стол \(reservation.tableNumber)", systemImage: "chair.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Label(timeRange, systemImage: "clock")
                    Label("\(reservation.persons) чел.", systemImage: "person.2.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !reservation.notes.isEmpty {
                    Text(reservation.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Status badge
            Text(reservation.status.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(reservation.status.color.opacity(0.15))
                .foregroundStyle(reservation.status.color)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Reservation

struct AddReservationView: View {
    let presetDate: Date
    let onSave: (TableReservation) -> Void

    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss
    @State private var guestName   = ""
    @State private var guestPhone  = ""
    @State private var tableNumber = ""
    @State private var persons     = 2
    @State private var date: Date
    @State private var duration    = 120
    @State private var notes       = ""

    init(presetDate: Date, onSave: @escaping (TableReservation) -> Void) {
        self.presetDate = presetDate
        self.onSave = onSave
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: presetDate)
        comps.hour = 19; comps.minute = 0
        _date = State(initialValue: Calendar.current.date(from: comps) ?? presetDate)
    }

    // Conflict: same table, overlapping time, not cancelled
    private var conflictingReservation: TableReservation? {
        guard !tableNumber.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let endDate = date.addingTimeInterval(Double(duration) * 60)
        return store.reservations.first { existing in
            existing.tableNumber == tableNumber &&
            existing.status != .cancelled &&
            date < existing.endDate &&
            endDate > existing.date
        }
    }

    private var canSave: Bool {
        !guestName.isEmpty && conflictingReservation == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Гость") {
                    TextField("Имя гостя", text: $guestName)
                    TextField("Телефон", text: $guestPhone)
                        .keyboardType(.phonePad)
                }

                Section("Бронирование") {
                    HStack {
                        Text("Стол №")
                        TextField("Номер стола", text: $tableNumber)
                            .keyboardType(.numberPad)
                    }
                    Stepper("Гостей: \(persons)", value: $persons, in: 1...50)
                    DatePicker("Время", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Длительность", selection: $duration) {
                        Text("1 час").tag(60)
                        Text("1.5 часа").tag(90)
                        Text("2 часа").tag(120)
                        Text("2.5 часа").tag(150)
                        Text("3 часа").tag(180)
                    }
                }

                // Conflict warning
                if let conflict = conflictingReservation {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Стол уже забронирован")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                                let f = DateFormatter()
                                let _ = { f.dateFormat = "HH:mm" }()
                                Text("\(conflict.guestName) · \(f.string(from: conflict.date))–\(f.string(from: conflict.endDate))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Комментарий") {
                    TextField("Пожелания, аллергии…", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Новая бронь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let res = TableReservation(
                            guestName: guestName,
                            guestPhone: guestPhone,
                            tableNumber: tableNumber.isEmpty ? "?" : tableNumber,
                            persons: persons,
                            date: date,
                            duration: duration,
                            notes: notes
                        )
                        onSave(res)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Edit Reservation

struct EditReservationView: View {
    let reservation: TableReservation
    let onSave: (TableReservation) -> Void

    @EnvironmentObject var store: ChefProStore
    @Environment(\.dismiss) private var dismiss
    @State private var res: TableReservation

    init(reservation: TableReservation, onSave: @escaping (TableReservation) -> Void) {
        self.reservation = reservation
        self.onSave = onSave
        _res = State(initialValue: reservation)
    }

    // Conflict: same table, overlapping time, excluding self, not cancelled
    private var conflictingReservation: TableReservation? {
        let endDate = res.endDate
        return store.reservations.first { existing in
            existing.id != reservation.id &&
            existing.tableNumber == res.tableNumber &&
            existing.status != .cancelled &&
            res.date < existing.endDate &&
            endDate > existing.date
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Гость") {
                    TextField("Имя", text: $res.guestName)
                    TextField("Телефон", text: $res.guestPhone)
                        .keyboardType(.phonePad)
                }
                Section("Бронирование") {
                    HStack {
                        Text("Стол №")
                        TextField("Номер стола", text: $res.tableNumber)
                            .keyboardType(.numberPad)
                    }
                    Stepper("Гостей: \(res.persons)", value: $res.persons, in: 1...50)
                    DatePicker("Время", selection: $res.date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Длительность", selection: $res.duration) {
                        Text("1 час").tag(60)
                        Text("1.5 часа").tag(90)
                        Text("2 часа").tag(120)
                        Text("2.5 часа").tag(150)
                        Text("3 часа").tag(180)
                    }
                }

                // Conflict warning
                if let conflict = conflictingReservation {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Стол уже забронирован")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                                let f = DateFormatter()
                                let _ = { f.dateFormat = "HH:mm" }()
                                Text("\(conflict.guestName) · \(f.string(from: conflict.date))–\(f.string(from: conflict.endDate))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Статус") {
                    Picker("Статус", selection: $res.status) {
                        ForEach(ReservationStatus.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                }
                Section("Комментарий") {
                    TextField("Пожелания…", text: $res.notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Редактировать бронь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { onSave(res); dismiss() }
                        .disabled(conflictingReservation != nil)
                }
            }
        }
    }
}
