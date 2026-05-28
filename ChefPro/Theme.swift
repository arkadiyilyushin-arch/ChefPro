import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Helpers

extension FileManager {
    var documentsURL: URL { urls(for: .documentDirectory, in: .userDomainMask)[0] }
}

// MARK: - QR Code Generator

func generateQRCode(from string: String) -> UIImage {
    let data = string.data(using: .utf8)!
    let filter = CIFilter(name: "CIQRCodeGenerator")!
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("H", forKey: "inputCorrectionLevel")
    let transform = CGAffineTransform(scaleX: 10, y: 10)
    let output = filter.outputImage!.transformed(by: transform)
    return UIImage(ciImage: output)
}

// MARK: - Unit Normaliser

/// Normalises a quantity+unit pair to a human-friendly representation.
/// 1500 g  → (1.5, "кг"),  500 мл → (0.5, "л"), etc.
func normaliseUnit(quantity: Double, unit: String) -> (Double, String) {
    switch unit {
    case "г", "g":
        if quantity >= 1000 { return (quantity / 1000, "кг") }
    case "мл", "ml":
        if quantity >= 1000 { return (quantity / 1000, "л") }
    default:
        break
    }
    return (quantity, unit)
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

// MARK: - Undo Banner

struct UndoBannerModifier: ViewModifier {
    @EnvironmentObject var store: ChefProStore

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let item = store.undoItem {
                HStack {
                    Text("Удалено: \(item.description)")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Отменить") {
                        item.restore()
                        store.undoItem = nil
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.darkGray))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: store.undoItem != nil)
            }
        }
    }
}

extension View {
    func undoBanner() -> some View {
        modifier(UndoBannerModifier())
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

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var color: Color = .chefAccent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.caption) }
                Text(title).font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
