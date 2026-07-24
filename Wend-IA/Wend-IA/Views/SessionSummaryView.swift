import SwiftData
import SwiftUI

/// Tela de resumo exibida ao fim de um exercício individual.
///
/// Mostra os dados objetivos da sessão e exibe feedback gerado por Apple Intelligence.
struct SessionSummaryView: View {

    // MARK: - Input

    let record: SessionRecord
    let definition: StretchDefinition

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
                        doneButton
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
                exerciseName: definition.name
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
                color: accuracyColor
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
                body: fb.whatWentWell
            )
            feedbackRow(
                icon: "lightbulb.fill",
                iconColor: Color(hex: "#C8882A"),
                title: "Tip to improve",
                body: fb.tipToImprove
            )
            feedbackRow(
                icon: "heart.fill",
                iconColor: Color(hex: "#A0522D"),
                title: "Encouragement",
                body: fb.encouragement
            )
        }
    }

    private func feedbackRow(icon: String, iconColor: Color, title: String, body: String) -> some View {
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
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.5))
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

    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Done")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(WendTheme.Colors.creamLight)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(WendTheme.Colors.greenDark)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var accuracyColor: Color {
        switch Int(record.withinRangePercentage) {
        case 80...: return WendTheme.Colors.greenBasic
        case 60...: return Color(hex: "#C8882A")
        default:    return Color(hex: "#B05030")
        }
    }

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
    return SessionSummaryView(record: record, definition: definition)
        .modelContainer(for: [SessionRecord.self, UserProfile.self], inMemory: true)
}
