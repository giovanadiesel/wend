import Combine
import CoreGraphics
import CoreMedia
import Foundation
import Vision

/// Processa frames de vídeo, executa `VNDetectHumanBodyPoseRequest` e publica
/// o mapa de articulações detectadas com confiança ≥ 0.5.
///
/// ### Uso típico
/// ```swift
/// let camera = CameraManager()
/// let analyzer = PoseAnalyzer()
/// analyzer.connect(to: camera)
/// camera.start()
/// ```
///
/// - Note: A análise ocorre em uma fila de background dedicada.
///   Todas as atualizações dos `@Published` são enviadas para a main queue.
public final class PoseAnalyzer: ObservableObject {

    // MARK: - Tipos Públicos

    /// Alias para o dicionário de articulações detectadas no frame atual.
    public typealias JointMap = [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]

    /// Resultado de uma avaliação de regra de ângulo articular.
    public struct AngleEvaluation {
        /// Ângulo calculado em graus (0–180).
        public let degrees: Double
        /// `true` se `degrees` está dentro do `acceptableRange` da regra avaliada.
        public let isWithinRange: Bool
    }

    // MARK: - Estado Publicado

    /// Articulações detectadas no frame mais recente com confidence ≥ 0.5.
    /// Dicionário vazio quando nenhuma pose é detectada.
    @Published public private(set) var detectedJoints: JointMap = [:]

    /// `true` enquanto ao menos uma articulação estiver sendo detectada.
    @Published public private(set) var isDetecting: Bool = false

    // MARK: - Internals

    private var cancellables = Set<AnyCancellable>()

    /// Fila dedicada para executar os requests do Vision sem bloquear a main thread.
    private let analysisQueue = DispatchQueue(
        label: "com.wend.pose.analysis",
        qos: .userInteractive
    )

    /// Reutiliza o handler de sequência para rastrear movimento entre frames,
    /// melhorando a acurácia do Vision em vídeo contínuo.
    private let sequenceHandler = VNSequenceRequestHandler()

    // MARK: - Conexão com CameraManager

    /// Inscreve o `PoseAnalyzer` no `framePublisher` de um `CameraManager`.
    ///
    /// - Parameter cameraManager: Instância gerenciando a sessão de captura ativa.
    public func connect(to cameraManager: CameraManager) {
        cameraManager.framePublisher
            .receive(on: analysisQueue)
            .sink { [weak self] sampleBuffer in
                self?.analyze(sampleBuffer: sampleBuffer)
            }
            .store(in: &cancellables)
    }

    /// Para de receber frames e cancela todas as subscriptions ativas.
    public func disconnect() {
        cancellables.removeAll()
    }

    // MARK: - Análise de Pose (Background)

    private func analyze(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()

        do {
            // `orientation: .up` é o padrão para câmera frontal em portrait
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            publishJoints([:])
            return
        }

        // Usa apenas a primeira observação (pessoa mais proeminente no frame)
        guard
            let observation = request.results?.first,
            let allPoints = try? observation.recognizedPoints(.all)
        else {
            publishJoints([:])
            return
        }

        // Filtra articulações com confidence menor que 0.5
        let confident = allPoints.filter { $0.value.confidence >= 0.5 }
        publishJoints(confident)
    }

    private func publishJoints(_ joints: JointMap) {
        DispatchQueue.main.async { [weak self] in
            self?.detectedJoints = joints
            self?.isDetecting = !joints.isEmpty
        }
    }

    // MARK: - Avaliação de Ângulo

    /// Avalia uma `JointAngleRule` usando os pontos detectados no frame atual.
    ///
    /// Recupera os três pontos da articulação da regra em `detectedJoints`,
    /// calcula o ângulo com a função `angle(vertex:pointA:pointC:)` e verifica
    /// se o resultado está dentro do `acceptableRange` definido na regra.
    ///
    /// - Parameter rule: Regra de ângulo articular a ser verificada.
    /// - Returns: Um `AngleEvaluation` com o grau calculado e conformidade,
    ///   ou `nil` se qualquer uma das três articulações não estiver detectada
    ///   com confiança suficiente no frame atual.
    public func evaluateAngle(rule: JointAngleRule) -> AngleEvaluation? {
        guard
            let pointA = detectedJoints[rule.jointA],
            let pointB = detectedJoints[rule.jointB],
            let pointC = detectedJoints[rule.jointC]
        else { return nil }

        // VNRecognizedPoint usa coordenadas normalizadas (0–1), origem no canto inferior esquerdo.
        let cgA = CGPoint(x: pointA.location.x, y: pointA.location.y)
        let cgB = CGPoint(x: pointB.location.x, y: pointB.location.y)
        let cgC = CGPoint(x: pointC.location.x, y: pointC.location.y)

        let degrees = angle(vertex: cgB, pointA: cgA, pointC: cgC)
        return AngleEvaluation(
            degrees: degrees,
            isWithinRange: rule.acceptableRange.contains(degrees)
        )
    }
}
