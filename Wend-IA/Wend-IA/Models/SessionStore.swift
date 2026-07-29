import Foundation
import SwiftData

/// Calcula métricas de progresso do usuário derivadas dos `SessionRecord` persistidos.
///
/// Encapsula toda a lógica de negócio de datas para manter as views limpas.
/// Recebe o array de `SessionRecord` já carregado pelo `@Query` da view e expõe
/// propriedades derivadas computadas — sem estado próprio persistido.
struct SessionStore {

    // MARK: - Plano do dia

    /// Rotina personalizada do usuário para o dia — reutiliza `UserProfile.todaysRoutine()`
    /// para não duplicar a lógica de filtro por `selectedExerciseIDs`. `nil` (sem profile)
    /// retorna lista vazia, o que não deveria acontecer no fluxo normal do app.
    static func dailyPlan(for profile: UserProfile?) -> [StretchDefinition] {
        profile?.todaysRoutine() ?? []
    }

    // MARK: - Init

    private let records: [SessionRecord]
    private let calendar: Calendar
    private let today: Date

    init(records: [SessionRecord], calendar: Calendar = .current, today: Date = Date()) {
        self.records = records
        self.calendar = calendar
        self.today = today
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
}
