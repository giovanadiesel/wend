import SwiftData
import SwiftUI

// MARK: - Wrapper auxiliar para .sheet(item:)

/// Wrapper `Identifiable` sobre a tupla (record, definition) para uso no `.sheet(item:)`.
/// Necessário porque tuplas não conformam ao protocolo `Identifiable` diretamente.
private struct PendingSession: Identifiable {
    let id: PersistentIdentifier
    let record: SessionRecord
    let definition: StretchDefinition

    init(record: SessionRecord, definition: StretchDefinition) {
        self.id = record.persistentModelID
        self.record = record
        self.definition = definition
    }
}

/// Tela principal do Wend — dados derivados dos `SessionRecord` reais via SwiftData.
struct HomeView: View {

    // MARK: - SwiftData

    /// Todos os registros de sessão, usados para calcular streak e progresso real.
    @Query(sort: \SessionRecord.date, order: .reverse)
    private var allRecords: [SessionRecord]

    @Environment(\.modelContext) private var modelContext

    // MARK: - State Local

    @State private var selectedTab: WendTab = .exercise
    /// Serviço de dica diária — mantém a dica atual e aciona geração em background quando necessário.
    @State private var tipService = DailyTipService()
    // TODO: Remover antes do release
    @State private var showDebugCamera = false
    /// Sessão recém-concluída aguardando exibição do resumo. `nil` quando nenhuma.
    @State private var pendingSession: PendingSession?

    // MARK: - Dados Derivados (calculados a partir dos records reais)

    /// Ponto central de cálculo: streak, routineItems e próximo exercício.
    private var store: SessionStore { SessionStore(records: allRecords) }

    private var streak: UserStreak {
        UserStreak(
            streakDays: store.streakDays,
            goalsCompleted: store.goalsCompletedToday,
            totalGoals: store.totalGoalsToday
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            WendTheme.Colors.creamBasic
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

                    HeaderView(userName: "Giovana")
                        .padding(.top, 8)

                    StreakCardView(streak: streak)

                    // Featured card: próximo exercício não feito hoje (ou o primeiro se todos concluídos)
                    if let next = store.nextExercise {
                        FeaturedRoutineCardView(
                            title: next.name,
                            description: next.instructions
                                .components(separatedBy: .newlines)
                                .first?
                                .trimmingCharacters(in: .whitespaces) ?? next.instructions,
                            durationText: durationLabel(for: next),
                            onStart: {
                                // TODO: Navegar para a tela de sessão do exercício `next`
                                print("Iniciando: \(next.name)")
                            }
                        )
                    } else {
                        allDoneCard
                    }

                    // Lista da rotina com status real de completude
                    RoutineListView(
                        items: store.routineItems,
                        onItemToggle: { _ in
                            // Somente leitura neste contexto — a conclusão real
                            // ocorre via ExerciseSessionController ao salvar SessionRecord.
                        }
                    )

                    TipCardView(tip: TipItem(
                        title: "Tip of the day",
                        text: tipService.currentMessage
                    ))

                    // ── DEBUG: Remover antes do release ──────────────────
                    Button { showDebugCamera = true } label: {
                        Label("Debug: testar câmera", systemImage: "camera.metering.unknown")
                            .font(.caption)
                            .foregroundColor(WendTheme.Colors.coffee.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                    // ────────────────────────────────────────────────────
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }

            CustomTabBarView(selectedTab: $selectedTab)
                .padding(.bottom, 12)
        }
        .fullScreenCover(isPresented: $showDebugCamera) {
            PoseTestView()
        }
        .sheet(item: $pendingSession) { pending in
            SessionSummaryView(record: pending.record, definition: pending.definition)
        }
        // Dispara refresh da dica quando os records ou o streak mudam.
        // O service exibe a dica cacheada enquanto gera — transição silenciosa.
        .task(id: allRecords.count) {
            await tipService.refreshIfNeeded(
                context: modelContext,
                records: allRecords,
                streak: store.streakDays
            )
        }
    }

    // MARK: - Helpers de UI

    private func durationLabel(for stretch: StretchDefinition) -> String {
        let totalSeconds = stretch.holdDuration * 3 // 3 reps padrão
        let mins = Int(totalSeconds) / 60
        return mins > 0 ? "\(mins) min" : "\(Int(totalSeconds)) sec"
    }

    /// Card exibido quando todos os exercícios do dia foram concluídos.
    private var allDoneCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(WendTheme.Colors.greenBasic)
            Text("All done for today! 🎉")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)
            Text("Come back tomorrow for your next session.")
                .font(.caption)
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(WendTheme.Colors.greenLight)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Persistência de Sessão

    /// Salva um `SessionRecord` no ModelContext e aciona a exibição do resumo.
    ///
    /// Chamado pelo closure `onSessionFinished` do `ExerciseSessionController`.
    func saveSessionRecord(
        for stretch: StretchDefinition,
        holdDurationAchieved: TimeInterval,
        withinRangePercentage: Double
    ) {
        let record = SessionRecord(
            date: Date(),
            exerciseID: stretch.id,
            holdDurationAchieved: holdDurationAchieved,
            targetHoldDuration: stretch.holdDuration * 3,
            withinRangePercentage: withinRangePercentage
        )
        modelContext.insert(record)
        // Apresenta o resumo com feedback de IA imediatamente após salvar.
        pendingSession = PendingSession(record: record, definition: stretch)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
}
