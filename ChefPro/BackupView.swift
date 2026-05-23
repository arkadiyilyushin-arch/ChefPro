import SwiftUI

struct BackupView: View {
    @EnvironmentObject var store: ChefProStore
    @State private var showShareSheet = false
    @State private var backupURL: URL? = nil
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showImportConfirm = false
    @State private var pendingImportURL: URL? = nil

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Экспорт данных", systemImage: "arrow.up.doc.fill")
                        .font(.headline)
                    Text("Сохраняет все данные (блюда, склад, сотрудников, доставки и др.) в JSON-файл. Используйте для резервного копирования или переноса на другое устройство.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Button {
                    if let url = store.exportBackup() {
                        backupURL = url
                        showShareSheet = true
                    }
                } label: {
                    Label("Создать резервную копию", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.chefAccent)
                }
            } header: {
                Text("Резервная копия")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Импорт данных", systemImage: "arrow.down.doc.fill")
                        .font(.headline)
                    Text("Загружает данные из ранее созданного файла резервной копии. Текущие данные будут заменены.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Button {
                    showImportPicker = true
                } label: {
                    Label("Восстановить из файла", systemImage: "doc.badge.arrow.up")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Восстановление")
            }

            Section("Информация о данных") {
                HStack { Text("Блюд"); Spacer(); Text("\(store.dishes.count)").foregroundStyle(.secondary) }
                HStack { Text("Позиций склада"); Spacer(); Text("\(store.inventoryItems.count)").foregroundStyle(.secondary) }
                HStack { Text("Сотрудников"); Spacer(); Text("\(store.employees.count)").foregroundStyle(.secondary) }
                HStack { Text("Поставок"); Spacer(); Text("\(store.deliveries.count)").foregroundStyle(.secondary) }
                HStack { Text("Производств"); Spacer(); Text("\(store.productions.count)").foregroundStyle(.secondary) }
                HStack { Text("Продаж"); Spacer(); Text("\(store.sales.count)").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Резервная копия")
        .sheet(isPresented: $showShareSheet) {
            if let url = backupURL { ShareSheet(items: [url]) }
        }
        .fileImporter(isPresented: $showImportPicker,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pendingImportURL = url
                    showImportConfirm = true
                }
            case .failure:
                importErrorMessage = "Не удалось открыть файл"
                showImportError = true
            }
        }
        .alert("Восстановить данные?", isPresented: $showImportConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Восстановить", role: .destructive) {
                guard let url = pendingImportURL else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    try store.importBackup(from: url)
                    showImportSuccess = true
                } catch {
                    importErrorMessage = error.localizedDescription
                    showImportError = true
                }
            }
        } message: {
            Text("Все текущие данные будут заменены данными из файла резервной копии.")
        }
        .alert("Данные восстановлены", isPresented: $showImportSuccess) {
            Button("OK") {}
        } message: {
            Text("Резервная копия успешно загружена.")
        }
        .alert("Ошибка импорта", isPresented: $showImportError) {
            Button("OK") {}
        } message: {
            Text(importErrorMessage)
        }
    }
}
