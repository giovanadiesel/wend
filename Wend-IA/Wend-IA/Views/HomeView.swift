import SwiftData
import SwiftUI

// MARK: - Wrapper auxiliar para .sheet(item:)

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

/// Tela principal do Wend — dados derivados dos `SessionRecord` reais via SwiftData e `RoutineManager`.
struct HomeView: View {

    // MARK: - SwiftData

    @Query(sort: \SessionRecord.date, order: .reverse)
    private var allRecords: [SessionRecord]

    @Environment(\.modelContext) private var modelContext

    // MARK: - Routine Manager

    @State private var routineManager = RoutineManager.shared

    // MARK: - State Local

    @State private var selectedTab: WendTab = .exercise
    @State private var tipService = DailyTipService()
    // TODO: Remover antes do release
    @State private var showDebugCamera = false

    /// Sessão recém-concluída aguardando exibição do resumo.
    @State private var pendingSession: PendingSession?

    /// Exercício selecionado para iniciar no `ExercisingView`.
    @State private var exercisingDefinition: StretchDefinition?

    /// Lista de exercícios da sessão a ser executada.
    @State private var sessionStretches: [StretchDefinition] = []

    /// Exercício selecionado para detalhe individual — abre `ExerciseDetailView`.
    @State private var selectedDetailDefinition: StretchDefinition?

    /// Controla exibição da sheet de adicionar exercício removido.
    @State private var showAddExerciseSheet = false

    /// Filtro selecionado para a lista da rotina (nil = All).
    @State private var selectedPeriodFilter: RoutineTimeOfDay? = nil

    // MARK: - Dados Derivados

    private var streak: UserStreak {
        let store = SessionStore(records: allRecords)
        return UserStreak(
            streakDays: store.streakDays,
            goalsCompleted: completedCountToday,
            totalGoals: activeStretches.count
        )
    }

    private var activeStretches: [StretchDefinition] {
        routineManager.activeStretches(for: selectedPeriodFilter)
    }

    private var completedIDsToday: Set<String> {
        let calendar = Calendar.current
        return Set(
            allRecords
                .filter { calendar.isDateInToday($0.date) }
                .map { $0.exerciseID }
        )
    }

