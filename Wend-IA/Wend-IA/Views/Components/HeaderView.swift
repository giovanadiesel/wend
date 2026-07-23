import SwiftUI

/// Componente de cabeçalho com saudação personalizada e ícone de sol.
public struct HeaderView: View {
    public var userName: String
    
    public init(userName: String = "Giovana") {
        self.userName = userName
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: WendSymbols.headerSun)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(WendTheme.Colors.greenDark)
                .accessibilityLabel("Ícone de sol")
            
            Text("Good Morning, \(userName)!")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(WendTheme.Colors.coffee)
            
            Text("Ready to take care of your back?")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HeaderView()
        .padding()
        .background(WendTheme.Colors.creamLight)
}
