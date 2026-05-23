import SwiftUI

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject var store: ChefProStore

    @State private var selectedEmployee: Employee?
    @State private var pin = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 82))
                            .foregroundStyle(.chefAccent)

                        Text("ChefPro")
                            .font(.largeTitle)
                            .bold()

                        Text("Вход сотрудника")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 30)

                    BigCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Выберите сотрудника")
                                .font(.headline)

                            ForEach(store.employees) { employee in
                                Button {
                                    selectedEmployee = employee
                                    pin = ""
                                    showError = false
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: selectedEmployee?.id == employee.id ? "checkmark.circle.fill" : "person.crop.circle")
                                            .font(.title2)
                                            .foregroundStyle(selectedEmployee?.id == employee.id ? Color.green : Color.secondary)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(employee.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(employee.position)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                    }
                                    .frame(minHeight: 58)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    BigCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("PIN-код")
                                .font(.headline)

                            SecureField("Введите PIN", text: $pin)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .font(.title2)
                                .padding()
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            if showError {
                                Text("Неверный PIN-код")
                                    .foregroundStyle(.red)
                                    .font(.subheadline)
                            }

                            BigActionButton(title: "Войти", icon: "lock.open.fill") {
                                guard let selectedEmployee else {
                                    showError = true
                                    return
                                }

                                let success = store.login(employee: selectedEmployee, pin: pin)
                                showError = !success
                            }
                            .disabled(selectedEmployee == nil || pin.isEmpty)
                        }
                    }

                    BigCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Демо PIN-коды")
                                .font(.headline)
                            Text("Шеф: 1111")
                            Text("Су-шеф: 2222")
                            Text("Кладовщик: 3333")
                            Text("Администратор: 4444")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color.chefBackground)
        }
    }
}
