import Foundation

/// Struct representando a configuração estática de um exercício de alongamento.
///
/// Contém as instruções textuais e as regras angulares que serão usadas pelo módulo de
/// visão computacional para validar a postura do usuário em tempo real.
public struct StretchDefinition: Identifiable, Sendable {
    public let id: String
    /// Nome exibido ao usuário.
    public let name: String
    /// Passo a passo instrucional do exercício.
    public let instructions: String
    /// Tempo (em segundos) que o usuário deve manter a posição.
    public let holdDuration: TimeInterval
    /// Conjunto de regras de ângulo articular que definem a postura correta.
    public let targetJoints: [JointAngleRule]

    public init(
        id: String,
        name: String,
        instructions: String,
        holdDuration: TimeInterval,
        targetJoints: [JointAngleRule] = []
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.holdDuration = holdDuration
        self.targetJoints = targetJoints
    }
}
