import SwiftUI

/// Componente de cabeçalho com saudação personalizada — texto e ícone mudam
/// conforme o horário do dia (manhã/tarde/noite/madrugada).
public struct HeaderView: View {
    public var userName: String

    public init(userName: String = "Giovana") {
        self.userName = userName
    }

    /// Saudação e SF Symbol correspondentes à hora atual do dispositivo.
    /// Manhã 5–11h, tarde 12–17h, noite 18–21h, madrugada 22–4h.
    private var greeting: (text: String, symbol: String) {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5...11: return ("Good Morning", WendSymbols.greetingMorning)
        case 12...17: return ("Good Afternoon", WendSymbols.greetingAfternoon)
        case 18...21: return ("Good Evening", WendSymbols.greetingEvening)
        default: return ("Good Night", WendSymbols.greetingNight)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: greeting.symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(WendTheme.Colors.greenDark)
                .accessibilityLabel("Ícone de saudação")

            Text("\(greeting.text), \(userName)!")
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
