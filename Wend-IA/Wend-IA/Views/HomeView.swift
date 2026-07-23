import SwiftUI

/// Tela Principal (HomeView) do aplicativo Wend com fundo Cream Basic e componentes ajustados.
public struct HomeView: View {
    @State private var streak = UserStreak(streakDays: 5, goalsCompleted: 3, totalGoals: 4)
    @State private var routineItems: [RoutineItem] = [
        RoutineItem(title: "Cat-Camel", detail: "3 min · Easy", isCompleted: true),
        RoutineItem(title: "Bridge Pose", detail: "15 repetitions · Easy", isCompleted: true),
        RoutineItem(title: "Spinal Mobility", detail: "15 repetitions · Easy", isCompleted: true),
        RoutineItem(title: "Piriformis Stretch", detail: "5 min · Moderate", isCompleted: false)
    ]
    @State private var tip = TipItem(
        title: "Tip of the day",
        text: "Remember to breathe deeply during exercises. Breathing helps to relax the muscles."
    )
    @State private var selectedTab: WendTab = .exercise
    // TODO: Remover antes do release
    @State private var showDebugCamera = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Fundo da Tela Principal em Cream Basic
            WendTheme.Colors.creamBasic
                .ignoresSafeArea()
            
            // Conteúdo Principal Rolável
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    // Header
                    HeaderView(userName: "Giovana")
                        .padding(.top, 8)
                    
                    // Streak Card (Fundo Cream Light + Gradiente Radial Verde Desfocado)
                    StreakCardView(streak: streak)
                    
                    // Featured Routine Card ("Morning Stretch")
                    FeaturedRoutineCardView(
                        title: "Morning Stretch",
                        description: "Wake up your body with gentle movements focused on the lower back.",
                        durationText: "10 min",
                        onStart: {
                            print("Iniciando rotina de alongamento lombar...")
                        }
                    )
                    
                    // Routine List Card (Fundo Cream Light)
                    RoutineListView(
                        items: routineItems,
                        onItemToggle: { item in
                            toggleRoutineItem(item)
                        }
                    )
                    
                    // Tip Card (Fundo Cream Dark)
                    TipCardView(tip: tip)

                    // ── DEBUG: Remover antes do release ─────────────────
                    Button {
                        showDebugCamera = true
                    } label: {
                        Label("Debug: testar câmera", systemImage: "camera.metering.unknown")
                            .font(.caption)
                            .foregroundColor(WendTheme.Colors.coffee.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                    // ────────────────────────────────────────────────────
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Espaço reservado para a TabBar Flutuante
            }
            
            // Custom Floating Tab Bar em Liquid Glass + Cream Basic
            CustomTabBarView(selectedTab: $selectedTab)
                .padding(.bottom, 12)
        }
        .fullScreenCover(isPresented: $showDebugCamera) {
            PoseTestView()
        }
    }
    
    private func toggleRoutineItem(_ item: RoutineItem) {
        withAnimation(.easeInOut) {
            item.isCompleted.toggle()
            let completedCount = routineItems.filter(\.isCompleted).count
            streak.goalsCompleted = completedCount
        }
    }
}

#Preview {
    HomeView()
}
