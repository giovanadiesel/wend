import SwiftUI

/// Card informativo "Tip of the day" com sugestões ergonômicas e comportamentais.
public struct TipCardView: View {
    public var tip: TipItem
    
    public init(tip: TipItem) {
        self.tip = tip
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(WendTheme.Colors.greenLight)
                    .frame(width: 38, height: 38)
                
                Image(systemName: tip.iconSymbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(WendTheme.Colors.greenBasic)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(tip.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WendTheme.Colors.coffee)
                
                Text(tip.text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.85))
                    .lineSpacing(3)
            }
            
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(WendTheme.Colors.creamDark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    TipCardView(tip: TipItem(
        title: "Tip of the day",
        text: "Remember to breathe deeply during exercises. Breathing helps to relax the muscles."
    ))
    .padding()
    .background(WendTheme.Colors.creamLight)
}
