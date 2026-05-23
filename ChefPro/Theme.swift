import SwiftUI

// MARK: - Helpers

extension FileManager {
    var documentsURL: URL { urls(for: .documentDirectory, in: .userDomainMask)[0] }
}

func parsePositiveDouble(_ text: String) -> Double? {
    guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
    return v
}

func parseNonNegativeDouble(_ text: String) -> Double? {
    guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v >= 0 else { return nil }
    return v
}

// MARK: - Theme

extension Color {
    static let chefBackground = Color(.systemGroupedBackground)
    static let chefCard = Color(.secondarySystemGroupedBackground)
    static let chefAccent = Color.orange
}

// Enables dot-syntax in ShapeStyle contexts, e.g. .foregroundStyle(.chefAccent)
extension ShapeStyle where Self == Color {
    static var chefAccent: Color { .orange }
}

struct BigCard<Content: View>: View {
    let content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.chefCard)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

struct BigActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(.chefAccent)
        .controlSize(.large)
    }
}
