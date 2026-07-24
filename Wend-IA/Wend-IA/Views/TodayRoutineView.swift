import SwiftData
import SwiftUI

// MARK: - TodayRoutineView

/// Sheet exibida quando o usuário toca no card "Morning Stretch" na HomeView.
///
/// Lista todos os exercícios da rotina de hoje com status de conclusão,
/// duração estimada e um chevron que navega para o `ExerciseDetailView` individual.
struct TodayRoutineView: View {

    // MARK: - Parâmetros

    let definitions: [StretchDefinition]
    let completedIDs: Set<String>

    /// Disparado quando o usuário confirma iniciar um exercício específico.
    var onStartExercise: (StretchDefinition) -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedDefinition: StretchDefinition?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                WendTheme.Colors.creamBasic.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header ─────────────────────────────────────────────
                        routineHeader
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 20)

                        // ── Lista de exercícios ────────────────────────────────
                        VStack(spacing: 0) {
                            ForEach(Array(definitions.enumerated()), id: \.element.id) { index, def in
                                routineRow(for: def, index: index)

                                if index < definitions.count - 1 {
                                    Divider()
                                        .background(WendTheme.Colors.coffee.opacity(0.08))
                                        .padding(.leading, 64)
                                }
                            }
                        }
                        .background(WendTheme.Colors.creamLight)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Morning Stretch")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                WendTheme.Colors.coffee.opacity(0.4),
                                WendTheme.Colors.coffee.opacity(0.08)
                            )
                    }
                }
            }
            .navigationDestination(item: $selectedDefinition) { def in
                ExerciseDetailView(
                    definition: def,
                    isCompleted: completedIDs.contains(def.id),
                    onStart: {
                        dismiss()
                        onStartExercise(def)
                    }
                )
            }
        }
    }

    // MARK: - Subviews

    private var routineHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(Color(hex: "#D4832A"))
                    .font(.system(size: 15, weight: .semibold))
                Text("Today's plan")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.55))
            }

            Text("\(completedIDs.intersection(definitions.map(\.id)).count) of \(definitions.count) done")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(WendTheme.Colors.greenBasic)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WendTheme.Colors.greenLight)
                        .frame(height: 6)
                    let ratio = definitions.isEmpty ? 0.0 :
                        Double(completedIDs.intersection(definitions.map(\.id)).count) / Double(definitions.count)
                    Capsule()
                        .fill(WendTheme.Colors.greenBasic)
                        .frame(width: geo.size.width * ratio, height: 6)
                        .animation(.easeOut(duration: 0.4), value: ratio)
                }
            }
            .frame(height: 6)
            .padding(.top, 4)
        }
    }

    private func routineRow(for def: StretchDefinition, index: Int) -> some View {
        let isDone = completedIDs.contains(def.id)

        return Button {
            selectedDefinition = def
        } label: {
            HStack(spacing: 16) {
                // Ícone de status
                ZStack {
                    Circle()
                        .fill(isDone ? WendTheme.Colors.greenLight : WendTheme.Colors.creamBasic)
                        .frame(width: 40, height: 40)
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isDone ? WendTheme.Colors.greenBasic : WendTheme.Colors.coffee.opacity(0.35))
                }

                // Título e detalhe
                VStack(alignment: .leading, spacing: 3) {
                    Text(def.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDone
                            ? WendTheme.Colors.coffee.opacity(0.45)
                            : WendTheme.Colors.coffee)
                        .strikethrough(isDone, color: WendTheme.Colors.coffee.opacity(0.3))

                    Text(holdLabel(for: def))
                        .font(.system(size: 13))
                        .foregroundColor(WendTheme.Colors.coffee.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private func holdLabel(for def: StretchDefinition) -> String {
        let secs = Int(def.holdDuration)
        let tracking = def.targetJoints.isEmpty ? "Timer" : "Tracking"
        if secs >= 60 {
            return "\(secs / 60) min · \(tracking)"
        } else {
            return "\(secs) sec hold · \(tracking)"
        }
    }
}

// MARK: - Preview

#Preview {
    TodayRoutineView(
        definitions: StretchDefinition.sampleStretches,
        completedIDs: ["cat-camel", "bridge-pose"],
        onStartExercise: { _ in }
    )
    .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
}
