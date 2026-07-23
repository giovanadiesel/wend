import AVFoundation
import Combine

/// Gerencia o ciclo de vida de uma `AVCaptureSession` usando a câmera frontal.
///
/// Expõe o `previewLayer` para integração com UIKit/SwiftUI e publica cada
/// `CMSampleBuffer` capturado via `framePublisher` para consumo pela `PoseAnalyzer`.
///
/// - Note: Toda atualização de estado publicado (`isRunning`, `authorizationError`)
///   ocorre na main queue para compatibilidade direta com SwiftUI.
public final class CameraManager: NSObject, ObservableObject {

    // MARK: - Estado Publicado

    /// `true` enquanto a sessão de captura estiver ativa.
    @Published public private(set) var isRunning: Bool = false

    /// Erro de autorização de câmera, se houver.
    @Published public private(set) var authorizationError: CameraError?

    // MARK: - Sessão e Preview

    /// Sessão de captura compartilhada — use para configurar o `AVCaptureVideoPreviewLayer`.
    public let session = AVCaptureSession()

    /// Layer de preview pronto para ser inserido em uma `UIView` ou `CALayer`.
    public private(set) lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)

    // MARK: - Publisher de Frames

    /// Emite cada `CMSampleBuffer` capturado pela câmera frontal.
    /// Conecte-o à `PoseAnalyzer` para iniciar a análise de postura.
    public let framePublisher = PassthroughSubject<CMSampleBuffer, Never>()

    // MARK: - Filas Privadas

    /// Fila dedicada para configurar e controlar a sessão AVCapture.
    private let sessionQueue = DispatchQueue(
        label: "com.wend.camera.session",
        qos: .userInteractive
    )

    /// Fila dedicada para receber buffers de vídeo do delegate.
    private let outputQueue = DispatchQueue(
        label: "com.wend.camera.output",
        qos: .userInteractive
    )

    // MARK: - Inicialização

    override public init() {
        super.init()
    }

    // MARK: - Autorização

    /// Solicita permissão de câmera ao usuário e configura a sessão se concedida.
    public func requestAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureSession()
                } else {
                    DispatchQueue.main.async {
                        self?.authorizationError = .unauthorized
                    }
                }
            }
        default:
            DispatchQueue.main.async { [weak self] in
                self?.authorizationError = .unauthorized
            }
        }
    }

    // MARK: - Controle da Sessão

    /// Inicia a captura de vídeo. Chame após `requestAuthorization()`.
    public func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    /// Para a captura de vídeo e libera recursos de processamento.
    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    // MARK: - Configuração Privada

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            self.session.sessionPreset = .high

            // Câmera frontal
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            ) else {
                DispatchQueue.main.async { self.authorizationError = .noFrontCamera }
                return
            }

            // Input
            guard let deviceInput = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(deviceInput) else {
                DispatchQueue.main.async { self.authorizationError = .inputSetupFailed }
                return
            }
            self.session.addInput(deviceInput)

            // Output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)

            guard self.session.canAddOutput(videoOutput) else {
                DispatchQueue.main.async { self.authorizationError = .outputSetupFailed }
                return
            }
            self.session.addOutput(videoOutput)

            // Espelha a imagem para que a câmera frontal se comporte como um espelho
            if let connection = videoOutput.connection(with: .video),
               connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Recebe cada frame capturado e o publica via `framePublisher`.
    /// Chamado na `outputQueue` — Combine propaga o valor para os subscribers.
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        framePublisher.send(sampleBuffer)
    }
}

// MARK: - Erros

extension CameraManager {
    public enum CameraError: Error, LocalizedError {
        case unauthorized
        case noFrontCamera
        case inputSetupFailed
        case outputSetupFailed

        public var errorDescription: String? {
            switch self {
            case .unauthorized:      return "Acesso à câmera negado. Habilite nas configurações do app."
            case .noFrontCamera:    return "Câmera frontal não encontrada neste dispositivo."
            case .inputSetupFailed: return "Não foi possível configurar a entrada da câmera."
            case .outputSetupFailed: return "Não foi possível configurar a saída de vídeo."
            }
        }
    }
}
