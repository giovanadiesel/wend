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

/// Tela principal do Wend — dados derivados dos `SessionRecord`/`UserProfile` reais via
/// SwiftData e do `RoutineManager` (hold/reps personalizados).
struct HomeView: View {

    // MARK: - SwiftData

    @Query(sort: \SessionRecord.date, order: .reverse)
    private var allRecords: [SessionRecord]

    @Query private var profiles: [UserProfile]

    @Environment(\.modelContext) private var modelContext

    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    // MARK: - Routine Manager

    @State private var routineManager = RoutineManager.shared

    // MARK: - State Local

    @State private var selectedTab: WendTab = .exercise
    @State private var tipService = DailyTipService()

    /// Sessão recém-concluída aguardando exibição do resumo.
    @State private var pendingSession: PendingSession?

    /// Exercício selecionado para iniciar no `ExercisingView`.
    @State private var exercisingDefinition: StretchDefinition?

    /// Controla se a sessão sendo iniciada é a rotina completa ou exercício individual.
    @State private var isRoutineSessionFlow = true

    /// Exercício selecionado para detalhe individual — abre `ExerciseDetailView`.
    @State private var selectedDetailDefinition: StretchDefinition?

    /// Controla exibição da sheet de adicionar exercício removido.
    @State private var showAddExerciseSheet = false

    // MARK: - Dados Derivados

    private var profile: UserProfile? { profiles.first }

    private var streak: UserStreak {
        let store = SessionStore(records: allRecords)
        return UserStreak(
            streakDays: store.streakDays,
            goalsCompleted: completedCountToday,
            totalGoals: activeStretches.count
        )
    }

    /// Rotina do usuário — `UserProfile.todaysRoutine()`, não mais a lista completa.
    private var activeStretches: [StretchDefinition] {
        profile?.todaysRoutine() ?? []
    }