    private var completedCountToday: Int {
        completedIDsToday.intersection(routineManager.activeStretches().map(\.id)).count
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

                        // Carrossel horizontal de cards de rotina (Morning Stretch, Night Unwind, etc.)
                        routineCardsCarousel

                        // Lista da rotina interativa com filtro e badges de período
                        routineListSection

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
            .sheet(item: $selectedDetailDefinition) { def in
                NavigationStack {
                    ExerciseDetailView(
                        definition: def,
                        isCompleted: completedIDsToday.contains(def.id),
                        onStart: {
                            selectedDetailDefinition = nil
                            startRoutineSession(for: [def])
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
            .sheet(isPresented: $showAddExerciseSheet) {
                addExerciseSheet
            }
            .sheet(item: $pendingSession) { pending in
                SessionSummaryView(record: pending.record, definition: pending.definition)
            }
            .task(id: allRecords.count) {
                let store = SessionStore(records: allRecords)
                await tipService.refreshIfNeeded(
                    context: modelContext,
                    records: allRecords,
                    streak: store.streakDays
                )
            }
            .navigationDestination(item: $exercisingDefinition) { def in
                ExercisingView(
                    definition: def,
                    stretches: sessionStretches.isEmpty ? routineManager.activeStretches() : sessionStretches
                )
            }
        } // NavigationStack
    }

    // MARK: - Routine Cards Carousel

    private var routineCardsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(routineManager.availableTimesOfDay) { period in
                    let periodStretches = routineManager.activeStretches(for: period)
                    FeaturedRoutineCardView(
                        title: period.cardTitle,
                        description: period.cardDescription,
                        durationText: durationLabel(for: periodStretches),
                        bannerImageName: period.bannerImageName,
                        timeOfDay: period,
                        onStart: {
                            startRoutineSession(for: periodStretches)
                        }
                    )
                    .frame(width: 320)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    // MARK: - Routine List Section

    private var routineListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today's routine")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(WendTheme.Colors.coffee)

                Spacer()

                if !routineManager.removedStretches.isEmpty {
                    Button {
                        showAddExerciseSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Add")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(WendTheme.Colors.greenBasic)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(WendTheme.Colors.greenLight)
                        .clipShape(Capsule())
                    }
                }
            }

            // Filtro por Período (All / Morning / Night)
            periodFilterBar

            VStack(spacing: 0) {
                if activeStretches.isEmpty {
                    emptyRoutineView
                } else {
                    ForEach(Array(activeStretches.enumerated()), id: \.element.id) { index, def in
                        routineRow(for: def, index: index)

                        if index < activeStretches.count - 1 || !routineManager.removedStretches.isEmpty {
                            Divider()
                                .background(WendTheme.Colors.coffee.opacity(0.1))
                                .padding(.leading, 40)
                        }
                    }
                }

                // Botão de adicionar exercício no rodapé da lista
                if !routineManager.removedStretches.isEmpty {
                    addExerciseRowButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(WendTheme.Colors.creamLight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var periodFilterBar: some View {
        HStack(spacing: 8) {
            filterChip(title: "All", tod: nil)
            ForEach(RoutineTimeOfDay.allCases) { tod in
                filterChip(title: tod.rawValue, tod: tod)
            }
        }
    }

    private func filterChip(title: String, tod: RoutineTimeOfDay?) -> some View {
        let isSelected = selectedPeriodFilter == tod
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPeriodFilter = tod
            }
        } label: {
            HStack(spacing: 4) {
                if let tod {
                    Image(systemName: tod.iconSymbol)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? WendTheme.Colors.creamLight : WendTheme.Colors.coffee.opacity(0.75))
            .background(isSelected ? WendTheme.Colors.greenDark : WendTheme.Colors.creamLight)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func routineRow(for def: StretchDefinition, index: Int) -> some View {
        let isDone = completedIDsToday.contains(def.id)
        let item = RoutineItem(
            title: def.name,
            detail: routineManager.detailText(for: def),
            isCompleted: isDone
        )
        let tod = routineManager.timeOfDay(for: def)

        return Button {
            selectedDetailDefinition = def
        } label: {
            RoutineRowView(item: item, timeOfDay: tod)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    routineManager.excludeExercise(def.id)
                }
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                selectedDetailDefinition = def
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            }
            .tint(WendTheme.Colors.greenBasic)
        }
    }

    private var addExerciseRowButton: some View {
        Button {
            showAddExerciseSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.greenBasic)

                Text("Add exercise back")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.greenDark)

                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var emptyRoutineView: some View {
        VStack(spacing: 8) {
            Text("No exercises in this view")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))

            Button("Restore default exercises") {
                withAnimation {
                    routineManager.resetToDefaults()
                }
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(WendTheme.Colors.greenBasic)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Add Exercise Sheet

    private var addExerciseSheet: some View {
        NavigationStack {
            ZStack {
                WendTheme.Colors.creamBasic.ignoresSafeArea()

                List {
                    Section {
                        ForEach(routineManager.removedStretches) { def in
                            let tod = routineManager.timeOfDay(for: def)
                            Button {
                                withAnimation {
                                    routineManager.restoreExercise(def.id)
                                }
                                if routineManager.removedStretches.isEmpty {
                                    showAddExerciseSheet = false
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(WendTheme.Colors.greenBasic)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(def.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(WendTheme.Colors.coffee)
                                            Image(systemName: tod.iconSymbol)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(tod == .morning ? Color(hex: "#D4832A") : Color(hex: "#6B5B95"))
                                        }

                                        Text(routineManager.detailText(for: def))
                                            .font(.system(size: 13))
                                            .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } footer: {
                        Text("Tap an exercise to add it back into your daily routine.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showAddExerciseSheet = false
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WendTheme.Colors.greenDark)
                }
            }
        }
    }

    // MARK: - Actions & Helpers

    private func startRoutineSession(for list: [StretchDefinition]) {
        guard let first = list.first else { return }
        sessionStretches = list
        exercisingDefinition = first
    }

    private func durationLabel(for list: [StretchDefinition]) -> String {
        let totalSecs = list.reduce(0.0) { sum, stretch in
            sum + routineManager.holdDuration(for: stretch) * Double(routineManager.targetReps(for: stretch))
        }
        let mins = Int(totalSecs) / 60
        return mins > 0 ? "\(mins) min" : "\(Int(totalSecs)) sec"
    }

    func saveSessionRecord(
        for stretch: StretchDefinition,
        holdDurationAchieved: TimeInterval,
        withinRangePercentage: Double
    ) {
        let customReps = routineManager.targetReps(for: stretch)
        let record = SessionRecord(
            date: Date(),
            exerciseID: stretch.id,
            holdDurationAchieved: holdDurationAchieved,
            targetHoldDuration: stretch.holdDuration * Double(customReps),
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
