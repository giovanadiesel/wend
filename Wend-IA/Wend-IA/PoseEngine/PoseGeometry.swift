import CoreGraphics
import Foundation
import Vision

/// Calcula o ângulo em graus entre os vetores `vertex→pointA` e `vertex→pointC`
/// usando a lei dos cossenos via produto escalar.
///
/// - Parameters:
///   - vertex: O ponto vértice do ângulo (articulação central, ex: joelho).
///   - pointA: A primeira extremidade do ângulo (ex: quadril).
///   - pointC: A segunda extremidade do ângulo (ex: tornozelo).
/// - Returns: O ângulo em graus no intervalo `[0, 180]`.
///            Retorna `0` se qualquer vetor tiver magnitude zero, evitando divisão por zero.
public func angle(
    vertex: CGPoint,
    pointA: CGPoint,
    pointC: CGPoint
) -> Double {
    // Vetores vertex→pointA e vertex→pointC
    let ax = Double(pointA.x - vertex.x)
    let ay = Double(pointA.y - vertex.y)
    let cx = Double(pointC.x - vertex.x)
    let cy = Double(pointC.y - vertex.y)

    let dotProduct = ax * cx + ay * cy
    let magnitudeA = (ax * ax + ay * ay).squareRoot()
    let magnitudeC = (cx * cx + cy * cy).squareRoot()
    let magnitude = magnitudeA * magnitudeC

    // Protege contra magnitude zero (pontos coincidentes com o vértice)
    guard magnitude > 0 else { return 0 }

    // Clamp para [-1, 1] para absorver erros de ponto flutuante antes de arccos
    let cosineValue = (dotProduct / magnitude).clamped(to: -1.0...1.0)
    let radians = acos(cosineValue)
    return radians * (180.0 / .pi)
}

/// Avalia o ângulo entre três articulações em um mapa de articulações reconhecidas pelo Vision.
///
/// - Parameters:
///   - jointA: Primeira extremidade do ângulo.
///   - jointB: Vértice do ângulo (ponto central).
///   - jointC: Segunda extremidade do ângulo.
///   - joints: Dicionário de articulações reconhecidas.
///   - minConfidence: Nível mínimo de confiança (padrão: 0.5).
/// - Returns: Tupla com o ângulo calculado em graus e as confianças dos três pontos,
///   ou `nil` se alguma das articulações não for encontrada ou tiver confiança < `minConfidence`.
public func evaluateJointAngle(
    jointA: VNHumanBodyPoseObservation.JointName,
    jointB: VNHumanBodyPoseObservation.JointName,
    jointC: VNHumanBodyPoseObservation.JointName,
    in joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
    minConfidence: Float = 0.5
) -> (degrees: Double, confA: Float, confB: Float, confC: Float)? {
    guard
        let ptA = joints[jointA], ptA.confidence >= minConfidence,
        let ptB = joints[jointB], ptB.confidence >= minConfidence,
        let ptC = joints[jointC], ptC.confidence >= minConfidence
    else { return nil }

    let cgA = CGPoint(x: ptA.location.x, y: ptA.location.y)
    let cgB = CGPoint(x: ptB.location.x, y: ptB.location.y)
    let cgC = CGPoint(x: ptC.location.x, y: ptC.location.y)

    let degrees = angle(vertex: cgB, pointA: cgA, pointC: cgC)
    return (degrees: degrees, confA: ptA.confidence, confB: ptB.confidence, confC: ptC.confidence)
}

// MARK: - Comparable + ClosedRange helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

