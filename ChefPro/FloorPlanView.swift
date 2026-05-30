import SwiftUI

// MARK: - Floor Plan Models

struct FloorTable: Identifiable, Codable {
    var id     = UUID()
    var number: String
    var x:      Double        // center, 0.0–1.0 relative to canvas
    var y:      Double
    var seats:  Int           = 4
    var shape:  TableShape    = .round

    enum TableShape: String, Codable, CaseIterable {
        case round  = "Круглый"
        case square = "Квадратный"
        case rect   = "Прямоугольный"
    }
}

// MARK: - Constants

private enum TableLayout {
    static let roundSize:  CGFloat = 64
    static let squareSize: CGFloat = 64
    static let rectW:      CGFloat = 90
    static let rectH:      CGFloat = 54
    static let gridStep:   CGFloat = 10   // px snap grid

    static func size(for shape: FloorTable.TableShape) -> CGSize {
        switch shape {
        case .round:  return CGSize(width: roundSize,  height: roundSize)
        case .square: return CGSize(width: squareSize, height: squareSize)
        case .rect:   return CGSize(width: rectW,      height: rectH)
        }
    }
}

// MARK: - Floor Plan View

struct FloorPlanView: View {
    @EnvironmentObject var store: ChefProStore

    @AppStorage("chefpro_floor_tables") private var tablesData: Data = Data()
    @State private var tables:        [FloorTable] = []
    @State private var editMode       = false
    @State private var selectedID:    UUID? = nil
    @State private var showAddTable   = false
    @State private var showReservations = false

    // Drag state: stores translation-from-start while finger is down
    @State private var dragOffsets:  [UUID: CGSize]  = [:]
    // Drag start: stores the normalized (0–1) position when drag began
    @State private var dragStarts:   [UUID: CGPoint] = [:]

