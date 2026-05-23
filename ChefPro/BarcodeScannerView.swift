import SwiftUI
import AVFoundation

// MARK: - Barcode Scanner (UIViewRepresentable)

struct BarcodeCameraView: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIView(context: Context) -> ScannerPreviewView {
        let view = ScannerPreviewView()
        view.coordinator = context.coordinator
        context.coordinator.setup(in: view)
        return view
    }

    func updateUIView(_ uiView: ScannerPreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: ScannerPreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        private let session = AVCaptureSession()
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func setup(in view: ScannerPreviewView) {
            guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else { return }

            session.beginConfiguration()

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .qr, .code128]

            session.commitConfiguration()

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            view.previewLayer = previewLayer
            view.layer.insertSublayer(previewLayer, at: 0)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        func stop() {
            if session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.session.stopRunning()
                }
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = object.stringValue else { return }
            hasScanned = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onScan(code)
        }
    }
}

// MARK: - Preview View (manages AVCaptureVideoPreviewLayer frame updates)

final class ScannerPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    var coordinator: BarcodeCameraView.Coordinator?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Viewfinder Overlay

struct ScannerViewfinderOverlay: View {
    @State private var scanLineOffset: CGFloat = -100

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width * 0.7, 260.0)
            let rectX = (geo.size.width - size) / 2
            let rectY = (geo.size.height - size) / 2

            ZStack {
                // Semi-transparent background with clear center rectangle
                Color.black.opacity(0.55)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .frame(width: size, height: size)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )

                // Corner brackets
                cornerBrackets(x: rectX, y: rectY, size: size)

                // Animated scan line
                Rectangle()
                    .fill(Color.green.opacity(0.85))
                    .frame(width: size - 20, height: 2)
                    .offset(x: 0, y: rectY + scanLineOffset)
                    .animation(
                        .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true),
                        value: scanLineOffset
                    )
                    .onAppear { scanLineOffset = size / 2 - 4 }
            }
        }
    }

    @ViewBuilder
    private func cornerBrackets(x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        let bracketLen: CGFloat = 24
        let lineW: CGFloat = 3
        let color = Color.green

        // Top-left
        Path { p in
            p.move(to: CGPoint(x: x + bracketLen, y: y))
            p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + bracketLen))
        }
        .stroke(color, lineWidth: lineW)

        // Top-right
        Path { p in
            p.move(to: CGPoint(x: x + size - bracketLen, y: y))
            p.addLine(to: CGPoint(x: x + size, y: y))
            p.addLine(to: CGPoint(x: x + size, y: y + bracketLen))
        }
        .stroke(color, lineWidth: lineW)

        // Bottom-left
        Path { p in
            p.move(to: CGPoint(x: x, y: y + size - bracketLen))
            p.addLine(to: CGPoint(x: x, y: y + size))
            p.addLine(to: CGPoint(x: x + bracketLen, y: y + size))
        }
        .stroke(color, lineWidth: lineW)

        // Bottom-right
        Path { p in
            p.move(to: CGPoint(x: x + size, y: y + size - bracketLen))
            p.addLine(to: CGPoint(x: x + size, y: y + size))
            p.addLine(to: CGPoint(x: x + size - bracketLen, y: y + size))
        }
        .stroke(color, lineWidth: lineW)
    }
}

// MARK: - Simulator Fallback

struct BarcodeScannerSimulatorFallback: View {
    @Binding var manualCode: String
    let onScan: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Камера недоступна")
                .font(.title3).bold()
            Text("Введите штрихкод вручную")
                .foregroundStyle(.secondary)
            TextField("Штрихкод", text: $manualCode)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            Button("Применить") {
                guard !manualCode.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                onScan(manualCode)
            }
            .buttonStyle(.borderedProminent)
            .disabled(manualCode.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
}

// MARK: - BarcodeScannerSheet

struct BarcodeScannerSheet: View {
    @Binding var isPresented: Bool
    let onScan: (String) -> Void

    @State private var manualCode = ""
    private var cameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraAvailable {
                    BarcodeCameraView(onScan: { code in
                        onScan(code)
                        isPresented = false
                    })
                    .ignoresSafeArea()

                    ScannerViewfinderOverlay()
                        .ignoresSafeArea()

                    VStack {
                        Spacer()
                        Text("Наведите камеру на штрихкод")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(.bottom, 40)
                    }
                } else {
                    BarcodeScannerSimulatorFallback(manualCode: $manualCode) { code in
                        onScan(code)
                        isPresented = false
                    }
                }
            }
            .navigationTitle("Сканер штрихкода")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { isPresented = false }
                }
            }
        }
    }
}
