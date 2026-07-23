import Foundation
import Observation

/// Modelo de dados reativo com `@Observable` representando uma dica diária de postura e saúde lombar.
@Observable
public final class TipItem: Identifiable, @unchecked Sendable {
    public let id: UUID
    public var title: String
    public var text: String
    public var iconSymbol: String
    
    public init(
        id: UUID = UUID(),
        title: String,
        text: String,
        iconSymbol: String = WendSymbols.tipOfTheDay
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.iconSymbol = iconSymbol
    }
}
