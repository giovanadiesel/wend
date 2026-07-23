import SwiftUI

public enum WendTab: String, CaseIterable, Identifiable {
    case exercise = "Exercise"
    case progress = "Progress"
    case profile = "Profile"
    
    public var id: String { rawValue }
    
    public var iconSymbol: String {
        switch self {
        case .exercise: return WendSymbols.tabExercise
        case .progress: return WendSymbols.tabProgress
        case .profile: return WendSymbols.tabProfile
        }
    }
}

/// Floating Tab Bar com efeito Liquid Glass e tom Cream Basic.
public struct CustomTabBarView: View {
    @Binding public var selectedTab: WendTab
    
    public init(selectedTab: Binding<WendTab>) {
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(WendTab.allCases) { tab in
                let isSelected = selectedTab == tab
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconSymbol)
                            .font(.system(size: isSelected ? 22 : 20, weight: .bold))
                        
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundColor(isSelected ? WendTheme.Colors.greenDark : WendTheme.Colors.coffee.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Group {
                            if isSelected {
                                Capsule()
                                    .fill(WendTheme.Colors.greenLight)
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(6)
        .background(
            ZStack {
                // UltraThinMaterial para o efeito translúcido Liquid Glass
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Overlay de cor Cream Basic com transparência para manter o tom exato do Wend
                WendTheme.Colors.creamBasic
                    .opacity(0.75)
            }
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
        )
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        WendTheme.Colors.creamBasic.ignoresSafeArea()
        VStack {
            Spacer()
            CustomTabBarView(selectedTab: .constant(.exercise))
        }
    }
}
