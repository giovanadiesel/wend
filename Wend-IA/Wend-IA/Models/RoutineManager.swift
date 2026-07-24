import Foundation
import Observation

/// Período do dia para a rotina de alongamento.
public enum RoutineTimeOfDay: String, CaseIterable, Identifiable, Codable, Sendable {
    case morning = "Morning"
    case night = "Night"

    public var id: String { rawValue }

    public var iconSymbol: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .night: return "moon.stars.fill"
        }
    }

    public var cardTitle: String {
        switch self {
        case .morning: return "Morning Stretch"
        case .night: return "Night Unwind"
        }
    }

    public var cardDescription: String {
        switch self {
        case .morning: return "Wake up your body with gentle movements focused on the lower back."
        case .night: return "Decompress your spine and relax your muscles for a peaceful night's rest."
        }
    }

    public var bannerImageName: String {
        switch self {
        case .morning: return "morning_stretch_banner"
        case .night: return "night_stretch_banner"
        }
    }
}

/// Gerenciador de estado reativo para as configurações da rotina do usuário.
///
/// Persiste no `UserDefaults`:
/// - Exercícios excluídos/removidos da rotina de hoje.
/// - Tempo de hold personalizado por exercício.
/// - Número de repetições personalizadas por exercício.
/// - Período do dia (Morning / Night) atribuído a cada exercício.
@Observable
public final class RoutineManager: @unchecked Sendable {
    public static let shared = RoutineManager()

    // MARK: - AppStorage Keys

    private let excludedKey = "wend_excluded_exercise_ids"
    private let holdDurationsKey = "wend_custom_hold_durations"
    private let targetRepsKey = "wend_custom_target_reps"
    private let timeOfDayKey = "wend_custom_time_of_day"

    // MARK: - Published State

    public private(set) var excludedIDs: Set<String> = []
    public private(set) var customHoldDurations: [String: Double] = [:]
    public private(set) var customTargetReps: [String: Int] = [:]
    public private(set) var customTimeOfDay: [String: RoutineTimeOfDay] = [:]

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
        if let timeDict = UserDefaults.standard.dictionary(forKey: timeOfDayKey) as? [String: String] {
            var parsed: [String: RoutineTimeOfDay] = [:]
            for (k, v) in timeDict {
                if let tod = RoutineTimeOfDay(rawValue: v) {
                    parsed[k] = tod
                }
            }
            customTimeOfDay = parsed
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(Array(excludedIDs), forKey: excludedKey)
        UserDefaults.standard.set(customHoldDurations, forKey: holdDurationsKey)
        UserDefaults.standard.set(customTargetReps, forKey: targetRepsKey)

        let timeDict = customTimeOfDay.mapValues { $0.rawValue }
        UserDefaults.standard.set(timeDict, forKey: timeOfDayKey)
    }

    // MARK: - Queries

    /// Retorna todos os exercícios ativos do plano diário, opcionalmente filtrados por período do dia.
    public func activeStretches(for timeOfDay: RoutineTimeOfDay? = nil) -> [StretchDefinition] {
        let active = StretchDefinition.sampleStretches.filter { !excludedIDs.contains($0.id) }
        guard let tod = timeOfDay else { return active }
        return active.filter { self.timeOfDay(for: $0) == tod }
    }

    /// Retorna os exercícios que foram removidos e podem ser adicionados novamente.
    public var removedStretches: [StretchDefinition] {
        StretchDefinition.sampleStretches.filter { excludedIDs.contains($0.id) }
    }

    /// Período do dia atribuído ao exercício (padrão: Morning para 1-3, Night para 4-5).
    public func timeOfDay(for stretch: StretchDefinition) -> RoutineTimeOfDay {
        if let custom = customTimeOfDay[stretch.id] {
            return custom
        }
        // Atribuição inicial padrão se o usuário ainda não personalizou
        switch stretch.id {
        case "piriformis-stretch", "lumbar-rotation":
            return .night
        default:
            return .morning
        }
    }

    /// Períodos do dia que possuem ao menos 1 exercício ativo.
    public var availableTimesOfDay: [RoutineTimeOfDay] {
        let times = RoutineTimeOfDay.allCases.filter { tod in
            !activeStretches(for: tod).isEmpty
        }
        return times.isEmpty ? [.morning] : times
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

    public func updateTimeOfDay(_ time: RoutineTimeOfDay, for id: String) {
        customTimeOfDay[id] = time
        saveSettings()
    }

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
        customTimeOfDay.removeAll()
        saveSettings()
    }
}
