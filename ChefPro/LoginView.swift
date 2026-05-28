import SwiftUI
import LocalAuthentication

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject var store: ChefProStore

    @State private var selectedEmployee: Employee?
    @State private var pin = ""
    @State private var showError = false
    @State private var showRegister = false
    @State private var knownIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {

                    // MARK: Logo
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 82))
                            .foregroundStyle(.chefAccent)
                        Text("ChefPro")
                            .font(.largeTitle).bold()
                        Text("Вход сотрудника")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 30)

                    // MARK: Employee list
                    BigCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Выберите сотрудника")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    knownIDs = Set(store.employees.map(\.id))
                                    showRegister = true
                                } label: {
                                    Label("Добавить", systemImage: "person.badge.plus")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.chefAccent)
                                }
                            }

                            if store.employees.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "person.slash")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.tertiary)
                                    Text("Нет сотрудников")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text("Нажмите «Добавить» чтобы создать первого сотрудника")
                                        .font(.caption).foregroundStyle(.tertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            } else {
                                ForEach(store.employees) { employee in
                                    Button {
                                        selectedEmployee = employee
                                        pin = ""
                                        showError = false
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: selectedEmployee?.id == employee.id
                                                  ? "checkmark.circle.fill" : "person.crop.circle")
                                                .font(.title2)
                                                .foregroundStyle(selectedEmployee?.id == employee.id
                                                                 ? Color.green : Color.secondary)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(employee.name)
                                                    .font(.headline).foregroundStyle(.primary)
                                                Text(employee.position)
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if employee.id == store.currentEmployeeID {
                                                Button {
                                                    authenticateWithBiometrics(employee: employee)
                                                } label: {
                                                    Image(systemName: LAContext().biometryType == .faceID ? "faceid" : "touchid")
                                                        .font(.title3)
                                                        .foregroundStyle(.chefAccent)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .frame(minHeight: 58)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // MARK: PIN
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
                                .onChange(of: pin) { _, val in
                                    if val.count > 4 { pin = String(val.prefix(4)) }
                                }

                            if showError {
                                Text("Неверный PIN-код")
                                    .foregroundStyle(.red).font(.subheadline)
                            }

                            BigActionButton(title: "Войти", icon: "lock.open.fill") {
                                guard let selectedEmployee else { showError = true; return }
                                showError = !store.login(employee: selectedEmployee, pin: pin)
                            }
                            .disabled(selectedEmployee == nil || pin.count != 4)
                        }
                    }
                }
                .padding()
            }
            .background(Color.chefBackground)
            .sheet(isPresented: $showRegister) {
                AddEditEmployeeView(employee: nil)
                    .environmentObject(store)
                    .onDisappear {
                        // Auto-select the newly registered employee
                        if let newEmployee = store.employees.first(where: { !knownIDs.contains($0.id) }) {
                            selectedEmployee = newEmployee
                        }
                    }
            }
        }
    }

    // MARK: - Biometric Authentication

    private func authenticateWithBiometrics(employee: Employee) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        let reason = "Войти как \(employee.name)"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            if success {
                DispatchQueue.main.async {
                    _ = store.login(employee: employee, pin: employee.pin)
                }
            }
        }
    }
}
