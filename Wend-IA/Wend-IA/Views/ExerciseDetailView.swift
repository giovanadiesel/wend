import SwiftData
import SwiftUI

// MARK: - ExerciseDetailView

/// Tela de detalhe individual de um exercício, exibida ao tocar em uma row da rotina.
///
/// Mostra a descrição completa, dicas de respiração, ajuste de parâmetros (hold & reps)
/// e o botão para iniciar a sessão deste exercício individualmente.
struct ExerciseDetailView: View {

    // MARK: - Parâmetros

    let definition: StretchDefinition
    let isCompleted: Bool
    var onStart: () -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    @State private var routineManager = RoutineManager.shared

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            WendTheme.Colors.creamBasic.ignoresSafeArea()

            BlurTopScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Banner ─────────────────────────────────────────────────
                    bannerSection
                        .padding(.bottom, 24)

                    // ── Body content ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 24) {

                        // Sobre o exercício
                        sectionBlock(
                            icon: "figure.flexibility",
                            title: "About this exercise",
                            color: WendTheme.Colors.greenBasic
                        ) {
                            Text(definition.instructions)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(WendTheme.Colors.coffee.opacity(0.8))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Dica de respiração
                        if let tip = definition.breathingTip {
                            sectionBlock(
                                icon: "wind",
                                title: "Breathing tip",
                                color: Color(hex: "#4A8B6F")
                            ) {
                                Text(tip)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.8))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // Editar metas do exercício (botões - e + customizados para iOS físico)
                        customizationBlock

                        // Stats rápidos
                        statsRow

                        // Espaçamento para o botão fixo
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }

