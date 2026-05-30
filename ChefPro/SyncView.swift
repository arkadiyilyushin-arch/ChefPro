import SwiftUI

// MARK: - Sync Setup View
// Allows two devices to share the same Firestore restaurantID
// so data is synchronized in real-time between them.

struct SyncView: View {
    @EnvironmentObject var store: ChefProStore

    @State private var joinCode        = ""
    @State private var showJoinAlert   = false
    @State private var isConnecting    = false
    @State private var connectionError: String? = nil
    @State private var showCopied      = false

    private let service = ChefProFirebaseService.shared

    var body: some View {
        List {

            // ── This device's sync code ───────────────────────────
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Код этого устройства")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    Text(service.syncCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(.chefAccent)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)

                    Text("Полный ID: \(service.restaurantID)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button {
                        UIPasteboard.general.string = service.restaurantID
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopied = false
                        }
                    } label: {
                        Label(showCopied ? "Скопировано!" : "Скопировать полный ID",
                              systemImage: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(showCopied ? .green : .chefAccent)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Это устройство")
            } footer: {
                Text("Поделитесь этим кодом со вторым устройством чтобы данные синхронизировались.")
            }

            // ── Connect to another device ─────────────────────────
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Введите полный ID с другого устройства (скопируйте его там и вставьте здесь):")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Вставьте ID сюда…", text: $joinCode, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2...3)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if let err = connectionError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        showJoinAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            if isConnecting {
                                ProgressView().tint(.white)
                            } else {
                                Label("Подключиться", systemImage: "link.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.chefAccent)
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Подключиться к другому устройству")
            } footer: {
                Text("⚠️ Данные этого устройства будут заменены данными с подключаемого устройства.")
            }

            // ── Sync status ───────────────────────────────────────
            Section("Статус синхронизации") {
                HStack {
                    Label("Последняя синхронизация", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if let date = store.lastSyncDate {
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Нет данных").foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Label("Статус", systemImage: store.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                    Spacer()
                    if store.isSyncing {
                        Text("Синхронизация…").foregroundStyle(.orange)
                    } else if let err = store.syncError {
                        Text(err).foregroundStyle(.red).lineLimit(1)
                    } else {
                        Text("В норме").foregroundStyle(.green)
                    }
                }

                Button {
                    Task {
                        await store.syncFromCloud()
                    }
                } label: {
                    Label("Синхронизировать сейчас", systemImage: "icloud.and.arrow.down")
                }
                .disabled(store.isSyncing)
            }

            // ── How it works ──────────────────────────────────────
            Section("Как работает синхронизация") {
                VStack(alignment: .leading, spacing: 8) {
                    stepRow(1, "Скопируйте полный ID на этом устройстве")
                    stepRow(2, "На втором устройстве: Еще → Синхронизация → вставьте ID → Подключиться")
                    stepRow(3, "Оба устройства теперь работают с одними данными")
                    stepRow(4, "Изменения синхронизируются автоматически в реальном времени")
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Синхронизация")
        .navigationBarTitleDisplayMode(.large)
        .alert("Подключиться к устройству?", isPresented: $showJoinAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Подключиться", role: .destructive) {
                Task { await connectToDevice() }
            }
        } message: {
            Text("Данные этого устройства будут заменены данными с другого устройства. Это действие нельзя отменить.")
        }
    }

    private func connectToDevice() async {
        let trimmed = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isConnecting = true
        connectionError = nil
        await store.connectToDevice(restaurantID: trimmed)
        isConnecting = false
        if store.syncError != nil {
            connectionError = "Не удалось подключиться. Проверьте ID и интернет."
        } else {
            joinCode = ""
        }
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.chefAccent)
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
