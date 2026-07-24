import Foundation
import Observation

/// Gerenciador de estado reativo para as configurações da rotina do usuário.
///
/// Persiste no `UserDefaults`:
/// - Exercícios excluídos/removidos da rotina de hoje.
/// - Tempo de hold personalizado por exercício.
/// - Número de repetições personalizadas por exercício.
@Observable
public final class RoutineManager: @unchecked Sendable {
    public static let shared = RoutineManager()

    // MARK: - AppStorage Keys

    private let excludedKey = "wend_excluded_exercise_ids"
    private let holdDurationsKey = "wend_custom_hold_durations"
    private let targetRepsKey = "wend_custom_target_reps"

    // MARK: - Published State

    public private(set) var excludedIDs: Set<String> = []
    public private(set) var customHoldDurations: [String: Double] = [:]
    public private(set) var customTargetReps: [String: Int] = [:]

    // MARK: - Init

    public init() {
        loadSettings()
    }

    // MARK: - Persistence Helpers

    private func loadSettings() {
        if let excludedArray = UserDefaults.standard.array(forKey: excludedKey) as? [String] {
            excludedIDs = Set(excludedArray)
        }
        if let holdsDict = UserDefaults.standard.dictionary(forKey: holdDurationsKey) as? [String: Double] {
            customHoldDurations = holdsDict
        }
        if let repsDict = UserDefaults.standard.dictionary(forKey: targetRepsKey) as? [String: Int] {
            customTargetReps = repsDict
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(Array(excludedIDs), forKey: excludedKey)
        UserDefaults.standard.set(customHoldDurations, forKey: holdDurationsKey)
        UserDefaults.standard.set(customTargetReps, forKey: targetRepsKey)
    }

    // MARK: - Queries

    /// Retorna todos os exercícios ativos do plano diário (ignorando excluídos).
    public var activeStretches: [StretchDefinition] {
        StretchDefinition.sampleStretches.filter { !excludedIDs.contains($0.id) }
    }

    /// Retorna os exercícios que foram removidos e podem ser adicionados novamente.
    public var removedStretches: [StretchDefinition] {
        StretchDefinition.sampleStretches.filter { excludedIDs.contains($0.id) }
    }

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

    public func excludeExercise(_ id: String) {
        excludedIDs.insert(id)
        saveSettings()
    }

    public func restoreExercise(_ id: String) {
        excludedIDs.remove(id)
        saveSettings()
    }

    public func resetToDefaults() {
        excludedIDs.removeAll()
        customHoldDurations.removeAll()
        customTargetReps.removeAll()
        saveSettings()
    }
}
