import Foundation
import SwiftData

/// Cache persistido da dica diária gerada por Apple Intelligence.
///
/// Armazena exatamente uma instância (upsert manual).
/// O `DailyTipService` verifica `generatedAt` ao iniciar para decidir se
/// reutiliza a mensagem existente ou dispara uma nova geração.
@Model
final class DailyTipCache {
    /// Texto da dica exibida ao usuário.
    var message: String
    /// Momento em que a dica foi gerada ou atualizada pela última vez.
    var generatedAt: Date

    init(message: String, generatedAt: Date = Date()) {
        self.message = message
        self.generatedAt = generatedAt
    }

    /// `true` quando a dica foi gerada no dia de hoje (mesmo dia calendário).
    var isFreshForToday: Bool {
        Calendar.current.isDateInToday(generatedAt)
    }
}
