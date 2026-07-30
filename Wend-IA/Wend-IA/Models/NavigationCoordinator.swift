import Combine
import Foundation

/// Coordenador de navegação compartilhado — permite que qualquer parte do app
/// (ex: uma notificação, um deep link, um widget) dispare a abertura de um
/// exercício específico na `ExercisingView` sem precisar de referência direta
/// à `HomeView`.
///
/// `HomeView` observa `pendingExercise` e reaproveita seu mecanismo de
/// navegação já existente (`navigationDestination(item: $exercisingDefinition)`)
/// assim que o valor deixa de ser `nil`.
public final class NavigationCoordinator: ObservableObject {
    public static let shared = NavigationCoordinator()

    @Published public var pendingExercise: StretchDefinition?

    public init() {}
}
