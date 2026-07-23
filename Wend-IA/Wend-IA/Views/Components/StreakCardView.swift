import SwiftUI

/// Card de progresso e ofensiva (Streak) com fundo Cream Light e detalhe gradiente radial Green Light desfocado.
public struct StreakCardView: View {
    public var streak: UserStreak
    
    public init(streak: UserStreak) {
        self.streak = streak
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak: \(streak.streakDays) days")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WendTheme.Colors.greenDark)
                    
                    Text("You're on the right track!")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(WendTheme.Colors.coffee.opacity(0.8))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today, \(formattedDate)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WendTheme.Colors.coffee)
                    
                    Text("\(streak.goalsCompleted) out of \(streak.totalGoals) goals")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WendTheme.Colors.greenBasic)
                }
            }
            
            Spacer()
            
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(
                        WendTheme.Colors.greenBasic.opacity(0.2),
                        lineWidth: 8
                    )
                
                Circle()
                    .trim(from: 0, to: streak.progressFraction)
                    .stroke(
                        WendTheme.Colors.greenBasic,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: streak.progressFraction)
                
                Text("\(Int(streak.progressFraction * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(WendTheme.Colors.coffee)
            }
            .frame(width: 68, height: 68)
        }
        .padding(20)
        .background(
            ZStack {
                // Base background Cream Light
                WendTheme.Colors.creamLight
                
                // Radial gradient Green Light 40% opacidade no canto superior direito com blur de 40
                GeometryReader { geo in
                    RadialGradient(
                        colors: [
                            WendTheme.Colors.greenLight.opacity(0.4),
                            Color.clear
                        ],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: geo.size.width * 0.7
                    )
                    .blur(radius: 40)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: streak.date)
    }
}

#Preview {
    StreakCardView(streak: UserStreak(streakDays: 5, goalsCompleted: 3, totalGoals: 4))
        .padding()
        .background(WendTheme.Colors.creamBasic)
}
