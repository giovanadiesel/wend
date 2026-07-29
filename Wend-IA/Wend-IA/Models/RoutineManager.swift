import Foundation
import Observation

/// Gerenciador de estado reativo para a customização de hold/reps por exercício.
///
/// Persiste no `UserDefaults`:
/// - Tempo de hold personalizado por exercício.
/// - Número de repetições personalizadas por exercício.
///
/// A seleção de quais exercícios compõem a rotina do usuário vive em
/// `UserProfile.selectedExerciseIDs` (SwiftData) — ver `UserProfile.todaysRoutine()`.
@Observable
public final class RoutineManager: @unchecked Sendable {
    public static let shared = RoutineManager()

    // MARK: - AppStorage Keys

    private let holdDurationsKey = "wend_custom_hold_durations"
    private let targetRepsKey = "wend_custom_target_reps"

    // MARK: - Published State

    public private(set) var customHoldDurations: [String: Double] = [:]
    public private(set) var customTargetReps: [String: Int] = [:]

    // MARK: - Init

    public init() {
        loadSettings()
    }

    // MARK: - Persistence Helpers

    private func loadSettings() {
        if let holdsDict = UserDefaults.standard.dictionary(forKey: holdDurationsKey) as? [String: Double] {
            customHoldDurations = holdsDict
        }
        if let repsDict = UserDefaults.standard.dictionary(forKey: targetRepsKey) as? [String: Int] {
            customTargetReps = repsDict
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(customHoldDurations, forKey: holdDurationsKey)
        UserDefaults.standard.set(customTargetReps, forKey: targetRepsKey)
    }

    // MARK: - Queries

    /// Duração do hold para o exercício (personalizada ou padrão da definição).
    public func holdDuration(for stretch: StretchDefinition) -> Double {
        customHoldDurations[stretch.id] ?? stretch.holdDuration
    }

    /// Número de repetições para o exercício (personalizado ou padrão 3).
    public func targetReps(for stretch: StretchDefinition) -> Int {
        customTargetReps[stretch.id] ?? 3
    }

    /// Texto de detalhe formatado para a row da rotina (ex: "3 reps · 15s hold").
    public func detailText(for stretch: StretchDefinition) -> String {
        let reps = targetReps(for: stretch)
        let holdSecs = Int(holdDuration(for: stretch))
        return "\(reps) reps · \(holdSecs)s hold"
    }

    // MARK: - Mutating Actions

    public func updateHoldDuration(_ duration: Double, for id: String) {
        customHoldDurations[id] = duration
        saveSettings()
    }

    public func updateTargetReps(_ reps: Int, for id: String) {
        customTargetReps[id] = reps
        saveSettings()
    }
}
