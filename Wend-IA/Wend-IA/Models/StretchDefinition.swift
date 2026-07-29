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
    /// Exercícios do plano diário.
    ///
    /// `minimumDeltaFromBaseline` é avaliado em relação à posição neutra do
    /// próprio usuário (calibrada no início de cada sessão — ver
    /// `ExerciseSessionController`), não a uma faixa de graus absoluta. Cat Camel,
    /// Seated Spinal Twist e Piriformis Stretch foram validados em dispositivo
    /// físico real em 2026-07-29 (ver comentários por exercício). Bridge Pose e
    /// Lumbar Rotation rodam em modo time-only — o Vision não detecta joints com
    /// confiança suficiente em poses supinas, então não há como validar ângulo.
    static let sampleStretches: [StretchDefinition] = [

        // ── 1. Cat Camel ────────────────────────────────────────────────────────
        // Validado em dispositivo físico em 2026-07-29 — precisão ~60%.
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
                    minimumDeltaFromBaseline: 15.0,
                    mistakeHint: "Increase your range — the arc through your spine needs to be bigger.",
                    movementLabel: "spine arch"
                ),
            ]
        ),

        // ── 2. Bridge Pose ──────────────────────────────────────────────────────
        // Pose supina — testado em dispositivo físico (2026-07-29): calibração só
        // conseguiu 3 amostras (mínimo é 5) e o joelho nunca mais foi detectado
        // com confiança depois disso, em nenhum momento da sessão. Mesmo padrão
        // documentado no Lumbar Rotation abaixo — o Vision estruturalmente não
        // detecta bem joints em posição horizontal. Modo time-only.
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
            targetJoints: [] // Exercício supino — rastreio por tempo (sem ângulo)
        ),

        // ── 3. Seated Spinal Twist ──────────────────────────────────────────────
        // Validado em dispositivo físico em 2026-07-29 — precisão ~40%,
        // variação real de até 54.7° (bem acima do limiar de 12°).
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
                // leftShoulder → rightShoulder (vértice) → nose
                // Trocado de rightHip em 2026-07-29 (perna cruzada ofusca o quadril).
                // Uma tentativa intermediária usou leftShoulder→neck(vértice)→rightShoulder,
                // mas pescoço e ombros ficam quase colineares — o ângulo fica travado em
                // ~180° porque giro encurta a linha, não muda o ângulo dela. A estrutura
                // original (vértice no ombro, terceiro ponto fora da linha dos ombros) é
                // que capturava a rotação de verdade — só trocamos o quadril (ofuscado)
                // pelo nariz (bem detectado e fora da linha).
                JointAngleRule(
                    jointA: .leftShoulder,
                    jointB: .rightShoulder,
                    jointC: .nose,
                    minimumDeltaFromBaseline: 12.0,
                    mistakeHint: "Rotate further — keep your hips stable and gently guide your shoulder away from your hip.",
                    movementLabel: "torso rotation"
                ),
            ]
        ),

        // ── 4. Seated Piriformis Stretch ────────────────────────────────────────
        // Validado em dispositivo físico em 2026-07-29 — precisão ~70%,
        // variação real de 30°-95° (câmera alta, angulada pra baixo, mostrando
        // quadril e joelhos por completo — recomendado nas instruções do app).
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
                    minimumDeltaFromBaseline: 20.0,
                    mistakeHint: "Lean slightly forward from the hips — this deepens the piriformis stretch.",
                    movementLabel: "hip and glute opening"
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

            Hold briefly, then roll the ball back through the center and over to \
            the left side. Repeat at your own pace in each direction, moving \
            slowly and with control throughout — your hold time and reps are set \
            in your routine, so adjust them anytime to match your comfort.
            """,
            breathingTip: "Inhale to prepare at center. Exhale slowly as you roll the ball to one side, letting your lower back soften into the rotation. Inhale as you return to center. The breath helps your muscles release — never force the rotation.",
            holdDuration: 20,
            targetJoints: [] // Exercício supino — rastreio por tempo (sem ângulo)
        ),

    ]
}
