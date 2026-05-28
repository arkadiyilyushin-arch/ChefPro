import SwiftUI
import Vision
import UIKit

struct InvoiceScanResult {
    var productName: String = ""
    var quantity: Double?
    var unit: String = "кг"
    var price: Double?
}

struct InvoiceScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onResult: (InvoiceScanResult) -> Void

    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var scanResult: InvoiceScanResult? = nil
    @State private var isProcessing = false
    @State private var rawText = ""

    // Editable fields after scan
    @State private var editName = ""
    @State private var editQty = ""
    @State private var editUnit = "кг"
    @State private var editPrice = ""

    let units = ["кг", "г", "л", "мл", "шт"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if capturedImage == nil {
                    // Initial state - show scan button
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 64))
                            .foregroundStyle(.chefAccent)
                        Text("Сканер накладной")
                            .font(.title2.bold())
                        Text("Сфотографируйте накладную — приложение автоматически распознает товар, количество и цену")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button {
                            showCamera = true
                        } label: {
                            Label("Сфотографировать", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.chefAccent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Распознаю текст...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Show parsed result for editing
                    Form {
                        if !rawText.isEmpty {
                            Section("Распознанный текст") {
                                Text(rawText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(6)
                            }
                        }
                        Section("Данные для приемки") {
                            TextField("Название товара", text: $editName)
                            HStack {
                                TextField("Количество", text: $editQty)
                                    .keyboardType(.decimalPad)
                                Picker("Ед.", selection: $editUnit) {
                                    ForEach(units, id: \.self) { Text($0) }
                                }
                                .frame(width: 80)
                            }
                            HStack {
                                TextField("Сумма", text: $editPrice)
                                    .keyboardType(.decimalPad)
                                Text("₽").foregroundStyle(.secondary)
                            }
                        }
                        Section {
                            Button("Применить данные") {
                                let result = InvoiceScanResult(
                                    productName: editName,
                                    quantity: Double(editQty.replacingOccurrences(of: ",", with: ".")),
                                    unit: editUnit,
                                    price: Double(editPrice.replacingOccurrences(of: ",", with: "."))
                                )
                                onResult(result)
                                dismiss()
                            }
                            .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                            Button("Сфотографировать снова") {
                                capturedImage = nil
                                scanResult = nil
                                showCamera = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Сканер накладной")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePickerView(image: $capturedImage)
            }
            .onChange(of: capturedImage) { _, img in
                guard let img else { return }
                recognizeText(in: img)
            }
        }
    }

    private func recognizeText(in image: UIImage) {
        isProcessing = true
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }
        let request = VNRecognizeTextRequest { request, _ in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            DispatchQueue.main.async {
                let result = parseInvoice(lines: lines)
                rawText = lines.prefix(8).joined(separator: "\n")
                editName = result.productName
                editQty = result.quantity.map { String(format: "%.1f", $0) } ?? ""
                editUnit = result.unit
                editPrice = result.price.map { String(format: "%.2f", $0) } ?? ""
                isProcessing = false
            }
        }
        request.recognitionLanguages = ["ru-RU", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func parseInvoice(lines: [String]) -> InvoiceScanResult {
        var result = InvoiceScanResult()
        let unitKeywords = ["кг", "г", "л", "мл", "шт", "kg", "g", "l", "ml", "pcs"]
        let numberPattern = try? NSRegularExpression(pattern: "[0-9]+[.,]?[0-9]*")

        // Find product name: longest line that doesn't look like a number/total
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count > 3 else { continue }
            let hasLetter = trimmed.contains(where: { $0.isLetter })
            let looksLikeNumber = (trimmed.filter({ $0.isNumber || $0 == "." || $0 == "," }).count > trimmed.count / 2)
            if hasLetter && !looksLikeNumber && result.productName.isEmpty {
                result.productName = trimmed
            }
        }

        // Find quantity + unit
        for line in lines {
            let lower = line.lowercased()
            for unit in unitKeywords {
                if lower.contains(unit) {
                    let range = NSRange(line.startIndex..., in: line)
                    if let match = numberPattern?.firstMatch(in: line, range: range),
                       let r = Range(match.range, in: line),
                       let qty = Double(line[r].replacingOccurrences(of: ",", with: ".")) {
                        result.quantity = qty
                        result.unit = unit == "kg" ? "кг" : unit == "g" ? "г" : unit == "l" ? "л" : unit == "ml" ? "мл" : unit == "pcs" ? "шт" : unit
                        break
                    }
                }
            }
            if result.quantity != nil { break }
        }

        // Find price: number near ₽ or "руб" or largest number in last lines
        for line in lines.reversed() {
            let lower = line.lowercased()
            if lower.contains("₽") || lower.contains("руб") || lower.contains("итог") || lower.contains("сумм") {
                let range = NSRange(line.startIndex..., in: line)
                let matches = numberPattern?.matches(in: line, range: range) ?? []
                if let last = matches.last, let r = Range(last.range, in: line),
                   let price = Double(line[r].replacingOccurrences(of: ",", with: ".")) {
                    result.price = price
                    break
                }
            }
        }
        return result
    }
}

// MARK: - UIImagePickerController wrapper
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