    /// Exercícios do catálogo que o usuário não selecionou pra rotina — podem ser
    /// adicionados de volta via `addExerciseSheet`.
    private var unselectedStretches: [StretchDefinition] {
        let selected = Set(profile?.selectedExerciseIDs ?? [])
        return StretchDefinition.sampleStretches.filter { !selected.contains($0.id) }
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
        completedIDsToday.intersection(activeStretches.map(\.id)).count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                WendTheme.Colors.creamBasic
                    .ignoresSafeArea()

                Group {
                    switch selectedTab {
                    case .exercise:
                        exerciseTabContent
                    case .progress:
                        WendProgressView()
                    case .profile:
                        WendProfileView()
                    }
                }

                CustomTabBarView(selectedTab: $selectedTab)
                    .padding(.bottom, 12)
            }
            .sheet(item: $selectedDetailDefinition) { def in
                NavigationStack {
                    ExerciseDetailView(
                        definition: def,
                        isCompleted: completedIDsToday.contains(def.id),
                        onStart: {
                            selectedDetailDefinition = nil
                            startSingleExerciseSession(for: def)
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            DismissGlassButton {
                                selectedDetailDefinition = nil
                            }
                        }
                        .sharedBackgroundVisibility(.hidden)
                    }
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                addExerciseSheet
            }
            .sheet(item: $pendingSession) { pending in
                SessionSummaryView(record: pending.record, definition: pending.definition)
            }
            .task {
                ensureProfileExists()
            }
            .onChange(of: navigationCoordinator.pendingExercise) { _, newValue in
                guard let stretch = newValue else { return }
                isRoutineSessionFlow = false
                exercisingDefinition = stretch
                navigationCoordinator.pendingExercise = nil
            }
            .task(id: allRecords.count) {
                let store = SessionStore(records: allRecords)
                await tipService.refreshIfNeeded(
                    context: modelContext,
                    records: allRecords,
                    streak: store.streakDays,
                    profile: profile
                )
            }
            .navigationDestination(item: $exercisingDefinition) { def in
                ExercisingView(
                    definition: def,
                    stretches: activeStretches,
                    isRoutineFlow: isRoutineSessionFlow
                )
            }
        } // NavigationStack
    }

    // MARK: - Setup

    /// Faz o backfill único de `selectedExerciseIDs` pra perfis criados antes desse
    /// campo existir (ficariam com rotina vazia sem isso — não há como distinguir
    /// "nunca configurado" de "esvaziado de propósito" sem onboarding, então trata
    /// vazio como "não configurado ainda").
    ///
    /// Não cria `UserProfile` novo: `RootView` só mostra `HomeView` depois que o
    /// onboarding já criou e configurou o perfil (`hasCompletedOnboarding == true`),
    /// então `profiles.first` sempre existe aqui no fluxo normal.
    private func ensureProfileExists() {
        guard let existing = profiles.first else { return }
        if existing.selectedExerciseIDs.isEmpty {
            existing.selectedExerciseIDs = StretchDefinition.sampleStretches.map(\.id)
        }
    }

    // MARK: - Exercise Tab Content

    private var exerciseTabContent: some View {
        BlurTopScrollView {
            VStack(alignment: .leading, spacing: 22) {

                HeaderView(userName: (profile?.name).flatMap { $0.isEmpty ? nil : $0 } ?? "Friend")
                    .padding(.top, 8)

                StreakCardView(streak: streak)

                // Featured card: botão START inicia a rotina completa
                FeaturedRoutineCardView(
                    title: (profile?.painArea).flatMap { $0.isEmpty ? nil : $0 } ?? "Lower Back",
                    description: "Wake up your body with gentle movements focused on the lower back.",
                    durationText: totalDurationLabel,
                    onStart: {
                        startFullRoutineSession()
                    }
                )

                // Lista da rotina interativa (swipe para excluir/editar + botão +)
                routineListSection

                TipCardView(tip: TipItem(
                    title: "Tip of the day",
                    text: tipService.currentMessage
                ))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Routine List Section

    private var routineListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today's routine")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(WendTheme.Colors.coffee)

                Spacer()

                if !unselectedStretches.isEmpty {
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

            VStack(spacing: 0) {
                if activeStretches.isEmpty {
                    emptyRoutineView
                } else {
                    ForEach(Array(activeStretches.enumerated()), id: \.element.id) { index, def in
                        routineRow(for: def, index: index)

                        if index < activeStretches.count - 1 || !unselectedStretches.isEmpty {
                            Divider()
                                .background(WendTheme.Colors.coffee.opacity(0.1))
                                .padding(.leading, 40)
                        }
                    }
                }

                // Botão de adicionar exercício no rodapé da lista
                if !unselectedStretches.isEmpty {
                    addExerciseRowButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(WendTheme.Colors.creamLight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func routineRow(for def: StretchDefinition, index: Int) -> some View {
        let isDone = completedIDsToday.contains(def.id)
        let item = RoutineItem(
            title: def.name,
            detail: routineManager.detailText(for: def),
            isCompleted: isDone
        )

        return Button {
            selectedDetailDefinition = def
        } label: {
            RoutineRowView(item: item)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    profile?.deselectExercise(def.id)
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
            Text("No exercises in today's routine")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))

            Button("Restore default exercises") {
                withAnimation {
                    profile?.selectedExerciseIDs = StretchDefinition.sampleStretches.map(\.id)
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
                        ForEach(unselectedStretches) { def in
                            Button {
                                withAnimation {
                                    profile?.selectExercise(def.id)
                                }
                                if unselectedStretches.count <= 1 {
                                    showAddExerciseSheet = false
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(WendTheme.Colors.greenBasic)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(def.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(WendTheme.Colors.coffee)

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

    private func startFullRoutineSession() {
        guard let first = activeStretches.first else { return }
        isRoutineSessionFlow = true
        exercisingDefinition = first
    }

    private func startSingleExerciseSession(for stretch: StretchDefinition) {
        isRoutineSessionFlow = false
        exercisingDefinition = stretch
    }

    private var totalDurationLabel: String {
        let totalSecs = activeStretches.reduce(0.0) { sum, stretch in
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
