import Foundation
import Vision

/// Struct representando a configuração estática de um exercício de alongamento.
///
/// Contém as instruções textuais e as regras angulares que serão usadas pelo módulo de
/// visão computacional para validar a postura do usuário em tempo real.
public struct StretchDefinition: Identifiable, Sendable {
    public let id: String
    /// Nome exibido ao usuário.
    public let name: String
    /// Passo a passo instrucional do exercício.
    public let instructions: String
    /// Tempo (em segundos) que o usuário deve manter a posição.
    public let holdDuration: TimeInterval
    /// Conjunto de regras de ângulo articular que definem a postura correta.
    public let targetJoints: [JointAngleRule]

    public init(
        id: String,
        name: String,
        instructions: String,
        holdDuration: TimeInterval,
        targetJoints: [JointAngleRule] = []
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.holdDuration = holdDuration
        self.targetJoints = targetJoints
    }
}

// MARK: - Sample Data

extension StretchDefinition {
    /// Exercícios de calibração — ajuste os `acceptableRange` após observar os
    /// ângulos reais na `PoseTestView` enquanto executa cada movimento.
    static let sampleStretches: [StretchDefinition] = [

        // ── 1. Cat Camel ────────────────────────────────────────────────────────
        // Foco: flexão/extensão da coluna. Avalia o ângulo formado entre ombro,
        // quadril e joelho no plano lateral para checar o arco do movimento.
        StretchDefinition(
            id: "cat-camel",
            name: "Cat Camel",
            instructions: """
            Posicione-se em quatro apoios (mãos e joelhos). \
            Inspire arqueando as costas para baixo (cat) e expire arqueando para cima (camel). \
            Mantenha o pescoço neutro. Repita lentamente.
            """,
            holdDuration: 5,
            targetJoints: [
                // Ombro direito → Quadril direito (vértice) → Joelho direito
                // Avalia o arco lateral do tronco durante o movimento
                JointAngleRule(
                    jointA: .rightShoulder,
                    jointB: .rightHip,
                    jointC: .rightKnee,
                    acceptableRange: 70.0...110.0, // TODO: ajustar com valores observados na PoseTestView
                    mistakeHint: "Amplie o movimento: o arco do tronco está insuficiente."
                ),
            ]
        ),

        // ── 2. Bridge Pose ──────────────────────────────────────────────────────
        // Foco: extensão de quadril com ativação de glúteo. Avalia o ângulo do
        // joelho (a perna deve formar ~90° com o chão) e o alinhamento do tronco.
        StretchDefinition(
            id: "bridge-pose",
            name: "Bridge Pose",
            instructions: """
            Deite de costas com joelhos dobrados e pés no chão. \
            Eleve o quadril até ombros, quadril e joelhos formarem uma linha reta. \
            Contraia os glúteos e mantenha a posição.
            """,
            holdDuration: 15,
            targetJoints: [
                // Quadril direito → Joelho direito (vértice) → Tornozelo direito
                // Verifica que o joelho está a ~90° (perna vertical ao chão)
                JointAngleRule(
                    jointA: .rightHip,
                    jointB: .rightKnee,
                    jointC: .rightAnkle,
                    acceptableRange: 70.0...110.0, // TODO: ajustar com valores observados na PoseTestView
                    mistakeHint: "Ajuste a posição dos pés: o joelho deve estar a 90° do chão."
                ),
                // Ombro direito → Quadril direito (vértice) → Joelho direito
                // Verifica que o tronco está elevado e alinhado (linha ombro-quadril-joelho)
                JointAngleRule(
                    jointA: .rightShoulder,
                    jointB: .rightHip,
                    jointC: .rightKnee,
                    acceptableRange: 70.0...110.0, // TODO: ajustar com valores observados na PoseTestView
                    mistakeHint: "Eleve mais o quadril para alinhar com ombros e joelhos."
                ),
            ]
        ),

        // ── 3. Piriformis Stretch ───────────────────────────────────────────────
        // Foco: rotação externa do quadril, alongando o músculo piriforme.
        // Avalia o ângulo do joelho cruzado sobre a coxa (posição de "4").
        StretchDefinition(
            id: "piriformis-stretch",
            name: "Piriformis Stretch",
            instructions: """
            Deite de costas. Cruze o tornozelo direito sobre o joelho esquerdo \
            formando o número 4. Puxe a coxa esquerda em direção ao peito. \
            Sinta o alongamento no glúteo direito. Troque o lado após o tempo.
            """,
            holdDuration: 30,
            targetJoints: [
                // Joelho direito → Quadril direito (vértice) → Tornozelo esquerdo
                // Avalia a abertura do quadril: quanto mais aberto, maior o ângulo
                JointAngleRule(
                    jointA: .rightKnee,
                    jointB: .rightHip,
                    jointC: .leftAnkle,
                    acceptableRange: 70.0...110.0, // TODO: ajustar com valores observados na PoseTestView
                    mistakeHint: "Puxe mais a coxa: o quadril não está suficientemente aberto."
                ),
            ]
        ),
    ]
}
