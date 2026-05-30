import SwiftUI
import Vision
import UIKit

// MARK: - Camera Image Picker

struct CameraImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - OCR

func recogniseText(in image: UIImage, completion: @escaping (String) -> Void) {
    guard let cgImage = image.cgImage else { completion(""); return }
    let request = VNRecognizeTextRequest { req, _ in
        let text = (req.results as? [VNRecognizedTextObservation] ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        DispatchQueue.main.async { completion(text) }
    }
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ru-RU", "en-US"]
    request.usesLanguageCorrection = true
    DispatchQueue.global(qos: .userInitiated).async {
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
    }
}

// MARK: - Tech Card Parser

func parseTechCard(from text: String) -> Dish {
    var dish = Dish(name: "", category: "Основные блюда", salePrice: 0, ingredients: [])
    var ingredients: [RecipeIngredient] = []
    var steps: [CookingStep] = []

    let lines = text.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    guard !lines.isEmpty else { return dish }

    // First non-header line = dish name
    let headerKeywords = ["техкарта", "технологическая карта", "рецепт", "recipe",
                          "ингредиенты", "состав", "наименование блюда"]
    var nameIndex = 0
    for (i, line) in lines.enumerated() {
        if !headerKeywords.contains(where: { line.lowercased().contains($0) }) {
            dish.name = line
            nameIndex = i
            break
        }
    }

    // Ingredient regex: number + optional unit
    let numberPattern = try? NSRegularExpression(
        pattern: #"(\d+[\.,]?\d*)\s*(г|гр|кг|мл|л|шт|уп|ст\.л|ч\.л|g|kg|ml)\b\.?"#,
        options: .caseInsensitive
    )

    // Section detection
    var inSteps = false
    var stepNumber = 1

    let ingredientSectionKeywords = ["ингредиент", "состав", "продукт", "ingredient"]
    let stepSectionKeywords = ["приготовлен", "способ", "технология", "шаг", "step", "метод"]

    let stepPrefixPattern = try? NSRegularExpression(
        pattern: #"^(\d+[\.\):]|шаг\s*\d+)"#,
        options: .caseInsensitive
    )

    for line in lines.dropFirst(nameIndex + 1) {
        let lower = line.lowercased()

        // Section header detection
        if ingredientSectionKeywords.contains(where: { lower.contains($0) }) {
            inSteps = false; continue
        }
        if stepSectionKeywords.contains(where: { lower.contains($0) }) {
            inSteps = true; continue
        }

        // Numbered step: "1." / "1)" / "Шаг 1"
        let range = NSRange(line.startIndex..., in: line)
        if stepPrefixPattern?.firstMatch(in: line, range: range) != nil {
            let instruction = line
                .replacingOccurrences(of: #"^(\d+[\.\):]|шаг\s*\d+)\s*"#,
                                      with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if !instruction.isEmpty {
                steps.append(CookingStep(stepNumber: stepNumber, instruction: instruction))
                stepNumber += 1
                inSteps = true
                continue
            }
        }

        // Ingredient detection: line that contains number + unit
        let lineRange = NSRange(line.startIndex..., in: line)
        if !inSteps, let match = numberPattern?.firstMatch(in: line, range: lineRange) {
            // Extract quantity value
            let numRange = Range(match.range(at: 1), in: line)!
            let quantity = Double(String(line[numRange]).replacingOccurrences(of: ",", with: ".")) ?? 0
            // Extract unit
            let unitRange = Range(match.range(at: 2), in: line)!
            let unit = String(line[unitRange]).lowercased()
            // Product name = line minus the number+unit token, cleaned of list markers
            let productName = line
                .replacingOccurrences(
                    of: #"\d+[\.,]?\d*\s*(г|гр|кг|мл|л|шт|уп|ст\.л|ч\.л|g|kg|ml)\b\.?"#,
                    with: "", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"^[-–•·]\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if !productName.isEmpty && quantity > 0 {
                ingredients.append(RecipeIngredient(productName: productName,
                                                    quantity: quantity,
                                                    unit: unit))
                continue
            }
        }

        // Free-form step lines while in steps section
        if inSteps && !line.isEmpty {
            steps.append(CookingStep(stepNumber: stepNumber, instruction: line))
            stepNumber += 1
        }
    }

    dish.ingredients = ingredients
    dish.steps = steps
    return dish
}

// MARK: - Main Scanner View

struct TechCardScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ChefProStore
    let onCreate: (Dish) -> Void

    // Image picking
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var capturedImage: UIImage?

    // OCR
    @State private var recognisedText = ""
    @State private var isRecognising = false

    // Parsed result
    @State private var parsedDish: Dish?
    @State private var parsedDishName = ""

    // UI stage: .capture / .recognising / .review / .preview
    private enum Stage { case capture, recognising, review, preview }
    private var stage: Stage {
        if capturedImage == nil { return .capture }
        if isRecognising { return .recognising }
        if parsedDish != nil { return .preview }
        return .review
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.chefBackground.ignoresSafeArea()

                switch stage {
                case .capture:
                    captureStage
                case .recognising:
                    recognisingStage
                case .review:
                    reviewStage
                case .preview:
                    previewStage
                }
            }
            .navigationTitle("Сканер техкарты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                CameraImagePicker(
                    sourceType: UIImagePickerController.isSourceTypeAvailable(.camera)
                        ? .camera : .photoLibrary,
                    image: $capturedImage
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibraryPicker) {
                CameraImagePicker(sourceType: .photoLibrary, image: $capturedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: capturedImage) { _, img in
                guard let img else { return }
                startOCR(on: img)
            }
        }
    }

    // MARK: Stage 1 – Capture

    private var captureStage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.chefAccent)

            VStack(spacing: 8) {
                Text("Сфотографируйте техкарту")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Приложение распознает текст\nи заполнит форму автоматически")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                Button {
                    showCameraPicker = true
                } label: {
                    Label("Сфотографировать техкарту", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.chefAccent)
                .padding(.horizontal, 32)

                Button {
                    showLibraryPicker = true
                } label: {
                    Label("Выбрать из галереи", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.bordered)
                .tint(Color.chefAccent)
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: Stage 2 – Recognising

    private var recognisingStage: some View {
        VStack(spacing: 24) {
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.15), radius: 10)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.4)
                Text("Распознаём текст...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: Stage 3 – Review text

    private var reviewStage: some View {
        VStack(spacing: 0) {
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            capturedImage = nil
                            recognisedText = ""
                            parsedDish = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                                .padding(10)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Распознанный текст")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 14)

                TextEditor(text: $recognisedText)
                    .font(.callout)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                Text("Отредактируйте текст при необходимости")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Button {
                    parsedDish = parseTechCard(from: recognisedText)
                    parsedDishName = parsedDish?.name ?? ""
                } label: {
                    Label("Разобрать как техкарту", systemImage: "wand.and.stars")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.chefAccent)
                .disabled(recognisedText.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: Stage 4 – Parsed preview

    private var previewStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Dish name editor
                VStack(alignment: .leading, spacing: 6) {
                    Text("Название блюда")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextField("Название блюда", text: $parsedDishName)
                        .font(.title3.bold())
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 16)

                if let dish = parsedDish {
                    // Ingredients preview
                    if !dish.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ингредиенты (\(dish.ingredients.count))")
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(Array(dish.ingredients.enumerated()), id: \.element.id) { idx, ing in
                                    HStack {
                                        Text(ing.productName)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(ing.quantity, specifier: "%.1f") \(ing.unit)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(idx % 2 == 0
                                        ? Color(.systemGray6)
                                        : Color(.systemBackground))
                                }
                            }
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("Ингредиенты не распознаны")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // Steps preview
                    if !dish.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Шаги приготовления (\(dish.steps.count))")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(dish.steps) { step in
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.chefAccent.opacity(0.15))
                                            .frame(width: 28, height: 28)
                                        Text("\(step.stepNumber)")
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.chefAccent)
                                    }
                                    Text(step.instruction)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }

                // Hint
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.chefAccent)
                    Text("Вы сможете отредактировать все данные после создания")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        guard var dish = parsedDish else { return }
                        dish.name = parsedDishName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? "Новое блюдо"
                            : parsedDishName.trimmingCharacters(in: .whitespaces)
                        onCreate(dish)
                        dismiss()
                    } label: {
                        Label("Создать техкарту", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.chefAccent)
                    .disabled(parsedDishName.trimmingCharacters(in: .whitespaces).isEmpty &&
                              (parsedDish?.name.trimmingCharacters(in: .whitespaces).isEmpty ?? true))

                    Button {
                        parsedDish = nil
                    } label: {
                        Label("Изменить текст", systemImage: "pencil")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: Helpers

    private func startOCR(on image: UIImage) {
        isRecognising = true
        recognisedText = ""
        parsedDish = nil
        recogniseText(in: image) { text in
            recognisedText = text
            isRecognising = false
        }
    }
}
