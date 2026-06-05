import SwiftUI
import LocalAuthentication

// MARK: - Экран входа

struct LoginView: View {
    @EnvironmentObject var store: ChefProStore

    @State private var selectedEmployee: Employee?
    @State private var pin = ""
    @State private var showError = false
    @State private var errorShake = false
    @State private var showRegister = false
    @State private var knownIDs: Set<UUID> = []
    @State private var appeared = false

    private var biometryType: LABiometryType { LAContext().biometryType }

    var body: some View {
        ZStack {
            // ── Фон ──────────────────────────────────────────
            Color(.systemBackground).ignoresSafeArea()
            LinearGradient(
                colors: [Color.chefAccent.opacity(0.18), Color.clear],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Логотип ───────────────────────────────────
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.chefAccent.opacity(0.15))
                            .frame(width: 90, height: 90)
                        Circle()
                            .fill(Color.chefAccent.opacity(0.1))
                            .frame(width: 110, height: 110)
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(Color.chefAccent)
                            .scaleEffect(appeared ? 1 : 0.5)
                            .opacity(appeared ? 1 : 0)
                    }

                    Text(store.restaurantName)
                        .font(.title2.bold())
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)

                    Text("Войдите в систему")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.top, 48)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)

                // ── Выбор сотрудника ──────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Сотрудник")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                        Spacer()
                        Button {
                            knownIDs = Set(store.employees.map(\.id))
                            showRegister = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.plus").font(.caption)
                                Text("Добавить").font(.caption.bold())
                            }
                            .foregroundStyle(.chefAccent)
                            .padding(.trailing, 20)
                        }
                        .buttonStyle(.plain)
                    }

                    if store.employees.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "person.slash")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("Нажмите «Добавить» чтобы создать первого сотрудника")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.employees) { emp in
                                    employeeCard(emp)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                Spacer()

                // ── PIN-индикатор ─────────────────────────────
                if selectedEmployee != nil {
                    VStack(spacing: 20) {
                        Text(selectedEmployee?.name ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            ForEach(0..<4, id: \.self) { i in
                                Circle()
                                    .fill(i < pin.count ? Color.chefAccent : Color(.systemGray4))
                                    .frame(width: 14, height: 14)
                                    .scaleEffect(i < pin.count ? 1.15 : 1)
                                    .animation(.spring(response: 0.2), value: pin.count)
                            }
                        }
                        .offset(x: errorShake ? -8 : 0)
                        .animation(errorShake ? .default.repeatCount(4, autoreverses: true).speed(6) : .default, value: errorShake)

                        if showError {
                            Text("Неверный PIN-код")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
                }

                // ── Цифровая клавиатура ───────────────────────
                if selectedEmployee != nil {
                    pinPad
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
            // Биометрия для последнего вошедшего
            if let id = store.currentEmployeeID,
               let emp = store.employees.first(where: { $0.id == id }) {
                selectedEmployee = emp
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateWithBiometrics(employee: emp)
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            AddEditEmployeeView(employee: nil)
                .environmentObject(store)
                .onDisappear {
                    if let newEmp = store.employees.first(where: { !knownIDs.contains($0.id) }) {
                        selectedEmployee = newEmp
                    }
                }
        }
        .animation(.spring(response: 0.35), value: selectedEmployee?.id)
    }

    // MARK: - Карточка сотрудника

    private func employeeCard(_ emp: Employee) -> some View {
        let isSelected = selectedEmployee?.id == emp.id
        let isLast = emp.id == store.currentEmployeeID

        return Button {
            selectedEmployee = emp
            pin = ""
            showError = false
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? Color.chefAccent
                              : Color(.secondarySystemGroupedBackground))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? Color.chefAccent : Color.clear, lineWidth: 2.5)
                                .frame(width: 62, height: 62)
                        )
                        .shadow(color: isSelected ? Color.chefAccent.opacity(0.35) : .clear, radius: 8)

                    Text(initials(emp.name))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .primary)

                    if isLast && biometryType != .none {
                        Image(systemName: biometryType == .faceID ? "faceid" : "touchid")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.chefAccent)
                            .clipShape(Circle())
                            .offset(x: 19, y: 19)
                    }
                }

                Text(emp.name.components(separatedBy: " ").first ?? emp.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .chefAccent : .primary)

                Text(emp.position)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected
                          ? Color.chefAccent.opacity(0.08)
                          : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.chefAccent.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Цифровая клавиатура

    private var pinPad: some View {
        VStack(spacing: 14) {
            ForEach([[1,2,3],[4,5,6],[7,8,9],[0,-1,-2]], id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(row, id: \.self) { val in
                        if val > 0 {
                            pinKey(label: "\(val)") { appendPin("\(val)") }
                        } else if val == -1 {
                            pinKey(label: "0") { appendPin("0") }
                        } else if val == -2 {
                            // Биометрия или пустое место
                            if let emp = selectedEmployee,
                               emp.id == store.currentEmployeeID,
                               biometryType != .none {
                                pinKey(
                                    icon: biometryType == .faceID ? "faceid" : "touchid",
                                    accent: true
                                ) { authenticateWithBiometrics(employee: emp) }
                            } else {
                                pinKey(label: "") { }
                                    .opacity(0)
                            }
                        }
                    }
                }
            }

            // Удалить
            Button {
                if !pin.isEmpty { pin.removeLast() }
                showError = false
            } label: {
                Image(systemName: "delete.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 44)
            }
            .buttonStyle(.plain)
            .opacity(pin.isEmpty ? 0.3 : 1)
        }
        .padding(.horizontal, 40)
    }

    private func pinKey(label: String = "", icon: String? = nil, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(accent ? Color.chefAccent.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                    .frame(width: 72, height: 72)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(accent ? .chefAccent : .primary)
                } else {
                    Text(label)
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }

    // MARK: - Вспомогательные методы

    private func appendPin(_ digit: String) {
        guard pin.count < 4 else { return }
        showError = false
        pin += digit
        if pin.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { attemptLogin() }
        }
    }

    private func attemptLogin() {
        guard let emp = selectedEmployee else { return }
        if store.login(employee: emp, pin: pin) {
            pin = ""
        } else {
            showError = true
            errorShake = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                errorShake = false
                pin = ""
            }
        }
    }

    private func authenticateWithBiometrics(employee: Employee) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Войти как \(employee.name)") { success, _ in
            if success {
                DispatchQueue.main.async { _ = store.login(employee: employee, pin: employee.pin) }
            }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return String((parts[0].first ?? "?")) + String((parts[1].first ?? ""))
        }
        return String(name.prefix(2)).uppercased()
    }
}
