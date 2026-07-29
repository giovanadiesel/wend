import Foundation
import SwiftData

/// Perfil persistido do usuário, armazenado via SwiftData.
///
/// Contém preferências de acessibilidade, configuração de câmera e lembretes de rotina.
@Model
public final class UserProfile {
    /// Nome do usuário exibido na saudação da HomeView.
    public var name: String
    /// Região corporal com dor indicada pelo fisioterapeuta (ex: "Lombar", "Cervical").
    public var painArea: String
    /// Indica se o usuário está atualmente em tratamento fisioterapêutico.
    public var inTreatment: Bool
    /// Horários configurados para notificações de lembrete de alongamento.
    public var reminderTimes: [DateComponents]
    /// Habilita o uso da câmera para análise de postura em tempo real.
    public var cameraEnabled: Bool
    /// IDs de `StretchDefinition` (ver `StretchDefinition.sampleStretches`) que o
    /// usuário escolheu manter na rotina diária — fonte de verdade de `todaysRoutine()`.
    ///
    /// Default `= []` direto na declaração (não só no parâmetro do `init`) é
    /// obrigatório aqui: sem isso, a migração leve automática do SwiftData falha
    /// pra quem já tinha o app instalado antes deste campo existir (erro 134110,
    /// "missing attribute values on mandatory destination attribute").
    public var selectedExerciseIDs: [String] = []
    /// `true` depois que o usuário passa pelo fluxo de onboarding.
    /// O fluxo em si ainda não existe — este campo só guarda o estado.
    public var hasCompletedOnboarding: Bool = false

    public init(
        name: String,
        painArea: String = "Lombar",
        inTreatment: Bool = false,
        reminderTimes: [DateComponents] = [],
        cameraEnabled: Bool = true,
        selectedExerciseIDs: [String] = [],
        hasCompletedOnboarding: Bool = false
    ) {
        self.name = name
        self.painArea = painArea
        self.inTreatment = inTreatment
        self.reminderTimes = reminderTimes
        self.cameraEnabled = cameraEnabled
        self.selectedExerciseIDs = selectedExerciseIDs
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

// MARK: - Rotina Personalizada

extension UserProfile {
    /// Exercícios da rotina diária do usuário: `StretchDefinition.sampleStretches`
    /// filtrados por `selectedExerciseIDs`, na ordem do catálogo.
    public func todaysRoutine() -> [StretchDefinition] {
        StretchDefinition.sampleStretches.filter { selectedExerciseIDs.contains($0.id) }
    }

    /// Adiciona um exercício à rotina (sem efeito se já estiver selecionado).
    public func selectExercise(_ id: String) {
        guard !selectedExerciseIDs.contains(id) else { return }
        selectedExerciseIDs.append(id)
    }

    /// Remove um exercício da rotina (sem efeito se não estiver selecionado).
    public func deselectExercise(_ id: String) {
        selectedExerciseIDs.removeAll { $0 == id }
    }
}
