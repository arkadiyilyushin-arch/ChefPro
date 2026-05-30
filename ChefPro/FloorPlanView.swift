import SwiftUI

// MARK: - Floor Plan Models

struct FloorTable: Identifiable, Codable {
    var id       = UUID()
    var number:  String
    var x:       Double   // 0.0 – 1.0 relative position
    var y:       Double
    var seats:   Int      = 4
    var shape:   TableShape = .round

    enum TableShape: String, Codable, CaseIterable {
        case round  = "Круглый"
        case square = "Квадратный"
        case rect   = "Прямоугольный"
    }
}

// MARK: - Floor Plan View

struct FloorPlanView: View {
    @EnvironmentObject var store: ChefProStore

    // Tables stored locally (separate from reservations)
    @AppStorage("chefpro_floor_tables") private var tablesData: Data = Data()
    @State private var tables: [FloorTable] = []
    @State private var editMode    = false
    @State private var selectedTableID: UUID? = nil
    @State private var showAddTable = false
    @State private var showReservations = false
    @State private var draggingID: UUID? = nil

    // Today's reservations indexed by table number
    private var confirmedToday: Set<String> {
        Set(store.todayReservations
            .filter { $0.status == .confirmed || $0.status == .arrived }
            .map { $0.tableNumber })
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Floor background
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .onTapGesture { selectedTableID = nil }

                    // Grid lines
                    Canvas { ctx, size in
                        let step: CGFloat = 40
                        var x: CGFloat = 0
                        while x <= size.width {
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            ctx.stroke(path, with: .color(.gray.opacity(0.12)), lineWidth: 0.5)
                            x += step
                        }
                        var y: CGFloat = 0
                        while y <= size.height {
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(path, with: .color(.gray.opacity(0.12)), lineWidth: 0.5)
                            y += step
                        }
                    }

                    // Tables
                    ForEach(tables) { table in
                        tableView(table, in: geo.size)
                    }

                    // Legend
                    VStack(alignment: .leading, spacing: 6) {
                        legendItem(color: .green, label: "Свободен")
                        legendItem(color: .orange, label: "Забронирован сегодня")
                        legendItem(color: .blue.opacity(0.3), label: "Выбран")
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .navigationTitle("План зала")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showReservations = true
                    } label: {
                        Label("Брони", systemImage: "calendar.badge.clock")
                    }

                    Button {
                        editMode.toggle()
                        if !editMode { saveTables() }
                    } label: {
                        Text(editMode ? "Готово" : "Изменить")
                    }

                    if editMode {
                        Button {
                            showAddTable = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTable) {
                AddFloorTableView { newTable in
                    tables.append(newTable)
                    saveTables()
                }
            }
            .sheet(isPresented: $showReservations) {
                TableReservationView().environmentObject(store)
            }
            .onAppear { loadTables() }
        }
    }

    // MARK: - Table View

    private func tableView(_ table: FloorTable, in size: CGSize) -> some View {
        let isSelected  = selectedTableID == table.id
        let isBooked    = confirmedToday.contains(table.number)
        let tableSize: CGFloat = table.shape == .rect ? 80 : 60
        let tableHeight: CGFloat = table.shape == .rect ? 44 : tableSize
        let x = table.x * (size.width - tableSize)
        let y = table.y * (size.height - 120)

        return ZStack {
            Group {
                if table.shape == .round {
                    Circle()
                        .fill(isBooked ? Color.orange.opacity(0.8) : Color.green.opacity(0.7))
                        .overlay(Circle().stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3))
                } else {
                    RoundedRectangle(cornerRadius: table.shape == .square ? 6 : 4)
                        .fill(isBooked ? Color.orange.opacity(0.8) : Color.green.opacity(0.7))
                        .overlay(RoundedRectangle(cornerRadius: table.shape == .square ? 6 : 4)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3))
                }
            }
            .frame(width: tableSize, height: tableHeight)

            VStack(spacing: 1) {
                Text("№\(table.number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text("\(table.seats)👤")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: tableSize, height: tableHeight)
        .position(x: x + tableSize / 2, y: y + tableHeight / 2)
        .gesture(
            editMode
            ? DragGesture()
                .onChanged { val in
                    if let i = tables.firstIndex(where: { $0.id == table.id }) {
                        tables[i].x = max(0, min(1, (val.location.x - tableSize / 2) / (size.width - tableSize)))
                        tables[i].y = max(0, min(1, (val.location.y - tableHeight / 2) / (size.height - 120)))
                    }
                }
                .onEnded { _ in saveTables() }
            : nil
        )
        .onTapGesture {
            withAnimation(.spring()) {
                selectedTableID = selectedTableID == table.id ? nil : table.id
            }
        }
        .contextMenu {
            if editMode {
                Button(role: .destructive) {
                    tables.removeAll { $0.id == table.id }
                    saveTables()
                } label: {
                    Label("Удалить стол", systemImage: "trash")
                }
            }
            Button {
                // Quick reservation
                showReservations = true
            } label: {
                Label("Забронировать", systemImage: "calendar.badge.plus")
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Persistence

    private func saveTables() {
        if let data = try? JSONEncoder().encode(tables) {
            tablesData = data
        }
    }

    private func loadTables() {
        if let decoded = try? JSONDecoder().decode([FloorTable].self, from: tablesData) {
            tables = decoded
        }
        if tables.isEmpty {
            // Default layout — 10 tables
            tables = defaultTables()
            saveTables()
        }
    }

    private func defaultTables() -> [FloorTable] {
        let positions: [(String, Double, Double, Int, FloorTable.TableShape)] = [
            ("1",  0.05, 0.05, 2, .round),
            ("2",  0.20, 0.05, 4, .round),
            ("3",  0.40, 0.05, 4, .square),
            ("4",  0.60, 0.05, 4, .square),
            ("5",  0.80, 0.05, 6, .rect),
            ("6",  0.05, 0.40, 4, .round),
            ("7",  0.25, 0.40, 2, .round),
            ("8",  0.50, 0.40, 4, .square),
            ("9",  0.70, 0.40, 4, .square),
            ("10", 0.85, 0.40, 8, .rect),
        ]
        return positions.map { FloorTable(number: $0.0, x: $0.1, y: $0.2, seats: $0.3, shape: $0.4) }
    }
}

// MARK: - Add Floor Table

struct AddFloorTableView: View {
    let onSave: (FloorTable) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var number = ""
    @State private var seats  = 4
    @State private var shape  = FloorTable.TableShape.round

    var body: some View {
        NavigationStack {
            Form {
                Section("Стол") {
                    HStack {
                        Text("Номер стола")
                        Spacer()
                        TextField("1", text: $number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    Stepper("Мест: \(seats)", value: $seats, in: 1...20)
                }
                Section("Форма") {
                    Picker("Форма стола", selection: $shape) {
                        ForEach(FloorTable.TableShape.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text("После создания перетащите стол на нужное место в режиме редактирования.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Добавить стол")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        guard !number.isEmpty else { return }
                        onSave(FloorTable(number: number, x: 0.5, y: 0.5, seats: seats, shape: shape))
                        dismiss()
                    }
                    .disabled(number.isEmpty)
                }
            }
        }
    }
}
