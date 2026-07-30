import AppIntents
import SwiftData

/// App Intent disparável via Siri/Atalhos ("Iniciar alongamento no Wend").
///
/// Abre o app diretamente na `ExercisingView` do próximo exercício pendente
/// da rotina de hoje, pulando a Home — usa o mesmo `NavigationCoordinator`
/// que `HomeView` já observa (ver `Models/NavigationCoordinator.swift`).
struct StartStretchIntent: AppIntent {

    static var title: LocalizedStringResource = "Start Stretch"

    static var description = IntentDescription(
        "Starts the next exercise you haven't completed yet in today's stretching routine."
    )

    /// A execução real precisa da câmera em primeiro plano — o app tem que
    /// abrir, não dá pra rodar isso em segundo plano.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = Wend_IAApp.sharedModelContainer.mainContext

        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        let routine = profile?.todaysRoutine() ?? []

        guard !routine.isEmpty else {
            return .result()
        }

        let records = try context.fetch(FetchDescriptor<SessionRecord>())
        let store = SessionStore(records: records)

        // Se todos os exercícios de hoje já foram concluídos, cai de volta
        // pro primeiro da rotina em vez de falhar — permite repetir.
        let chosenExercise = store.nextExercise(in: routine) ?? routine.first

        NavigationCoordinator.shared.pendingExercise = chosenExercise

        return .result()
    }
}
