import Foundation
import FoundationModels

// MARK: - Structured Output

/// Feedback estruturado gerado pelo modelo de linguagem local (Apple Intelligence).
///
/// A conformance ao protocolo `Generable` é sintetizada pelo macro `@Generable`,
/// que permite ao `LanguageModelSession` preencher os campos diretamente
/// a partir da resposta do modelo sem parsing manual de JSON/texto.
@Generable
struct SessionFeedback {
    /// Algo específico que a pessoa fez bem nessa sessão.
    @Guide(description: "Uma frase curta descrevendo algo concreto que a pessoa fez bem — ex: constância, tempo mantido, esforço. Não genérico.")
    var whatWentWell: String

    /// Dica prática e direta para melhorar na próxima sessão.
    @Guide(description: "Uma dica única, curta e acionável para a próxima vez — foco em postura, respiração ou frequência. Sem jargão clínico.")
    var tipToImprove: String

    /// Frase motivacional breve e acolhedora.
    @Guide(description: "Uma frase motivacional de até 12 palavras, calorosa e humana, sem exagero. Ex: 'Cada sessão te aproxima de uma costas mais forte.'")
    var encouragement: String
}

// MARK: - Service

/// Serviço de coaching baseado em Apple Intelligence (Foundation Models framework).
///
/// - Verifica disponibilidade do modelo antes de tentar gerar.
/// - Retorna `SessionFeedback` de fallback quando o modelo não está disponível
///   (dispositivo não compatível, Apple Intelligence desativada, modelo baixando).
/// - Toda a geração ocorre on-device, sem enviar dados para servidores externos.
struct CoachingService {

    // MARK: - API Pública

    /// Gera feedback personalizado para uma sessão de exercício concluída.
    ///
    /// - Parameters:
    ///   - record: `SessionRecord` recém-salvo com os dados da sessão.
    ///   - exerciseName: Nome legível do exercício (ex: "Bridge Pose").
    /// - Returns: `SessionFeedback` com três campos preenchidos pelo modelo,
    ///   ou valores de fallback caso Apple Intelligence esteja indisponível.
    static func generateFeedback(
        for record: SessionRecord,
        exerciseName: String
    ) async -> SessionFeedback {
        // ── 1. Verifica disponibilidade ──────────────────────────────────────
        guard case .available = SystemLanguageModel.default.availability else {
            return fallback(for: record)
        }

        // ── 2. Monta prompt contextualizado ──────────────────────────────────
        let prompt = buildPrompt(for: record, exerciseName: exerciseName)

        // ── 3. Gera feedback estruturado ─────────────────────────────────────
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: SessionFeedback.self)
            return response.content
        } catch {
            return fallback(for: record)
        }
    }

    // MARK: - Helpers Privados

    private static func buildPrompt(for record: SessionRecord, exerciseName: String) -> String {
        let precision = Int(record.withinRangePercentage.rounded())
        let achieved  = Int(record.holdDurationAchieved.rounded())
        let target    = Int(record.targetHoldDuration.rounded())
        let quality   = qualityLabel(precision: precision, achieved: achieved, target: target)

        return """
        Você é um assistente de bem-estar físico, especializado em reabilitação lombar.
        Analise a sessão de alongamento abaixo e forneça feedback personalizado.

        REGRAS OBRIGATÓRIAS:
        - Responda SEMPRE em português do Brasil
        - Tom: acolhedor, positivo e não-clínico — como um amigo que entende de fisioterapia
        - Frases curtas (máx. 25 palavras por campo)
        - Nunca use termos médicos técnicos

        DADOS DA SESSÃO:
        Exercício: \(exerciseName)
        Precisão de postura: \(precision)%
        Tempo mantido na posição: \(achieved)s de \(target)s esperados
        Qualidade geral: \(quality)
        """
    }

    /// Rótulo de qualidade legível para o modelo usar como contexto.
    private static func qualityLabel(precision: Int, achieved: Int, target: Int) -> String {
        let holdRatio = target > 0 ? Double(achieved) / Double(target) : 0
        switch (precision, holdRatio) {
        case (80..., 0.9...):
            return "Excelente — postura mantida com alta precisão durante quase todo o tempo"
        case (60..., 0.7...):
            return "Boa — precisão razoável, pequenas quedas de postura"
        case (40..., 0.5...):
            return "Regular — dificuldade em manter o ângulo correto por períodos maiores"
        default:
            return "Iniciante — sessão desafiadora, mas o esforço é o que conta"
        }
    }

    /// Feedback estático de fallback quando Apple Intelligence não está disponível.
    private static func fallback(for record: SessionRecord) -> SessionFeedback {
        let precision = Int(record.withinRangePercentage.rounded())

        let whatWentWell: String
        let tipToImprove: String

        switch precision {
        case 80...:
            whatWentWell = "Você manteve a posição com ótima precisão durante toda a sessão!"
            tipToImprove = "Tente aumentar o tempo de hold em 5 segundos na próxima vez."
        case 60...:
            whatWentWell = "Você completou todas as repetições — isso exige consistência!"
            tipToImprove = "Foque em respirar devagar para ajudar a manter a posição mais tempo."
        default:
            whatWentWell = "Você foi até o fim mesmo quando estava difícil — isso é o mais importante."
            tipToImprove = "Comece com movimentos menores e vá aumentando a amplitude aos poucos."
        }

        return SessionFeedback(
            whatWentWell: whatWentWell,
            tipToImprove: tipToImprove,
            encouragement: "Sessão concluída! Cada dia é um passo na direção certa. 💪"
        )
    }
}
