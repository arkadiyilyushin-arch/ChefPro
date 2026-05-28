import SwiftUI

// MARK: - POS Integration View

struct POSIntegrationView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var selectedPOS: POSSystem = .manual
    @State private var showManualEntry = false
    @State private var showImportSheet = false
    @State private var showDeleteConfirm = false

    private var importedToday: Int {
        Calendar.current.isDateInToday(Date()) ?
            store.posRecords.filter { Calendar.current.isDateInToday($0.importedAt) }.count : 0
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Summary ────────────────────────────────────
                Section {
                    HStack(spacing: 0) {
                        posStatCell(value: "\(store.posRecords.count)", label: "Записей", color: .blue)
                        Divider()
                        posStatCell(value: "\(importedToday)", label: "Сегодня", color: .green)
                        Divider()
                        posStatCell(value: revenueToday, label: "Выручка сег.", color: .orange)
                    }
                    .frame(height: 70)
                }

                // ── POS System selector ────────────────────────
                Section("Источник данных") {
                    ForEach(POSSystem.allCases, id: \.self) { pos in
                        HStack {
                            Image(systemName: pos.icon).foregroundStyle(.chefAccent).frame(width: 24)
                            Text(pos.rawValue)
                            Spacer()
                            if selectedPOS == pos {
                                Image(systemName: "checkmark").foregroundStyle(.chefAccent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPOS = pos }
                    }
                }

                // ── Import actions ─────────────────────────────
                Section("Импорт") {
                    if selectedPOS == .manual {
                        Button {
                            showManualEntry = true
                        } label: {
                            Label("Добавить продажу вручную", systemImage: "square.and.pencil")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Импорт из \(selectedPOS.rawValue)")
                                .font(.subheadline.bold())
                            Text("Экспортируйте данные из \(selectedPOS.rawValue) в формате CSV и загрузите файл.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)

                        Button {
                            showImportSheet = true
                        } label: {
                            Label("Загрузить CSV-файл", systemImage: "doc.badge.plus")
                        }

                        // Format hint
                        DisclosureGroup("Формат файла \(selectedPOS.rawValue)") {
                            Text(formatHint(for: selectedPOS))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .font(.caption)
                    }
                }

                // ── Recent imports ─────────────────────────────
                if !store.posRecords.isEmpty {
                    Section("Последние импорты") {
                        ForEach(store.posRecords.sorted { $0.importedAt > $1.importedAt }.prefix(30)) { record in
                            POSRecordRow(record: record)
                        }
                        .onDelete { idx in
                            let sorted = store.posRecords.sorted { $0.importedAt > $1.importedAt }
                            idx.forEach { store.deletePOSRecord(sorted[$0]) }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Очистить все записи", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Интеграция с кассой")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showManualEntry) {
                ManualPOSEntryView(posSystem: selectedPOS) { record in
                    store.addPOSRecord(record)
                }
            }
            .sheet(isPresented: $showImportSheet) {
                CSVImportView(posSystem: selectedPOS) { records in
                    store.importPOSRecords(records)
                }
            }
            .confirmationDialog("Удалить все записи?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    store.posRecords.removeAll()
                }
                Button("Отмена", role: .cancel) {}
            }
        }
    }

    private var revenueToday: String {
        let total = store.posRecords
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0.0) { $0 + $1.amount }
        return "\(Int(total)) ₽"
    }

    private func posStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatHint(for pos: POSSystem) -> String {
        switch pos {
        case .iiko:
            return "iiko: Отчёт → Выгрузка продаж → CSV\nКолонки: дата, блюдо, кол-во, сумма"
        case .poster:
            return "Poster: Аналитика → Продажи → Экспорт CSV\nФормат: date,product,qty,total"
        case .rkeeper:
            return "r_keeper: Менеджер → Отчёт по блюдам → Экспорт\nФормат: дата;блюдо;количество;сумма"
        case .tillypad:
            return "Tillypad: Отчёты → Реализация → CSV\nФормат: date;dish;qty;amount"
        case .manual:
            return ""
        }
    }
}

// MARK: - POS Record Row

struct POSRecordRow: View {
    let record: POSSaleRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.posSystem.icon)
                .foregroundStyle(.chefAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.dishName).font(.subheadline)
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.quantity) шт.")
                    .font(.caption.bold())
                Text("\(Int(record.amount)) ₽")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Manual POS Entry

struct ManualPOSEntryView: View {
    let posSystem: POSSystem
    let onSave: (POSSaleRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ChefProStore
    @State private var dishName  = ""
    @State private var quantity  = "1"
    @State private var amount    = ""
    @State private var date      = Date()
    @State private var showDishPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Блюдо") {
                    HStack {
                        TextField("Название блюда", text: $dishName)
                        Button {
                            showDishPicker = true
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
                Section("Данные") {
                    HStack {
                        Text("Количество")
                        Spacer()
                        TextField("1", text: $quantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("шт.").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Сумма")
                        Spacer()
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₽").foregroundStyle(.secondary)
                    }
                    DatePicker("Дата/время", selection: $date)
                }
            }
            .navigationTitle("Добавить продажу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let record = POSSaleRecord(
                            date: date,
                            dishName: dishName.isEmpty ? "Без названия" : dishName,
                            quantity: Int(quantity) ?? 1,
                            amount: Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0,
                            posSystem: posSystem
                        )
                        onSave(record)
                        dismiss()
                    }
                    .disabled(dishName.isEmpty || amount.isEmpty)
                }
            }
            .sheet(isPresented: $showDishPicker) {
                NavigationStack {
                    List(store.dishes) { dish in
                        Button {
                            dishName = dish.name
                            amount = String(Int(dish.salePrice))
                            showDishPicker = false
                        } label: {
                            HStack {
                                Text(dish.name)
                                Spacer()
                                Text("\(Int(dish.salePrice)) ₽").foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .navigationTitle("Выбрать блюдо")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") { showDishPicker = false }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - CSV Import View

struct CSVImportView: View {
    let posSystem: POSSystem
    let onImport: ([POSSaleRecord]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var csvText   = ""
    @State private var preview: [POSSaleRecord] = []
    @State private var parseError = ""
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Вставьте CSV или выберите файл") {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Выбрать файл…", systemImage: "doc.badge.plus")
                    }

                    TextEditor(text: $csvText)
                        .font(.caption.monospaced())
                        .frame(minHeight: 140)

                    if !csvText.isEmpty {
                        Button("Разобрать") { parseCSV() }
                    }
                }

                if !parseError.isEmpty {
                    Section {
                        Label(parseError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if !preview.isEmpty {
                    Section("Предпросмотр (\(preview.count) строк)") {
                        ForEach(preview.prefix(10)) { r in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.dishName).font(.caption.bold())
                                    Text(r.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(r.quantity) × \(Int(r.amount)) ₽")
                                    .font(.caption)
                            }
                        }
                        if preview.count > 10 {
                            Text("… ещё \(preview.count - 10) строк").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Импорт CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Импортировать") {
                        onImport(preview)
                        dismiss()
                    }
                    .disabled(preview.isEmpty)
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText, .text]) { result in
                if let url = try? result.get(), let text = try? String(contentsOf: url, encoding: .utf8) {
                    csvText = text
                    parseCSV()
                }
            }
        }
    }

    private func parseCSV() {
        parseError = ""
        let lines = csvText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var records: [POSSaleRecord] = []
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")

        for (i, line) in lines.enumerated() {
            if i == 0 && (line.lowercased().contains("дата") || line.lowercased().contains("date")) { continue }
            let parts = line.components(separatedBy: CharacterSet(charactersIn: ",;|\t"))
            guard parts.count >= 3 else { continue }

            // Try to parse: [date, dishName, qty, amount] or [dishName, qty, amount]
            var dishName = ""
            var qty = 1
            var amount = 0.0
            var date = Date()

            if parts.count >= 4 {
                // Assume: date, dish, qty, amount
                df.dateFormat = "dd.MM.yyyy"
                if let d = df.date(from: parts[0].trimmingCharacters(in: .whitespaces)) { date = d }
                dishName = parts[1].trimmingCharacters(in: .whitespaces)
                qty    = Int(parts[2].trimmingCharacters(in: .whitespaces)) ?? 1
                amount = Double(parts[3].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) ?? 0
            } else {
                // Assume: dish, qty, amount
                dishName = parts[0].trimmingCharacters(in: .whitespaces)
                qty    = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 1
                amount = Double(parts[2].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) ?? 0
            }

            guard !dishName.isEmpty else { continue }
            records.append(POSSaleRecord(date: date, dishName: dishName, quantity: qty, amount: amount, posSystem: posSystem))
        }

        if records.isEmpty {
            parseError = "Не удалось распознать данные. Проверьте формат CSV."
        } else {
            preview = records
        }
    }
}