            // ── Botão fixo no fundo ────────────────────────────────────────────
            startButton
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .background(
                    LinearGradient(
                        colors: [WendTheme.Colors.creamBasic.opacity(0), WendTheme.Colors.creamBasic],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false),
                    alignment: .bottom
                )
        }
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WendTheme.Colors.creamBasic, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Customization Block

    private var customizationBlock: some View {
        sectionBlock(
            icon: "slider.horizontal.3",
            title: "Customized target",
            color: WendTheme.Colors.greenDark
        ) {
            VStack(spacing: 14) {
                // Hold Duration Stepper (- e +)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hold duration")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(WendTheme.Colors.coffee)
                        Text("\(Int(currentHoldDuration)) seconds per rep")
                            .font(.system(size: 12))
                            .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
                    }
                    Spacer()
                    customStepper(
                        value: Int(currentHoldDuration),
                        unit: "s",
                        range: 5...120,
                        step: 5
                    ) { newValue in
                        routineManager.updateHoldDuration(Double(newValue), for: definition.id)
                    }
                }

                Divider()

                // Repetitions Stepper (- e +)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target repetitions")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(WendTheme.Colors.coffee)
                        Text("\(currentReps) reps per session")
                            .font(.system(size: 12))
                            .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
                    }
                    Spacer()
                    customStepper(
                        value: currentReps,
                        unit: "×",
                        range: 1...10,
                        step: 1
                    ) { newValue in
                        routineManager.updateTargetReps(newValue, for: definition.id)
                    }
                }
            }
        }
    }

    // MARK: - Custom Stepper Control (- e +)

    private func customStepper(
        value: Int,
        unit: String,
        range: ClosedRange<Int>,
        step: Int = 1,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            // Botão Menos (-)
            Button {
                let newValue = max(range.lowerBound, value - step)
                if newValue != value {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onChange(newValue)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(value > range.lowerBound ? WendTheme.Colors.greenDark : WendTheme.Colors.coffee.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(value > range.lowerBound ? WendTheme.Colors.greenLight : WendTheme.Colors.creamBasic)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(value <= range.lowerBound)

            // Valor atual
            Text("\(value)\(unit)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)
                .frame(minWidth: 38, alignment: .center)

            // Botão Mais (+)
            Button {
                let newValue = min(range.upperBound, value + step)
                if newValue != value {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onChange(newValue)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(value < range.upperBound ? WendTheme.Colors.creamLight : WendTheme.Colors.coffee.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(value < range.upperBound ? WendTheme.Colors.greenDark : WendTheme.Colors.creamBasic)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(value >= range.upperBound)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(
                label: "Hold time",
                value: "\(Int(currentHoldDuration))s",
                icon: "clock.fill",
                color: WendTheme.Colors.greenBasic
            )
            statCell(
                label: "Tracking",
                value: definition.targetJoints.isEmpty ? "Timer" : "Camera",
                icon: definition.targetJoints.isEmpty ? "timer" : "camera.fill",
                color: WendTheme.Colors.greenBasic
            )
            statCell(
                label: "Reps",
                value: "\(currentReps)×",
                icon: "arrow.counterclockwise",
                color: WendTheme.Colors.greenBasic
            )
        }
    }

    private func statCell(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.5))
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(WendTheme.Colors.creamLight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: onStart) {
            HStack(spacing: 10) {
                Image(systemName: isCompleted ? "arrow.clockwise" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(isCompleted ? "Do it again" : "Start exercise")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(WendTheme.Colors.creamLight)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(WendTheme.Colors.greenDark)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Section Block Helper

    private func sectionBlock<Content: View>(
        icon: String,
        title: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WendTheme.Colors.coffee)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WendTheme.Colors.creamLight)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Computed Properties

    private var currentHoldDuration: Double {
        routineManager.holdDuration(for: definition)
    }

    private var currentReps: Int {
        routineManager.targetReps(for: definition)
    }

    private var holdLabel: String {
        let secs = Int(currentHoldDuration)
        return secs >= 60 ? "\(secs / 60) min" : "\(secs)s"
    }

    private var bannerColors: [Color] {
        switch definition.id {
        case "cat-camel":
            return [Color(hex: "#8CB4A0"), Color(hex: "#5A8A72")]
        case "bridge-pose":
            return [Color(hex: "#A0B4D4"), Color(hex: "#6A8AB4")]
        case "seated-spinal-twist":
            return [Color(hex: "#C4A882"), Color(hex: "#A07850")]
        case "piriformis-stretch":
            return [Color(hex: "#B4A0C4"), Color(hex: "#8A70A0")]
        case "lumbar-rotation":
            return [Color(hex: "#A0C4B4"), Color(hex: "#5A8A7A")]
        default:
            return [WendTheme.Colors.greenLight, WendTheme.Colors.greenBasic]
        }
    }

    /// Nome do arquivo (sem extensão) do vídeo demonstrativo em loop, se houver
    /// um para este exercício. `nil` cai no ícone/gradiente padrão do banner.
    private var demoVideoResourceName: String? {
        switch definition.id {
        case "cat-camel": return "cat-camel-demo"
        case "bridge-pose": return "bridge-pose-demo"
        case "seated-spinal-twist": return "seated-spinal-twist-demo"
        case "piriformis-stretch": return "piriformis-demo"
        case "lumbar-rotation": return "lumbar-rotation-demo"
        default: return nil
        }
    }

    private var bannerIcon: String {
        switch definition.id {
        case "cat-camel":          return "figure.flexibility"
        case "bridge-pose":        return "figure.yoga"
        case "seated-spinal-twist": return "figure.mind.and.body"
        case "piriformis-stretch": return "figure.seated.seatbelt"
        case "lumbar-rotation":    return "figure.roll"
        default:                   return "figure.flexibility"
        }
    }

    private var durationBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .semibold))
            Text(holdLabel)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(WendTheme.Colors.coffee)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(WendTheme.Colors.creamLight)
        .clipShape(Capsule())
    }

    private var completedBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Done today")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(WendTheme.Colors.greenBasic)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(WendTheme.Colors.greenLight)
        .clipShape(Capsule())
    }

    private var timerBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
            Text("Timer only")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(WendTheme.Colors.coffee.opacity(0.65))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(WendTheme.Colors.creamBasic)
        .clipShape(Capsule())
    }

    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let videoName = demoVideoResourceName {
                LoopingVideoView(resourceName: videoName, resourceExtension: "mp4")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                LinearGradient(
                    colors: bannerColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 200)

                Image(systemName: bannerIcon)
                    .font(.system(size: 72, weight: .thin))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                durationBadge
                if isCompleted { completedBadge }
                if definition.targetJoints.isEmpty { timerBadge }
            }
            .padding(16)
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(
            definition: StretchDefinition.sampleStretches[0],
            isCompleted: false,
            onStart: {}
        )
    }
    .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
}
