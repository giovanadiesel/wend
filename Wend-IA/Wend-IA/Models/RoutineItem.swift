import Foundation
import Observation

/// Modelo de dados reativo com `@Observable` representando um item de rotina de alongamento.
@Observable
public final class RoutineItem: Identifiable, @unchecked Sendable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var isCompleted: Bool
    public var iconSymbol: String
    
    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        isCompleted: Bool = false,
        iconSymbol: String = WendSymbols.tabExercise
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isCompleted = isCompleted
        self.iconSymbol = iconSymbol
    }
}
