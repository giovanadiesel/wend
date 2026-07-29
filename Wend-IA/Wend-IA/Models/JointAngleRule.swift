import Foundation
import Vision

/// Regra de ângulo articular usada para avaliar a postura do usuário via Vision framework.
///
/// O ângulo é calculado entre os pontos `jointA–jointB–jointC`, sendo `jointB` o vértice.
///
/// A validação é **relativa à posição neutra do próprio usuário**, capturada no início de
/// cada sessão (ver `ExerciseSessionController`), e não a uma faixa absoluta de graus.
/// Um ângulo absoluto fixo (calibrado em vídeos de referência filmados de perfil, câmera
/// fixa) não se sustenta quando o usuário apoia o celular em qualquer lugar do quarto —
/// o mesmo movimento físico projeta ângulos 2D bem diferentes dependendo do ângulo da
/// câmera. Medir a variação em relação à própria posição inicial do usuário elimina essa
/// dependência.
public struct JointAngleRule: Hashable, Sendable {
    /// Primeira extremidade do ângulo.
    public let jointA: VNHumanBodyPoseObservation.JointName
    /// Vértice do ângulo (ponto central entre jointA e jointC).
    public let jointB: VNHumanBodyPoseObservation.JointName
    /// Segunda extremidade do ângulo.
    public let jointC: VNHumanBodyPoseObservation.JointName
    /// Variação mínima (em graus), a partir da posição neutra calibrada no início da sessão,
    /// para considerar que o usuário está na posição correta do alongamento.
    public let minimumDeltaFromBaseline: Double
    /// Texto de feedback exibido ao usuário quando o ângulo está fora do intervalo.
    public let mistakeHint: String

    public init(
        jointA: VNHumanBodyPoseObservation.JointName,
        jointB: VNHumanBodyPoseObservation.JointName,
        jointC: VNHumanBodyPoseObservation.JointName,
        minimumDeltaFromBaseline: Double,
        mistakeHint: String
    ) {
        self.jointA = jointA
        self.jointB = jointB
        self.jointC = jointC
        self.minimumDeltaFromBaseline = minimumDeltaFromBaseline
        self.mistakeHint = mistakeHint
    }
}
