import SwiftUI

/// Card da seção "Today's routine" contendo a lista de exercícios diários com fundo Cream Light.
public struct RoutineListView: View {
    public var items: [RoutineItem]
    public var onItemToggle: (RoutineItem) -> Void
    
    public init(
        items: [RoutineItem],
        onItemToggle: @escaping (RoutineItem) -> Void = { _ in }
    ) {
        self.items = items
        self.onItemToggle = onItemToggle
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's routine")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)
            
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    RoutineRowView(
                        item: item,
                        onToggle: { onItemToggle(item) }
                    )
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(WendTheme.Colors.coffee.opacity(0.1))
                            .padding(.leading, 40)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(WendTheme.Colors.creamLight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

#Preview {
    RoutineListView(items: [
        RoutineItem(title: "Cat-Camel", detail: "3 min · Easy", isCompleted: true),
        RoutineItem(title: "Bridge Pose", detail: "15 repetitions · Easy", isCompleted: true),
        RoutineItem(title: "Spinal Mobility", detail: "15 repetitions · Easy", isCompleted: true),
        RoutineItem(title: "Piriformis Stretch", detail: "5 min · Moderate", isCompleted: false)
    ])
    .padding()
    .background(WendTheme.Colors.creamBasic)
}
