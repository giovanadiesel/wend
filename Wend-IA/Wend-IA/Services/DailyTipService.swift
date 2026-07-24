import Foundation
import FoundationModels
import SwiftData

// MARK: - Structured Output

/// Saída estruturada gerada pelo modelo de linguagem local (Apple Intelligence).
@Generable
private struct DailyTip {
    @Guide(description: "A helpful, encouraging tip in 1-2 short sentences. No clinical language. Warm and friendly tone.")
    var message: String
}

// MARK: - Performance Summary

/// Resumo do desempenho recente do usuário, usado como contexto no prompt.
fileprivate struct PerformanceSummary {
    let streakDays: Int
    let averagePrecision: Double      // 0–100, média dos últimos 7 dias
    let completedTodayCount: Int
    let totalTodayCount: Int
    let weakestExercise: String?      // Nome do exercício com pior precisão média

    var completedAllToday: Bool { completedTodayCount >= totalTodayCount }

    /// Representação em texto para inclusão no prompt.
    func asPromptContext() -> String {
        var lines: [String] = [
            "Current streak: \(streakDays) day\(streakDays == 1 ? "" : "s")",
            "Average posture accuracy (last 7 days): \(Int(averagePrecision.rounded()))%",
            "Today's progress: \(completedTodayCount) of \(totalTodayCount) exercises completed",
        ]
        if let weak = weakestExercise {
            lines.append("Exercise needing most attention: \(weak)")
        }
        if completedAllToday {
            lines.append("Status: All exercises for today are done!")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Service

/// Serviço responsável por gerar e cachear a "Tip of the day" personalizada.
///
/// ### Ciclo de vida
/// - A dica é gerada **uma vez por dia** usando Apple Intelligence.
/// - Enquanto o modelo gera, a dica anterior permanece visível (transição silenciosa).
/// - Se Apple Intelligence não estiver disponível, uma dica de fallback é escolhida
///   aleatoriamente de uma lista fixa, variando de acordo com o desempenho.
///
/// ### Uso em HomeView
/// ```swift
/// @State private var tipService = DailyTipService()
///
/// .task {
///     await tipService.refreshIfNeeded(context: modelContext, records: allRecords, streak: store.streakDays)
/// }
///
/// TipCardView(tip: TipItem(title: "Tip of the day", text: tipService.currentMessage))
/// ```
@Observable
final class DailyTipService {

    // MARK: - Estado Publicado

    /// Mensagem atual exibida no card. Começa com uma dica de fallback genérica
    /// até o cache ser carregado ou a geração terminar.
    private(set) var currentMessage: String = DailyTipService.generalFallbacks.randomElement() ?? "Take a deep breath before starting — it helps your body ease into the movement."

    // MARK: - Internals

    private var isGenerating = false

    // MARK: - API Pública

    /// Verifica se a dica precisa ser atualizada e, se sim, gera em background.
    ///
    /// Deve ser chamada em um `.task` da HomeView a cada vez que os dados mudam.
    /// É segura para chamar múltiplas vezes — garante que apenas uma geração ocorre.
    ///
    /// - Parameters:
    ///   - context: O `ModelContext` ativo da view para leitura/escrita do `DailyTipCache`.
    ///   - records: Array de `SessionRecord` já carregado pelo `@Query` da HomeView.
    ///   - streak: Streak atual calculado pelo `SessionStore`.
    func refreshIfNeeded(
        context: ModelContext,
        records: [SessionRecord],
        streak: Int
    ) async {
        // ── 1. Carrega o cache existente ─────────────────────────────────────
        let cached = fetchCache(from: context)

        // Sempre inicializa currentMessage com o valor cacheado (para exibição imediata)
        if let cached {
            currentMessage = cached.message
        }

        // ── 2. Decide se precisa gerar ────────────────────────────────────────
        guard !isGenerating else { return }        // já está gerando
        guard cached == nil || !cached!.isFreshForToday else { return }  // cache de hoje: ok

        // ── 3. Gera em background (sem bloquear a UI) ─────────────────────────
        isGenerating = true
        defer { isGenerating = false }

        let summary = buildSummary(records: records, streak: streak)
        let newMessage = await generate(summary: summary)

        // ── 4. Persiste e publica ─────────────────────────────────────────────
        upsertCache(context: context, existing: cached, message: newMessage)
        currentMessage = newMessage
    }

    // MARK: - Busca no Cache

    private func fetchCache(from context: ModelContext) -> DailyTipCache? {
        let descriptor = FetchDescriptor<DailyTipCache>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    private func upsertCache(context: ModelContext, existing: DailyTipCache?, message: String) {
        if let existing {
            // Atualiza em lugar de inserir novo — mantém exatamente 1 registro
            existing.message = message
            existing.generatedAt = Date()
        } else {
            context.insert(DailyTipCache(message: message))
        }
    }

    // MARK: - Montagem do Resumo de Desempenho

    private func buildSummary(records: [SessionRecord], streak: Int) -> PerformanceSummary {
        let calendar = Calendar.current
        let today = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        let recentRecords = records.filter { $0.date >= sevenDaysAgo }

        // Precisão média global dos últimos 7 dias
        let avgPrecision: Double
        if recentRecords.isEmpty {
            avgPrecision = 0
        } else {
            avgPrecision = recentRecords.map(\.withinRangePercentage).reduce(0, +) / Double(recentRecords.count)
        }

        // Exercícios concluídos hoje
        let todayRecords = recentRecords.filter { calendar.isDateInToday($0.date) }
        let completedTodayIDs = Set(todayRecords.map(\.exerciseID))
        let plan = SessionStore.dailyPlan

        // Exercício com pior precisão média nos últimos 7 dias (excluindo os de hoje)
        let weakest = weakestExerciseName(from: recentRecords, plan: plan)

        return PerformanceSummary(
            streakDays: streak,
            averagePrecision: avgPrecision,
            completedTodayCount: completedTodayIDs.count,
            totalTodayCount: plan.count,
            weakestExercise: weakest
        )
    }

    /// Retorna o nome do exercício com menor precisão média nos últimos 7 dias.
    private func weakestExerciseName(
        from records: [SessionRecord],
        plan: [StretchDefinition]
    ) -> String? {
        // Agrupa por exercício e calcula média de precisão
        var precisionByID: [String: [Double]] = [:]
        for record in records {
            precisionByID[record.exerciseID, default: []].append(record.withinRangePercentage)
        }

        guard precisionByID.count >= 2 else { return nil } // sem comparação com menos de 2 exercícios

        let averages = precisionByID.mapValues { values in
            values.reduce(0, +) / Double(values.count)
        }

        // Exercício com menor média
        guard let worstID = averages.min(by: { $0.value < $1.value })?.key,
              let definition = plan.first(where: { $0.id == worstID }),
              let bestAvg = averages.values.max(),
              let worstAvg = averages[worstID],
              (bestAvg - worstAvg) > 10 // só reporta se a diferença for significativa (>10 pp)
        else { return nil }

        return definition.name
    }

    // MARK: - Geração com Foundation Models

    private func generate(summary: PerformanceSummary) async -> String {
        // ── Verificação de disponibilidade ───────────────────────────────────
        guard case .available = SystemLanguageModel.default.availability else {
            return Self.randomFallback(summary: summary)
        }

        // ── Prompt ───────────────────────────────────────────────────────────
        let prompt = buildPrompt(summary: summary)

        // ── Geração ──────────────────────────────────────────────────────────
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: DailyTip.self)
            return response.content.message
        } catch {
            return Self.randomFallback(summary: summary)
        }
    }

    private func buildPrompt(summary: PerformanceSummary) -> String {
        """
        You are a friendly wellness coach helping someone recover from lower back pain through daily stretching.
        Write a short "Tip of the day" message for this user based on their recent performance data.

        STRICT RULES:
        - Write in English
        - Maximum 2 short sentences (under 30 words total)
        - Tone: warm, encouraging, like a supportive friend — never clinical, never scolding
        - If streak is strong: reinforce consistency
        - If streak is 0 or low: encourage without guilt
        - If a specific exercise has low accuracy: give a concrete, gentle tip about it
        - If all exercises done today: celebrate briefly
        - Never mention "you should" or "you must" — phrase as "try" or "notice" or "remember"

        USER'S RECENT PERFORMANCE:
        \(summary.asPromptContext())
        """
    }

    // MARK: - Fallbacks Estáticos

    /// Seleciona uma dica de fallback com base no contexto de desempenho disponível.
    fileprivate static func randomFallback(summary: PerformanceSummary?) -> String {
        guard let summary else {
            return generalFallbacks.randomElement() ?? generalFallbacks[0]
        }

        switch (summary.streakDays, summary.averagePrecision, summary.completedAllToday) {
        case (_, _, true):
            return allDoneFallbacks.randomElement() ?? allDoneFallbacks[0]
        case (let s, _, _) where s >= 5:
            return streakFallbacks.randomElement() ?? streakFallbacks[0]
        case (0, _, _):
            return encourageFallbacks.randomElement() ?? encourageFallbacks[0]
        default:
            return generalFallbacks.randomElement() ?? generalFallbacks[0]
        }
    }

    private static let generalFallbacks = [
        "Take a deep breath before starting — it helps your body ease into the movement.",
        "Consistency matters more than perfection. Showing up is the biggest win.",
        "Even 5 minutes of stretching makes a difference. Every session counts.",
        "Listen to your body and move at your own pace. There's no rush.",
    ]

    private static let streakFallbacks = [
        "You're on a great streak! Consistency is building real progress for your back.",
        "Days like these add up — your spine is thanking you for each session.",
        "Keeping it up is the hardest part, and you're doing it. Well done!",
    ]

    private static let encourageFallbacks = [
        "Every day is a fresh start. Even a short session today will help.",
        "No pressure — just a gentle reminder that your back feels better when you move.",
        "Starting again is always an option. Your body is ready when you are.",
    ]

    private static let allDoneFallbacks = [
        "All done for today! Rest and let the stretches do their work.",
        "You completed everything today — that's something worth celebrating. 🎉",
        "Great job finishing your routine! Hydrate and enjoy the rest of your day.",
    ]
}