    private var confirmedToday: Set<String> {
        Set(store.todayReservations
            .filter { $0.status == .confirmed || $0.status == .arrived }
            .map    { $0.tableNumber })
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let canvas = CGSize(
                    width:  geo.size.width,
                    height: geo.size.height
                )
                ZStack(alignment: .topLeading) {
                    // Background tap to deselect
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .onTapGesture { selectedID = nil }

                    // Grid
                    gridCanvas(size: canvas)

                    // Tables
                    ForEach(tables) { table in
                        tableCell(table, canvas: canvas)
                    }

                    // Legend
                    legend
                }
            }
            .navigationTitle("План зала")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddTable) {
                AddFloorTableView { newTable in
                    // Place new table at a non-overlapping spot
                    var t = newTable
                    t.x = 0.1
                    t.y = 0.1
                    tables.append(t)
                    saveTables()
                }
            }
            .sheet(isPresented: $showReservations) {
                TableReservationView().environmentObject(store)
            }
            .onAppear { loadTables() }
        }
    }

    // MARK: - Table cell

    @ViewBuilder
    private func tableCell(_ table: FloorTable, canvas: CGSize) -> some View {
        let sz        = TableLayout.size(for: table.shape)
        let isBooked  = confirmedToday.contains(table.number)
        let isSel     = selectedID == table.id

        // Current center in pixels = stored position + live drag offset
        let base      = pixelCenter(table, canvas: canvas, sz: sz)
        let offset    = dragOffsets[table.id] ?? .zero
        let cx        = base.x + offset.width
        let cy        = base.y + offset.height

        ZStack {
            tableShape(table, sz: sz, booked: isBooked, selected: isSel)
            tableLabel(table)
        }
        .frame(width: sz.width, height: sz.height)
        .position(x: cx, y: cy)
        .shadow(color: isSel ? .blue.opacity(0.5) : .clear, radius: 8)
        .animation(.interactiveSpring(), value: dragOffsets[table.id])
        .gesture(dragGesture(for: table, canvas: canvas, sz: sz))
        .onTapGesture {
            withAnimation(.spring(response: 0.25)) {
                selectedID = selectedID == table.id ? nil : table.id
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
                showReservations = true
            } label: {
                Label("Забронировать", systemImage: "calendar.badge.plus")
            }
        }
    }

    // MARK: - Drag gesture (translation-based — correct for .position views)

    private func dragGesture(
        for table: FloorTable,
        canvas: CGSize,
        sz: CGSize
    ) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { val in
                guard editMode else { return }
                // Store start on first movement
                if dragStarts[table.id] == nil {
                    dragStarts[table.id] = CGPoint(x: table.x, y: table.y)
                }
                dragOffsets[table.id] = val.translation
            }
            .onEnded { val in
                guard editMode,
                      let start = dragStarts[table.id],
                      let i     = tables.firstIndex(where: { $0.id == table.id })
                else { return }

                // Available range for the center point
                let availW = canvas.width  - sz.width
                let availH = canvas.height - sz.height

                guard availW > 0, availH > 0 else { return }

                // New center in pixels (from start normalized coords)
                var newCX = start.x * availW + sz.width  / 2 + val.translation.width
                var newCY = start.y * availH + sz.height / 2 + val.translation.height

                // Snap to grid
                newCX = round(newCX / TableLayout.gridStep) * TableLayout.gridStep
                newCY = round(newCY / TableLayout.gridStep) * TableLayout.gridStep

                // Convert back to 0–1 (clamped)
                let newX = max(0, min(1, (newCX - sz.width  / 2) / availW))
                let newY = max(0, min(1, (newCY - sz.height / 2) / availH))

                tables[i].x = newX
                tables[i].y = newY

                dragOffsets[table.id] = nil
                dragStarts [table.id] = nil
                saveTables()
            }
    }

    // MARK: - Helpers

    private func pixelCenter(_ table: FloorTable, canvas: CGSize, sz: CGSize) -> CGPoint {
        let availW = max(1, canvas.width  - sz.width)
        let availH = max(1, canvas.height - sz.height)
        return CGPoint(
            x: table.x * availW + sz.width  / 2,
            y: table.y * availH + sz.height / 2
        )
    }

    @ViewBuilder
    private func tableShape(
        _ table: FloorTable,
        sz: CGSize,
        booked: Bool,
        selected: Bool
    ) -> some View {
        let fill: Color    = booked   ? .orange : .green
        let stroke: Color  = selected ? .blue   : .clear
        let radius: CGFloat = table.shape == .rect ? 10 : (table.shape == .square ? 10 : sz.width / 2)

        RoundedRectangle(cornerRadius: radius)
            .fill(fill.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(stroke, lineWidth: 3)
            )
            .frame(width: sz.width, height: sz.height)
    }

    @ViewBuilder
    private func tableLabel(_ table: FloorTable) -> some View {
        VStack(spacing: 2) {
            Text("№\(table.number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            HStack(spacing: 2) {
                Text("\(table.seats)")
                    .font(.system(size: 11))
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private func gridCanvas(size: CGSize) -> some View {
        Canvas { ctx, sz in
            let step: CGFloat = 40
            let color = GraphicsContext.Shading.color(.gray.opacity(0.15))
            var px: CGFloat = 0
            while px <= sz.width {
                var path = Path()
                path.move(to: .init(x: px, y: 0))
                path.addLine(to: .init(x: px, y: sz.height))
                ctx.stroke(path, with: color, lineWidth: 0.5)
                px += step
            }
            var py: CGFloat = 0
            while py <= sz.height {
                var path = Path()
                path.move(to: .init(x: 0, y: py))
                path.addLine(to: .init(x: sz.width, y: py))
                ctx.stroke(path, with: color, lineWidth: 0.5)
                py += step
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(.green,  "Свободен")
            legendRow(.orange, "Забронирован сегодня")
            legendRow(.blue,   "Выбран")
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .allowsHitTesting(false)
    }

    private func legendRow(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button { showReservations = true } label: {
                Image(systemName: "calendar.badge.clock")
            }
            Button {
                editMode.toggle()
                if !editMode { saveTables() }
            } label: {
                Text(editMode ? "Готово" : "Изменить")
                    .fontWeight(editMode ? .semibold : .regular)
                    .foregroundStyle(editMode ? .orange : .chefAccent)
            }
            if editMode {
                Button { showAddTable = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveTables() {
        tablesData = (try? JSONEncoder().encode(tables)) ?? Data()
    }

    private func loadTables() {
        if let decoded = try? JSONDecoder().decode([FloorTable].self, from: tablesData),
           !decoded.isEmpty {
            tables = decoded
        } else {
            tables = defaultTables()
            saveTables()
        }
    }

    // Default layout — evenly spaced, no overlapping
    private func defaultTables() -> [FloorTable] {
        [
            FloorTable(number: "1",  x: 0.05, y: 0.04, seats: 2, shape: .round),
            FloorTable(number: "2",  x: 0.25, y: 0.04, seats: 4, shape: .round),
            FloorTable(number: "3",  x: 0.48, y: 0.04, seats: 4, shape: .square),
            FloorTable(number: "4",  x: 0.70, y: 0.04, seats: 4, shape: .square),
            FloorTable(number: "5",  x: 0.88, y: 0.04, seats: 6, shape: .rect),
            FloorTable(number: "6",  x: 0.05, y: 0.38, seats: 4, shape: .round),
            FloorTable(number: "7",  x: 0.25, y: 0.38, seats: 2, shape: .round),
            FloorTable(number: "8",  x: 0.48, y: 0.38, seats: 4, shape: .square),
            FloorTable(number: "9",  x: 0.70, y: 0.38, seats: 4, shape: .square),
            FloorTable(number: "10", x: 0.88, y: 0.38, seats: 8, shape: .rect),
        ]
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
                    Label("Новый стол появится в левом верхнем углу. Перетащите его на нужное место в режиме редактирования.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Добавить стол")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        guard !number.isEmpty else { return }
                        onSave(FloorTable(number: number, x: 0.05, y: 0.05,
                                         seats: seats, shape: shape))
                        dismiss()
                    }
                    .disabled(number.isEmpty)
                }
            }
        }
    }
}
