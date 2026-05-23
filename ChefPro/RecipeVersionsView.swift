import SwiftUI

struct RecipeVersionsView: View {
    @EnvironmentObject var store: ChefProStore
    let dish: Dish

    private var versions: [RecipeVersion] { store.versions(for: dish) }

    var body: some View {
        List {
            if versions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Нет версий",
                    subtitle: "История изменений появится после первого редактирования техкарты"
                )
            } else {
                ForEach(versions) { version in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(version.savedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                                Text("Сохранил: \(version.savedBy)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(version.ingredients.count) ингр.")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\(String(format: "%.2f", version.salePrice))")
                                    .font(.caption.bold()).foregroundStyle(.chefAccent)
                            }
                        }

                        if !version.notes.isEmpty {
                            Text(version.notes).font(.caption).foregroundStyle(.secondary)
                                .italic()
                        }

                        if !version.ingredients.isEmpty {
                            Text(version.ingredients.prefix(3).map { $0.productName }.joined(separator: ", ")
                                 + (version.ingredients.count > 3 ? "..." : ""))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .leading) {
                        Button {
                            store.restoreVersion(version)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("Восстановить", systemImage: "arrow.counterclockwise")
                        }
                        .tint(.chefAccent)
                    }
                }
                .onDelete { store.recipeVersions.remove(atOffsets: $0) }
            }
        }
        .navigationTitle("История версий")
        .navigationBarTitleDisplayMode(.inline)
    }
}
