import SwiftData
import SwiftUI

/// Sheet de feedback do exercício exibida ao finalizar uma sessão.
///
/// Mostra as estatísticas objetivas da sessão e o feedback gerado por Apple Intelligence.
/// Contém botão "Next" (na rotina completa) ou "Done" (no último exercício/individual).
struct SessionSummaryView: View {

    // MARK: - Input

    let record: SessionRecord
    let definition: StretchDefinition
    /// Desempenho real por movimento durante a sessão — usado pra gerar
    /// feedback específico sobre corpo/ângulos. Vazio em exercícios time-only.
    let stats: [ExerciseSessionController.RuleFeedbackStat]
    let isRoutineFlow: Bool
    let isLastExercise: Bool
    let onNext: () -> Void
    let onDone: () -> Void

    // MARK: - Initializer

    init(
        record: SessionRecord,
        definition: StretchDefinition,
        stats: [ExerciseSessionController.RuleFeedbackStat] = [],
        isRoutineFlow: Bool = false,
        isLastExercise: Bool = true,
        onNext: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {}
    ) {
        self.record = record
        self.definition = definition
        self.stats = stats
        self.isRoutineFlow = isRoutineFlow
        self.isLastExercise = isLastExercise
        self.onNext = onNext
        self.onDone = onDone
    }

    // MARK: - State

    @State private var feedback: SessionFeedback?
    @State private var isGenerating = true
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                WendTheme.Colors.creamBasic.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        completionHeader
                        statsGrid
                        Divider()
                            .background(WendTheme.Colors.coffee.opacity(0.1))
                            .padding(.horizontal)
                        aiFeedbackSection
                        actionButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            isGenerating = true
            feedback = await CoachingService.generateFeedback(
                for: record,
                exerciseName: definition.name,
                stats: stats
            )
            isGenerating = false
        }
    }

    // MARK: - Subviews

    private var completionHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(WendTheme.Colors.greenLight)
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(WendTheme.Colors.greenBasic)
            }

            Text(definition.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)

            Text("Exercise complete")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCell(
                value: "\(Int(record.withinRangePercentage.rounded()))%",
                label: "Accuracy",
                icon: "scope",
                color: WendTheme.Colors.greenBasic
            )
            statCell(
                value: timeLabel(record.holdDurationAchieved),
                label: "Hold time",
                icon: "timer",
                color: WendTheme.Colors.greenBasic
            )
            statCell(
                value: timeLabel(record.targetHoldDuration),
                label: "Target",
                icon: "target",
                color: WendTheme.Colors.coffee.opacity(0.5)
            )
        }
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(WendTheme.Colors.coffee)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(WendTheme.Colors.creamLight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var aiFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.greenDark)
                Text("Exercise feedback")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee)
                Spacer()
                Text("Apple Intelligence")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.35))
            }

            if isGenerating {
                generatingIndicator
            } else if let fb = feedback {
                feedbackCards(fb)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.35), value: isGenerating)
    }

    private var generatingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(WendTheme.Colors.greenBasic)
            Text("Generating feedback...")
                .font(.system(size: 14))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(WendTheme.Colors.creamLight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func feedbackCards(_ fb: SessionFeedback) -> some View {
        VStack(spacing: 12) {
            feedbackRow(
                icon: "hand.thumbsup.fill",
                iconColor: WendTheme.Colors.greenBasic,
                title: "What went well",
                titleColor: WendTheme.Colors.greenBasic,
                body: fb.whatWentWell
            )
            feedbackRow(
                icon: "lightbulb.fill",
                iconColor: Color(hex: "#C8882A"),
                title: "Tip to improve",
                titleColor: Color(hex: "#C8882A"),
                body: fb.tipToImprove
            )
            feedbackRow(
                icon: "heart.fill",
                iconColor: Color(hex: "#A0522D"),
                title: "Encouragement",
                titleColor: Color(hex: "#A0522D"),
                body: fb.encouragement
            )
        }
    }

    private func feedbackRow(
        icon: String,
        iconColor: Color,
        title: String,
        titleColor: Color,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(titleColor)
                    .textCase(.uppercase)
                    .kerning(0.4)
                Text(body)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(WendTheme.Colors.coffee)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(WendTheme.Colors.creamLight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionButton: some View {
        Group {
            if isRoutineFlow && !isLastExercise {
                Button {
                    dismiss()
                    onNext()
                } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(WendTheme.Colors.creamLight)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(WendTheme.Colors.greenDark)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button {
                    dismiss()
                    onDone()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WendTheme.Colors.creamLight)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(WendTheme.Colors.greenDark)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func timeLabel(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return s >= 60 ? "\(s / 60)m\(s % 60 > 0 ? "\(s % 60)s" : "")" : "\(s)s"
    }
}

// MARK: - Preview

#Preview {
    let record = SessionRecord(
        date: Date(),
        exerciseID: "bridge-pose",
        holdDurationAchieved: 38,
        targetHoldDuration: 45,
        withinRangePercentage: 74
    )
    let definition = StretchDefinition.sampleStretches[1]
    return SessionSummaryView(
        record: record,
        definition: definition,
        isRoutineFlow: true,
        isLastExercise: false,
        onNext: {},
        onDone: {}
    )
    .modelContainer(for: [SessionRecord.self, UserProfile.self], inMemory: true)
}
