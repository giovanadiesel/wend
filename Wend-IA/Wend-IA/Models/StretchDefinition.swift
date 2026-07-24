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
    /// Dica de respiração exibida no ExerciseDetailView.
    public let breathingTip: String?
    /// Tempo (em segundos) que o usuário deve manter a posição.
    public let holdDuration: TimeInterval
    /// Conjunto de regras de ângulo articular que definem a postura correta.
    public let targetJoints: [JointAngleRule]

    public init(
        id: String,
        name: String,
        instructions: String,
        breathingTip: String? = nil,
        holdDuration: TimeInterval,
        targetJoints: [JointAngleRule] = []
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.breathingTip = breathingTip
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
        // Calibrado: P10–P90 110°–126° (conf ≥ 0.3, 2 vídeos)
        StretchDefinition(
            id: "cat-camel",
            name: "Cat Camel",
            instructions: """
            Start on your hands and knees with your back in a neutral position, \
            wrists directly under your shoulders and knees under your hips.

            Slowly arch your back — lift your head, open your chest and push your \
            tailbone out, letting your spine dip into a gentle curve (Cat position). \
            Hold for a moment.

            Then reverse the movement: tuck your chin to your chest, draw your belly \
            button in toward your spine and curl your tailbone under, rounding your \
            back toward the ceiling (Camel position). Hold, then repeat the cycle slowly.
            """,
            breathingTip: "Inhale as you arch into Cat, letting your belly drop. Exhale fully as you round into Camel, drawing your core in. Let your breath guide the pace — never rush the movement.",
            holdDuration: 5,
            targetJoints: [
                // rightShoulder → rightHip (vértice) → rightKnee
                JointAngleRule(
                    jointA: .rightShoulder,
                    jointB: .rightHip,
                    jointC: .rightKnee,
                    acceptableRange: 110.0...135.0,
                    mistakeHint: "Increase your range — the arc through your spine needs to be bigger."
                ),
            ]
        ),

        // ── 2. Bridge Pose ──────────────────────────────────────────────────────
        // Calibrado: P10–P90 38°–52° (fase de setup); hold estimado 80°–110°
        // TODO: validar ângulo de hold na PoseTestView
        StretchDefinition(
            id: "bridge-pose",
            name: "Bridge Pose",
            instructions: """
            Lie on your back with your knees bent and your feet flat on the floor, \
            hip-width apart. Let your arms rest alongside your body, palms facing down.

            Gently tilt your pelvis to imprint your lower back against the floor. \
            Pressing through your feet, slowly lift your hips until your shoulders, \
            hips and knees form a straight line. Squeeze your glutes at the top and \
            hold the position.

            To come down, keep your navel drawn in and lower your spine back to the \
            floor one vertebra at a time — from the upper back all the way down to \
            your tailbone. Release your glutes only once your pelvis rests on the floor.
            """,
            breathingTip: "Inhale to prepare. Exhale as you lift your hips, engaging your core and glutes. Breathe steadily at the top — avoid holding your breath. Inhale as you slowly lower back down.",
            holdDuration: 15,
            targetJoints: [
                // rightHip → rightKnee (vértice) → rightAnkle
                // TODO: validar na PoseTestView — exercício supino dificulta calibração por vídeo
                JointAngleRule(
                    jointA: .rightHip,
                    jointB: .rightKnee,
                    jointC: .rightAnkle,
                    acceptableRange: 80.0...110.0,
                    mistakeHint: "Adjust your foot position — your knee should be at roughly 90° to the floor."
                ),
            ]
        ),

        // ── 3. Seated Spinal Twist ──────────────────────────────────────────────
        // Calibrado: P10–P90 86°–127° (736/792 frames — excelente detecção)
        StretchDefinition(
            id: "seated-spinal-twist",
            name: "Seated Spinal Twist",
            instructions: """
            Sit upright on a chair or bench with both feet flat on the floor.

            Cross your right ankle over your left knee, letting your right foot rest \
            comfortably on the thigh. Sit tall, lengthening through the top of your head.

            Gently draw your right knee inward and toward the opposite shoulder while \
            keeping both sitting bones in contact with the seat — this subtle movement \
            deepens the rotation in the hip and lower back. \
            Place your left hand on the outside of your right knee for a gentle guide, \
            and rest your right hand behind you for support.

            Hold the twist, then repeat on the other side.
            """,
            breathingTip: "Inhale to sit taller and create space in your spine. Exhale to gently deepen the twist — never force the rotation. With each breath cycle, imagine growing an inch taller before rotating a little further.",
            holdDuration: 20,
            targetJoints: [
                // leftShoulder → rightShoulder (vértice) → rightHip
                JointAngleRule(
                    jointA: .leftShoulder,
                    jointB: .rightShoulder,
                    jointC: .rightHip,
                    acceptableRange: 80.0...130.0,
                    mistakeHint: "Rotate further — keep your hips stable and gently guide your shoulder away from your hip."
                ),
            ]
        ),

        // ── 4. Seated Piriformis Stretch ────────────────────────────────────────
        // Calibrado: P10–P90 65°–120° (211/319 frames)
        StretchDefinition(
            id: "piriformis-stretch",
            name: "Piriformis Stretch",
            instructions: """
            Start seated on a chair with both feet flat on the floor and your spine tall.

            Cross your right ankle over your left knee, so that your right ankle rests \
            on your left thigh — forming the shape of the number 4.

            Apply gentle downward pressure to your right knee with your right hand to \
            encourage the hip to open. Then, keeping your back straight, slowly hinge \
            forward at the hips until you feel a comfortable stretch deep in your right \
            glute and hip. Avoid rounding your lower back.

            Hold the position with a comfortable tension — you should feel a stretch, \
            not pain. Repeat on the other side.
            """,
            breathingTip: "Take a slow, deep inhale before leaning forward. As you exhale, gently fold deeper into the stretch — let the out-breath release tension. Keep breathing steadily throughout the hold; shallow breathing increases muscle guarding.",
            holdDuration: 30,
            targetJoints: [
                // rightKnee → rightHip (vértice) → leftKnee
                JointAngleRule(
                    jointA: .rightKnee,
                    jointB: .rightHip,
                    jointC: .leftKnee,
                    acceptableRange: 60.0...120.0,
                    mistakeHint: "Lean slightly forward from the hips — this deepens the piriformis stretch."
                ),
            ]
        ),

        // ── 5. Lumbar Rotation ──────────────────────────────────────────────────
        // Exercício supino com swiss ball — VNDetectHumanBodyPoseRequest não detecta
        // joints com confiança em posição horizontal (0/3 vídeos geraram dados).
        // Modo time-only: cronômetro inicia imediatamente, sem validação de ângulo.
        StretchDefinition(
            id: "lumbar-rotation",
            name: "Lumbar Rotation",
            instructions: """
            Lie on your back on the floor with your knees and hips bent, \
            placing your lower legs on top of an exercise ball.

            Keep your upper body relaxed and your arms resting out to the sides \
            for stability. Slowly roll the ball to the right, allowing your lower \
            back to rotate gently in that direction.

            Hold for 3 seconds, then roll the ball back through the center and \
            over to the left side. Repeat 10 times in each direction, moving \
            slowly and with control throughout.
            """,
            breathingTip: "Inhale to prepare at center. Exhale slowly as you roll the ball to one side, letting your lower back soften into the rotation. Inhale as you return to center. The breath helps your muscles release — never force the rotation.",
            holdDuration: 20,
            targetJoints: [] // Exercício supino — rastreio por tempo (sem ângulo)
        ),

    ]
}
