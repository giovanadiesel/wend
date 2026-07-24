import Foundation
import Vision

/// Regra de ângulo articular usada para avaliar a postura do usuário via Vision framework.
///
/// O ângulo é calculado entre os pontos `jointA–jointB–jointC`, sendo `jointB` o vértice.
public struct JointAngleRule: Hashable, Sendable {
    /// Primeira extremidade do ângulo.
    public let jointA: VNHumanBodyPoseObservation.JointName
    /// Vértice do ângulo (ponto central entre jointA e jointC).
    public let jointB: VNHumanBodyPoseObservation.JointName
    /// Segunda extremidade do ângulo.
    public let jointC: VNHumanBodyPoseObservation.JointName
    /// Intervalo de graus considerado correto para este exercício.
    public let acceptableRange: ClosedRange<Double>
    /// Texto de feedback exibido ao usuário quando o ângulo está fora do intervalo.
    public let mistakeHint: String

    public init(
        jointA: VNHumanBodyPoseObservation.JointName,
        jointB: VNHumanBodyPoseObservation.JointName,
        jointC: VNHumanBodyPoseObservation.JointName,
        acceptableRange: ClosedRange<Double>,
        mistakeHint: String
    ) {
        self.jointA = jointA
        self.jointB = jointB
        self.jointC = jointC
        self.acceptableRange = acceptableRange
        self.mistakeHint = mistakeHint
    }
}
