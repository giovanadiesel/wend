import AVFoundation
import SwiftData
import SwiftUI
import Vision

// MARK: - ExercisingView

/// Tela de execução de exercício em tempo real.
///
/// Exibe o preview da câmera frontal em tela cheia com overlay de pose e
/// um card inferior flutuante. Ao concluir cada exercício, apresenta a sheet de feedback
/// (`SessionSummaryView`) contendo o botão "Next" (na rotina completa) ou "Done" (no último/individual).
struct ExercisingView: View {

    // MARK: - Parâmetros

    /// Lista de exercícios na rotina atual.
    let stretches: [StretchDefinition]
    /// Índice inicial do exercício a ser executado.
    let initialIndex: Int
    /// `true` se foi iniciado a partir da rotina completa (botão Start do card),
    /// `false` se foi iniciado para um exercício individual.
    let isRoutineFlow: Bool

    // MARK: - State Local

    @State private var currentIndex: Int
    @State private var routineManager = RoutineManager.shared

    /// Controle da sheet de feedback do exercício concluído.
    @State private var activeSummaryRecord: SessionRecord?
    @State private var showSummarySheet = false

    // MARK: - Initializer

    init(
        definition: StretchDefinition? = nil,
        stretches: [StretchDefinition]? = nil,
        initialIndex: Int = 0,
        isRoutineFlow: Bool = true
    ) {
        let list = stretches ?? RoutineManager.shared.activeStretches
        let activeList = list.isEmpty ? StretchDefinition.sampleStretches : list
        self.stretches = activeList
        self.isRoutineFlow = isRoutineFlow

        if let def = definition, let idx = activeList.firstIndex(where: { $0.id == def.id }) {
            self.initialIndex = idx
            self._currentIndex = State(initialValue: idx)
        } else {
            let clamped = max(0, min(initialIndex, activeList.count - 1))
            self.initialIndex = clamped
            self._currentIndex = State(initialValue: clamped)
        }
    }

    /// Exercício em execução no momento.
    private var currentDefinition: StretchDefinition {
        stretches[max(0, min(currentIndex, stretches.count - 1))]
    }

    // MARK: - SwiftData

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Pose Engine

    @StateObject private var camera  = CameraManager()
    @StateObject private var analyzer = PoseAnalyzer()

    // MARK: - Controlador de Sessão

    @State private var controller: ExerciseSessionController?

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // ── 1. Preview câmera ──────────────────────────────────────────
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()

