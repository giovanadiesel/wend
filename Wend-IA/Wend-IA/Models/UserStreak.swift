import Foundation
import Observation

/// Modelo de dados reativo com `@Observable` representando as métricas de streak e progresso do usuário.
@Observable
public final class UserStreak: Identifiable, @unchecked Sendable {
    public let id: UUID
    public var streakDays: Int
    public var goalsCompleted: Int
    public var totalGoals: Int
    public var date: Date
    
    public init(
        id: UUID = UUID(),
        streakDays: Int = 0,
        goalsCompleted: Int = 0,
        totalGoals: Int = 3,
        date: Date = Date()
    ) {
        self.id = id
        self.streakDays = streakDays
        self.goalsCompleted = goalsCompleted
        self.totalGoals = totalGoals
        self.date = date
    }
    
    /// Fração do progresso diário entre 0.0 e 1.0.
    public var progressFraction: Double {
        guard totalGoals > 0 else { return 0.0 }
        return min(max(Double(goalsCompleted) / Double(totalGoals), 0.0), 1.0)
    }
}
