import SwiftUI

struct ExpenseListView: View {
    @EnvironmentObject var vm: ExpenseViewModel
    @State private var showAdd = false
    @State private var filterCategory: ExpenseCategory? = nil

    var filtered: [CarExpense] {
        guard let f = filterCategory else { return vm.currentCarExpenses }
        return vm.currentCarExpenses.filter { $0.category == f }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    filterBar
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        expenseList
                    }
                }

                addButton
            }
            .navigationTitle(vm.selectedCar?.displayName ?? "Расходы")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAdd) {
                AddExpenseView()
                    .environmentObject(vm)
            }
        }
    }

    // MARK: - Filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(label: "Все", isSelected: filterCategory == nil) {
                    filterCategory = nil
                }
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    FilterChip(label: cat.rawValue, icon: cat.icon,
                               isSelected: filterCategory == cat) {
                        filterCategory = filterCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - List

    private var expenseList: some View {
        List {
            ForEach(filtered) { expense in
                ExpenseRowView(expense: expense)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: vm.deleteExpense)
        }
        .listStyle(.plain)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Нет записей")
                .font(.title2.bold())
            Text("Нажмите «+» чтобы добавить\nпервую запись")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - FAB

    private var addButton: some View {
        Button {
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .accentColor.opacity(0.4), radius: 12, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        .disabled(vm.selectedCar == nil)
    }
}

// MARK: - Row

struct ExpenseRowView: View {
    let expense: CarExpense

    var categoryColor: Color {
        switch expense.category {
        case .fuel: return .orange
        case .service: return .blue
        case .other: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: expense.category.icon)
                    .foregroundColor(categoryColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.category.rawValue)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "speedometer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(expense.mileage.formatted()) км")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let liters = expense.liters {
                    Text(String(format: "%.1f л", liters))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(expense.amount.formatted(.number.precision(.fractionLength(0)))) ₽")
                .font(.headline.bold())
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.bold())
                }
                Text(label)
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? .accentColor.opacity(0.3) : .clear, radius: 4)
        }
    }
}
