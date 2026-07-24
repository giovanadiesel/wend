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
    /// Exercício selecionado para iniciar — aciona navegação para ExercisingView.
    @State private var exercisingDefinition: StretchDefinition?
    /// Controla a sheet da rotina completa do dia.
    @State private var showRoutineSheet = false
    /// Exercício selecionado para detalhe individual — abre ExerciseDetailView via sheet.
    @State private var selectedDetailDefinition: StretchDefinition?

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

    /// IDs dos exercícios concluídos hoje (para repassar às views de rotina).
    private var completedIDsToday: Set<String> {
        let calendar = Calendar.current
        return Set(
            allRecords
                .filter { calendar.isDateInToday($0.date) }
                .map { $0.exerciseID }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
        ZStack(alignment: .bottom) {
            WendTheme.Colors.creamBasic
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

                    HeaderView(userName: "Giovana")
                        .padding(.top, 8)

                    StreakCardView(streak: streak)

                    // Featured card: abre a rotina completa
                    FeaturedRoutineCardView(
                        title: "Morning Stretch",
                        description: "Wake up your body with gentle movements focused on the lower back.",
                        durationText: totalDurationLabel,
                        exerciseCount: StretchDefinition.sampleStretches.count,
                        onViewRoutine: {
                            showRoutineSheet = true
                        }
                    )

                    // Lista da rotina com status real de completude e navegação individual
                    routineListWithNavigation

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
        .sheet(isPresented: $showRoutineSheet) {
            TodayRoutineView(
                definitions: StretchDefinition.sampleStretches,
                completedIDs: completedIDsToday,
                onStartExercise: { def in
                    exercisingDefinition = def
                }
            )
        }
        .sheet(item: $selectedDetailDefinition) { def in
            NavigationStack {
                ExerciseDetailView(
                    definition: def,
                    isCompleted: completedIDsToday.contains(def.id),
                    onStart: {
                        selectedDetailDefinition = nil
                        exercisingDefinition = def
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            selectedDetailDefinition = nil
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
            }
        }
        .sheet(item: $pendingSession) { pending in
            SessionSummaryView(record: pending.record, definition: pending.definition)
        }
        // Dispara refresh da dica quando os records ou o streak mudam.
        .task(id: allRecords.count) {
            await tipService.refreshIfNeeded(
                context: modelContext,
                records: allRecords,
                streak: store.streakDays
            )
        }
        .navigationDestination(item: $exercisingDefinition) { def in
            ExercisingView(definition: def)
        }
        } // NavigationStack
    }

    // MARK: - Routine List with Per-Row Navigation

    /// Lista da rotina onde cada row abre o ExerciseDetailView individual.
    private var routineListWithNavigation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's routine")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)

            VStack(spacing: 0) {
                let items = store.routineItems
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    // Encontra a StretchDefinition correspondente pelo título
                    let def = StretchDefinition.sampleStretches.first { $0.name == item.title }

                    Button {
                        if let def { selectedDetailDefinition = def }
                    } label: {
                        RoutineRowView(item: item)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(def == nil)

                    if index < items.count - 1 {
                        Divider()
                            .background(WendTheme.Colors.coffee.opacity(0.1))
                            .padding(.leading, 40)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(WendTheme.Colors.creamLight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    // MARK: - Helpers de UI

    /// Duração total estimada da rotina (soma de holdDuration × 3 reps de cada exercício).
    private var totalDurationLabel: String {
        let totalSecs = StretchDefinition.sampleStretches.reduce(0.0) { $0 + $1.holdDuration * 3 }
        let mins = Int(totalSecs) / 60
        return mins > 0 ? "\(mins) min" : "\(Int(totalSecs)) sec"
    }

    // MARK: - Persistência de Sessão

    /// Salva um `SessionRecord` no ModelContext e aciona a exibição do resumo.
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
        pendingSession = PendingSession(record: record, definition: stretch)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
}


