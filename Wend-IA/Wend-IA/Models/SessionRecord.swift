import Foundation
import SwiftData

/// Registro persistido de uma sessão de exercício realizada pelo usuário.
///
/// Armazenado via SwiftData e usado para calcular histórico, streaks e evoluções.
@Model
public final class SessionRecord {
    /// Data e hora em que a sessão foi realizada.
    public var date: Date
    /// Identificador do exercício executado (corresponde a `StretchDefinition.id`).
    public var exerciseID: String
    /// Tempo efetivamente mantido na posição correta (em segundos).
    public var holdDurationAchieved: TimeInterval
    /// Tempo alvo prescrito para o exercício (em segundos).
    public var targetHoldDuration: TimeInterval
    /// Percentual do tempo total em que o usuário permaneceu dentro do ângulo correto (0–100).
    public var withinRangePercentage: Double

    public init(
        date: Date = Date(),
        exerciseID: String,
        holdDurationAchieved: TimeInterval,
        targetHoldDuration: TimeInterval,
        withinRangePercentage: Double
    ) {
        self.date = date
        self.exerciseID = exerciseID
        self.holdDurationAchieved = holdDurationAchieved
        self.targetHoldDuration = targetHoldDuration
        self.withinRangePercentage = withinRangePercentage
    }

    /// `true` quando o usuário completou ao menos 80% do tempo alvo dentro do ângulo correto.
    public var isSuccess: Bool {
        holdDurationAchieved >= targetHoldDuration * 0.8 && withinRangePercentage >= 80
    }
}
