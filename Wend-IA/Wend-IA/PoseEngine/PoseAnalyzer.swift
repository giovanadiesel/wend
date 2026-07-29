import Combine
import CoreGraphics
import CoreMedia
import Foundation
import Vision

/// Processa frames de vídeo, executa `VNDetectHumanBodyPoseRequest` e publica
/// o mapa de articulações detectadas com confiança ≥ 0.3 para suportar diferentes condições de iluminação em dispositivos físicos.
public final class PoseAnalyzer: ObservableObject {

    // MARK: - Tipos Públicos

    /// Alias para o dicionário de articulações detectadas no frame atual.
    public typealias JointMap = [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]

    /// Resultado de uma avaliação de regra de ângulo articular.
    public struct AngleEvaluation {
        /// Ângulo calculated em graus (0–180).
        public let degrees: Double
        /// `true` se `degrees` está dentro do `acceptableRange` da regra avaliada.
        public let isWithinRange: Bool
    }

    // MARK: - Estado Publicado

    /// Articulações detectadas no frame mais recente.
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
            // `orientation: .up` para quadros convertidos em retrato pelo AVCaptureConnection
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            publishJoints([:])
            return
        }

        // Usa a primeira observação (pessoa mais proeminente no frame)
        guard
            let observation = request.results?.first,
            let allPoints = try? observation.recognizedPoints(.all)
        else {
            publishJoints([:])
            return
        }

        // Filtra articulações com confidence ≥ 0.3 para melhor sensibilidade em dispositivos físicos
        let confident = allPoints.filter { $0.value.confidence >= 0.3 }
        publishJoints(confident)
    }

    private func publishJoints(_ joints: JointMap) {
        DispatchQueue.main.async { [weak self] in
            self?.detectedJoints = joints
            self?.isDetecting = !joints.isEmpty
        }
    }

    // MARK: - Avaliação de Ângulo

    /// Avalia uma `JointAngleRule` usando os pontos detectados no frame atual
    /// e emite logs em tempo real para diagnóstico em dispositivos físicos.
    public func evaluateAngle(rule: JointAngleRule) -> AngleEvaluation? {
        let ptA = detectedJoints[rule.jointA]
        let ptB = detectedJoints[rule.jointB]
        let ptC = detectedJoints[rule.jointC]

        let confA = ptA?.confidence ?? 0
        let confB = ptB?.confidence ?? 0
        let confC = ptC?.confidence ?? 0

        guard let eval = evaluateJointAngle(
            jointA: rule.jointA,
            jointB: rule.jointB,
            jointC: rule.jointC,
            in: detectedJoints,
            minConfidence: 0.3
        ) else {
            print("🔍 [PoseAnalyzer Log] Rule Vertex (\(rule.jointB.rawValue)): Point(s) missing or confidence < 0.3 — confA(\(rule.jointA.rawValue)): \(String(format: "%.2f", confA)), confB(\(rule.jointB.rawValue)): \(String(format: "%.2f", confB)), confC(\(rule.jointC.rawValue)): \(String(format: "%.2f", confC))")
            return nil
        }

        let inRange = rule.acceptableRange.contains(eval.degrees)
        print("📐 [PoseAnalyzer Log] Rule (\(rule.jointB.rawValue)): Raw Angle = \(String(format: "%.1f", eval.degrees))° | Range: \(rule.acceptableRange) | In Range: \(inRange) | Confidences -> A(\(rule.jointA.rawValue)): \(String(format: "%.2f", eval.confA)), B(\(rule.jointB.rawValue)): \(String(format: "%.2f", eval.confB)), C(\(rule.jointC.rawValue)): \(String(format: "%.2f", eval.confC))")

        return AngleEvaluation(
            degrees: eval.degrees,
            isWithinRange: inRange
        )
    }
}