                // ── 2. Overlay de pontos de pose ───────────────────────────────
                if let ctrl = controller {
                    PoseOverlayView(
                        joints: analyzer.detectedJoints,
                        evaluations: ctrl.evaluations,
                        rules: currentDefinition.targetJoints
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                // ── 3. Botão fechar (canto superior esquerdo) ──────────────────
                VStack {
                    HStack {
                        closeButton
                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top + 12)
                    .padding(.leading, 16)
                    Spacer()
                }
                .ignoresSafeArea()

                // ── 4. Card inferior flutuante ─────────────────────────────────
                if let ctrl = controller {
                    BottomSessionCard(
                        definition: currentDefinition,
                        controller: ctrl,
                        currentIndex: currentIndex,
                        totalCount: stretches.count,
                        isRoutineFlow: isRoutineFlow,
                        onFinishExercise: {
                            ctrl.finishEarly()
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                guard isRoutineFlow else { return }
                                if value.translation.width < -50 {
                                    advanceToNextExercise()
                                } else if value.translation.width > 50 {
                                    goToPreviousExercise()
                                }
                            }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .task {
            setupSession()
        }
        .onDisappear {
            camera.stop()
            analyzer.disconnect()
            controller?.stop()
        }
        .sheet(isPresented: $showSummarySheet) {
            if let record = activeSummaryRecord {
                SessionSummaryView(
                    record: record,
                    definition: currentDefinition,
                    isRoutineFlow: isRoutineFlow,
                    isLastExercise: currentIndex == stretches.count - 1,
                    onNext: {
                        advanceToNextExercise()
                    },
                    onDone: {
                        finishAndReturnHome()
                    }
                )
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Setup & Navigation

    private func setupSession() {
        controller?.stop()

        let customHold = routineManager.holdDuration(for: currentDefinition)
        let customReps = routineManager.targetReps(for: currentDefinition)

        let effectiveDefinition = StretchDefinition(
            id: currentDefinition.id,
            name: currentDefinition.name,
            instructions: currentDefinition.instructions,
            breathingTip: currentDefinition.breathingTip,
            holdDuration: customHold,
            targetJoints: currentDefinition.targetJoints
        )

        let ctrl = ExerciseSessionController(
            definition: effectiveDefinition,
            analyzer: analyzer,
            targetRepetitions: customReps,
            onSessionFinished: { achieved, accuracy in
                let record = saveRecord(definition: effectiveDefinition, achieved: achieved, accuracy: accuracy)
                activeSummaryRecord = record
                showSummarySheet = true
            }
        )
        controller = ctrl

        camera.requestAuthorization()
        analyzer.connect(to: camera)
        camera.start()
        ctrl.start()
    }

    private func advanceToNextExercise() {
        showSummarySheet = false
        if currentIndex < stretches.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
            setupSession()
        } else {
            finishAndReturnHome()
        }
    }

    private func goToPreviousExercise() {
        showSummarySheet = false
        if currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex -= 1
            }
            setupSession()
        }
    }

    private func finishAndReturnHome() {
        showSummarySheet = false
        camera.stop()
        analyzer.disconnect()
        controller?.stop()
        dismiss()
    }

    @discardableResult
    private func saveRecord(definition: StretchDefinition, achieved: TimeInterval, accuracy: Double) -> SessionRecord {
        let customReps = routineManager.targetReps(for: definition)
        let record = SessionRecord(
            date: Date(),
            exerciseID: definition.id,
            holdDurationAchieved: achieved,
            targetHoldDuration: definition.holdDuration * Double(customReps),
            withinRangePercentage: accuracy
        )
        modelContext.insert(record)
        return record
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            camera.stop()
            analyzer.disconnect()
            controller?.stop()
            dismiss()
        } label: {
            ZStack {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    WendTheme.Colors.creamBasic.opacity(0.75)
                }
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )

                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(WendTheme.Colors.coffee)
            }
            .frame(width: 44, height: 44)
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Pose Overlay View

private struct PoseOverlayView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    let evaluations: [ExerciseSessionController.RuleEvaluation?]
    let rules: [JointAngleRule]

    private var allInRange: Bool {
        evaluations.allSatisfy { $0?.isWithinRange == true }
    }

    var body: some View {
        Canvas { context, size in
            drawConnections(context: context, size: size)
            drawJoints(context: context, size: size)
        }
    }

    private func drawConnections(context: GraphicsContext, size: CGSize) {
        for rule in rules {
            guard
                let ptA = joints[rule.jointA],
                let ptB = joints[rule.jointB],
                let ptC = joints[rule.jointC]
            else { continue }

            let a = screenPoint(from: ptA.location, in: size)
            let b = screenPoint(from: ptB.location, in: size)
            let c = screenPoint(from: ptC.location, in: size)

            let lineColor = Color.white.opacity(0.8)
            let lineWidth: CGFloat = 2

            drawDashedLine(context: context, from: a, to: b, color: lineColor, lineWidth: lineWidth)
            drawDashedLine(context: context, from: b, to: c, color: lineColor, lineWidth: lineWidth)
        }
    }

    private func drawDashedLine(
        context: GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        color: Color,
        lineWidth: CGFloat
    ) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, dash: [6, 5])
        )
    }

    private func drawJoints(context: GraphicsContext, size: CGSize) {
        let ruleJoints: Set<VNHumanBodyPoseObservation.JointName> = Set(
            rules.flatMap { [$0.jointA, $0.jointB, $0.jointC] }
        )

        for (name, point) in joints {
            let pos = screenPoint(from: point.location, in: size)
            let isKeyJoint = ruleJoints.contains(name)

            let outerDiameter: CGFloat = isKeyJoint ? 18 : 10
            let innerDiameter: CGFloat = isKeyJoint ? 10 : 6

            let outerColor: Color = isKeyJoint
                ? (allInRange ? WendTheme.Colors.greenBasic : .white)
                : .white.opacity(0.5)
            let innerColor: Color = isKeyJoint
                ? (allInRange ? WendTheme.Colors.greenLight : .white)
                : .white.opacity(0.3)

            let outerRect = CGRect(
                x: pos.x - outerDiameter / 2,
                y: pos.y - outerDiameter / 2,
                width: outerDiameter,
                height: outerDiameter
            )
            context.fill(Path(ellipseIn: outerRect), with: .color(outerColor.opacity(0.4)))

            let innerRect = CGRect(
                x: pos.x - innerDiameter / 2,
                y: pos.y - innerDiameter / 2,
                width: innerDiameter,
                height: innerDiameter
            )
            context.fill(Path(ellipseIn: innerRect), with: .color(innerColor))
        }
    }

    private func screenPoint(
        from normalized: CGPoint,
        in size: CGSize
    ) -> CGPoint {
        CGPoint(
            x: (1.0 - normalized.x) * size.width,
            y: (1.0 - normalized.y) * size.height
        )
    }
}

