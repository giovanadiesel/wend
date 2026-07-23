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
    /// Habilita feedback de áudio durante os exercícios.
    public var voiceFeedbackEnabled: Bool
    /// Habilita o uso da câmera para análise de postura em tempo real.
    public var cameraEnabled: Bool

    public init(
        name: String,
        painArea: String = "Lombar",
        inTreatment: Bool = false,
        reminderTimes: [DateComponents] = [],
        voiceFeedbackEnabled: Bool = true,
        cameraEnabled: Bool = true
    ) {
        self.name = name
        self.painArea = painArea
        self.inTreatment = inTreatment
        self.reminderTimes = reminderTimes
        self.voiceFeedbackEnabled = voiceFeedbackEnabled
        self.cameraEnabled = cameraEnabled
    }
}
