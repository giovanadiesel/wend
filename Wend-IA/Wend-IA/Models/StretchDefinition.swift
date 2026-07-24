import Foundation
import Vision

/// Struct representando a configuração estática de um exercício de alongamento.
///
/// Contém as instruções textuais e as regras angulares que serão usadas pelo módulo de
/// visão computacional para validar a postura do usuário em tempo real.
public struct StretchDefinition: Identifiable, Hashable, Sendable {
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
    /// Exercícios do plano diário — `acceptableRange` calibrado via `VideoAngleAnalyzerScript`
    /// sobre vídeos de referência (P10–P90 observado, conf ≥ 0.3).
    ///
    /// Fonte: análise de 15 vídeos em 5 pastas (3 por exercício).
    /// Data de calibração: 2026-07-24.
    static let sampleStretches: [StretchDefinition] = [

        // ── 1. Cat Camel ────────────────────────────────────────────────────────
        // Foco: flexão/extensão da coluna. Avalia o ângulo ombro–quadril–joelho
        // no plano lateral (vista de lado) para confirmar o arco de movimento.
        //
        // Dados observados (conf ≥ 0.3):
        //   How to do the cat camel.mp4  → P10–P90: 111°–123° (260 frames válidos)
        //   video_1280x720-2.mp4         → P10–P90: 112°–126° (151 frames válidos)
        //   Consenso: 110°–135° (inclui fase de extensão máxima ~135°)
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
                // rightShoulder → rightHip (vértice) → rightKnee
                // Faixa calibrada: P10–P90 de 2 vídeos com boa detecção
                JointAngleRule(
                    jointA: .rightShoulder,
                    jointB: .rightHip,
                    jointC: .rightKnee,
                    acceptableRange: 110.0...135.0,
                    mistakeHint: "Amplie o movimento — o arco do tronco está insuficiente."
                ),
            ]
        ),

        // ── 2. Bridge Pose ──────────────────────────────────────────────────────
        // Foco: extensão do quadril com ativação de glúteo.
        // Exercício supino — Vision detecta melhor a flexão do joelho antes do lift.
        //
        // Dados observados (conf ≥ 0.3):
        //   video_1280x720-2.mp4 → P10–P90: 38°–52° (167 frames) — fase de setup
        //   bridge pose yoga.mp4 → P10–P90: 27°–66° (257 frames) — inclui subida/descida
        //   Nota: ângulo no hold (quadril elevado, joelho ~90°) não capturado nos vídeos.
        //   Faixa estimada para hold: 80°–110° (validar na PoseTestView ao vivo).
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
                // rightHip → rightKnee (vértice) → rightAnkle
                // Faixa estimada para posição de hold (joelho ~90°)
                // TODO: validar na PoseTestView — exercício supino dificulta calibração por vídeo
                JointAngleRule(
                    jointA: .rightHip,
                    jointB: .rightKnee,
                    jointC: .rightAnkle,
                    acceptableRange: 80.0...110.0,
                    mistakeHint: "Ajuste os pés — o joelho deve formar ~90° com o chão."
                ),
            ]
        ),

        // ── 3. Seated Spinal Twist ──────────────────────────────────────────────
        // Foco: rotação do tronco. Avalia o ângulo formado entre ombro esquerdo,
        // ombro direito (vértice) e quadril direito — mede o twist lateral.
        //
        // Dados observados (conf ≥ 0.3):
        //   Seated Spinal Twist - CORE.mp4 → P10–P90: 86°–127° (736/792 frames — excelente)
        //   Seated Spinal Twist.mp4        → P10–P90: 91°–93°  (152 frames — posição neutra)
        //   video_1280x720-2.mp4           → P10–P90: 79°–85°  (120/120 frames — fase inicial)
        //   Consenso: faixa de rotação ativa é 80°–130°
        StretchDefinition(
            id: "seated-spinal-twist",
            name: "Seated Spinal Twist",
            instructions: """
            Sente-se com as pernas estendidas. Cruze o joelho direito dobrado sobre a \
            perna esquerda. Coloque o cotovelo esquerdo fora do joelho direito e gire \
            o tronco para a direita. Mantenha a coluna ereta durante o twist.
            """,
            holdDuration: 20,
            targetJoints: [
                // leftShoulder → rightShoulder (vértice) → rightHip
                // Faixa calibrada: cobre posição neutra (80°) até twist completo (130°)
                JointAngleRule(
                    jointA: .leftShoulder,
                    jointB: .rightShoulder,
                    jointC: .rightHip,
                    acceptableRange: 80.0...130.0,
                    mistakeHint: "Gire mais o tronco — mantenha o quadril estável e o ombro afastado do quadril."
                ),
            ]
        ),

        // ── 4. Seated Piriformis Stretch ────────────────────────────────────────
        // Foco: rotação externa do quadril, alongando o músculo piriforme.
        // Avalia o ângulo joelho direito–quadril direito (vértice)–joelho esquerdo.
        //
        // Dados observados (conf ≥ 0.3):
        //   Seated Piriformis Stretch.mp4 → P10–P90: 65°–120° (211/319 frames)
        //   MedBridge.mp4                 → P10–P90: 29°–114° (165/311 frames — inclui cruzamento)
        //   Consenso: posição de hold ativo ≈ 65°–120°
        StretchDefinition(
            id: "piriformis-stretch",
            name: "Piriformis Stretch",
            instructions: """
            Sente-se em uma cadeira. Cruze o tornozelo direito sobre o joelho esquerdo \
            formando o número 4. Incline levemente o tronco para frente mantendo as \
            costas retas. Sinta o alongamento no glúteo direito. Troque o lado após o tempo.
            """,
            holdDuration: 30,
            targetJoints: [
                // rightKnee → rightHip (vértice) → leftKnee
                // Faixa calibrada: P10–P90 do vídeo com detecção mais consistente
                JointAngleRule(
                    jointA: .rightKnee,
                    jointB: .rightHip,
                    jointC: .leftKnee,
                    acceptableRange: 60.0...120.0,
                    mistakeHint: "Incline o tronco para frente — isso aprofunda o alongamento do piriforme."
                ),
            ]
        ),

        // ── 5. Lumbar Rotation ──────────────────────────────────────────────────
        // Exercício executado em posição **supina** com swiss ball.
        // O VNDetectHumanBodyPoseRequest é treinado para poses verticais e não
        // consegue mapear joints com confiança em posição horizontal — confirmado
        // na análise de 3 vídeos (0 frames válidos em todos).
        //
        // Solução: `targetJoints` vazio → modo time-only no ExerciseSessionController.
        // O cronômetro inicia imediatamente; o usuário mantém a posição pelo
        // holdDuration sem validação de ângulo. PRECISION na sessão será 100%.
        StretchDefinition(
            id: "lumbar-rotation",
            name: "Lumbar Rotation",
            instructions: """
            Deite de costas com os joelhos dobrados e os pés no chão. \
            Mantenha os ombros no chão e deixe os joelhos caírem lentamente \
            para um lado. Segure a posição e volte ao centro antes de trocar.
            """,
            holdDuration: 20,
            targetJoints: [] // Exercício supino — rastreio por tempo (sem ângulo)
        ),

    ]
}