// MARK: - Bottom Session Card

private struct BottomSessionCard: View {

    let definition: StretchDefinition
    @ObservedObject var controller: ExerciseSessionController
    let currentIndex: Int
    let totalCount: Int
    let isRoutineFlow: Bool
    let onFinishExercise: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Indicador pequeno "1 of 5" (se rotina completa) ──────────────────
            if isRoutineFlow {
                HStack {
                    Text("\(currentIndex + 1) of \(totalCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(WendTheme.Colors.creamLight)
                        .clipShape(Capsule())

                    Spacer()
                }
                .padding(.bottom, 6)
            }

            // ── Cabeçalho: Nome + badge Tracking ──────────────────────────────
            HStack(alignment: .top) {
                Text(definition.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(WendTheme.Colors.coffee)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                trackingBadge
            }
            .padding(.bottom, 8)

            // ── Linha de feedback em tempo real ───────────────────────────────
            Text(feedbackText)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.3), value: feedbackText)
                .padding(.bottom, 14)

            // ── Grade de estatísticas ─────────────────────────────────────────
            HStack(spacing: 12) {
                statCard(
                    label: "DURATION",
                    value: durationLabel,
                    color: WendTheme.Colors.greenBasic
                )
                statCard(
                    label: "PRECISION",
                    value: controller.phase == .calibratingBaseline
                        ? "—"
                        : "\(Int(controller.withinRangePercentage.rounded()))%",
                    color: WendTheme.Colors.greenBasic
                )
            }
            .padding(.bottom, 16)

            // ── Botão verde "Finish Exercise" ──────────────────────────────────
            Button(action: onFinishExercise) {
                Label("Finish Exercise", systemImage: "checkmark.circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WendTheme.Colors.creamLight)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(WendTheme.Colors.greenDark)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(hex: "#FFF4F0").opacity(0.95))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
        )
    }

    // MARK: - Tracking Badge

    private var trackingBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "record.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WendTheme.Colors.greenBasic)
            Text("Tracking")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WendTheme.Colors.greenBasic)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(WendTheme.Colors.creamLight)
        .clipShape(Capsule())
    }

    // MARK: - Stat Card

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.45))
                .kerning(0.8)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.15), value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(WendTheme.Colors.creamLight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Computed Strings

    private var feedbackText: String {
        let isTimeOnly = definition.targetJoints.isEmpty
        if isTimeOnly {
            switch controller.phase {
            case .holdingPosition:
                let pct = Int(controller.holdProgress * 100)
                return pct < 50
                    ? "Hold the position and breathe slowly."
                    : "Almost there — keep holding!"
            default:
                return "Hold the position and breathe slowly."
            }
        }

        switch controller.phase {
        case .calibratingBaseline:
            return "Get into your starting position and hold still — calibrating…"
        case .waitingForPosition:
            return "Position yourself in front of the camera."
        case .holdingPosition:
            let pct = Int(controller.holdProgress * 100)
            return pct < 50
                ? "Great posture! Keep your breath rhythm."
                : "Hold it — almost there!"
        case .outOfPosition:
            if let hintRule = definition.targetJoints.first(where: { rule in
                let idx = definition.targetJoints.firstIndex(where: { $0.jointB == rule.jointB }) ?? 0
                return controller.evaluations.indices.contains(idx)
                    && controller.evaluations[idx]?.isWithinRange == false
            }) {
                return hintRule.mistakeHint
            }
            return "Adjust your position to continue."
        case .sessionFinished:
            return "Exercise complete!"
        }
    }

    private var durationLabel: String {
        let total = Int(controller.sessionElapsedTime)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExercisingView(definition: StretchDefinition.sampleStretches[0])
            .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
    }
}
