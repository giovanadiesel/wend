import SwiftUI

/// Linha individual da lista de rotinas com indicador de status e chevron.
public struct RoutineRowView: View {
    public var item: RoutineItem
    public var onToggle: () -> Void
    
    public init(item: RoutineItem, onToggle: @escaping () -> Void = {}) {
        self.item = item
        self.onToggle = onToggle
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? WendSymbols.exerciseCompleted : WendSymbols.exercisePending)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(item.isCompleted ? WendTheme.Colors.greenBasic : WendTheme.Colors.greenDark)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee)
                
                Text(item.detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: WendSymbols.chevronRight)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.3))
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    VStack {
        RoutineRowView(item: RoutineItem(title: "Cat-Camel", detail: "3 min · Easy", isCompleted: true))
        RoutineRowView(item: RoutineItem(title: "Piriformis Stretch", detail: "5 min · Moderate", isCompleted: false))
    }
    .padding()
    .background(WendTheme.Colors.creamBasic)
}
