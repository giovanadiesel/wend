import Foundation
import SwiftData

/// Calcula métricas de progresso do usuário derivadas dos `SessionRecord` persistidos.
///
/// Encapsula toda a lógica de negócio de datas para manter as views limpas.
/// Recebe o array de `SessionRecord` já carregado pelo `@Query` da view e expõe
/// propriedades derivadas computadas — sem estado próprio persistido.
struct SessionStore {

    // MARK: - Plano fixo do dia

    /// Exercícios prescritos na rotina diária, sempre nesta ordem.
    /// Fonte de verdade: `StretchDefinition.sampleStretches`.
    static let dailyPlan: [StretchDefinition] = StretchDefinition.sampleStretches

    // MARK: - Init

    private let records: [SessionRecord]
    private let calendar: Calendar
    private let today: Date

    init(records: [SessionRecord], calendar: Calendar = .current, today: Date = Date()) {
        self.records = records
        self.calendar = calendar
        self.today = today
    }

    // MARK: - Exercícios Concluídos Hoje

    /// IDs dos exercícios com ao menos uma `SessionRecord` registrada hoje.
    var completedTodayIDs: Set<String> {
        let start = calendar.startOfDay(for: today)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return Set(
            records
                .filter { $0.date >= start && $0.date < end }
                .map(\.exerciseID)
        )
    }

    /// Exercícios do plano diário convertidos em `RoutineItem` com `isCompleted` real.
    var routineItems: [RoutineItem] {
        let done = completedTodayIDs
        return Self.dailyPlan.map { stretch in
            let detail = detailText(for: stretch)
            return RoutineItem(
                title: stretch.name,
                detail: detail,
                isCompleted: done.contains(stretch.id)
            )
        }
    }

    /// Quantidade de exercícios do plano já realizados hoje.
    var goalsCompletedToday: Int { completedTodayIDs.count }

    /// Quantidade total de exercícios no plano diário.
    var totalGoalsToday: Int { Self.dailyPlan.count }

    // MARK: - Próximo Exercício

    /// Primeiro exercício do plano que ainda não foi feito hoje.
    /// Retorna `nil` quando todos foram concluídos.
    var nextExercise: StretchDefinition? {
        let done = completedTodayIDs
        return Self.dailyPlan.first { !done.contains($0.id) }
    }

    // MARK: - Streak

    /// Número de dias consecutivos (incluindo hoje) com pelo menos uma sessão concluída.
    var streakDays: Int {
        guard !records.isEmpty else { return 0 }

        // Agrupa datas (normalizadas para início do dia) em que houve ao menos 1 sessão.
        let sessionDays: Set<Date> = Set(records.map { calendar.startOfDay(for: $0.date) })

        var streak = 0
        var cursor = calendar.startOfDay(for: today)

        // Conta para trás enquanto houver sessão em cada dia consecutivo.
        // Se hoje ainda não tem sessão, começa a contar a partir de ontem
        // para não quebrar streaks de dias anteriores.
        if !sessionDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        while sessionDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return streak
    }

    // MARK: - Helpers

    private func detailText(for stretch: StretchDefinition) -> String {
        let mins = Int(stretch.holdDuration * 3) / 60  // holdDuration × 3 reps
        let secs = Int(stretch.holdDuration * 3) % 60
        if mins > 0 {
            return "\(mins) min · Easy"
        } else {
            return "\(secs) sec · Easy"
        }
    }
}
