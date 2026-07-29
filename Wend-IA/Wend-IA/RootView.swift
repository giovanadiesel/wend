import SwiftData
import SwiftUI

/// Ponto de decisão do app: mostra `OnboardingView` até
/// `UserProfile.hasCompletedOnboarding` virar `true`, depois vai direto
/// para `HomeView`. Sem perfil ainda (primeira execução), também mostra
/// o onboarding.
struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if profiles.first?.hasCompletedOnboarding == true {
            HomeView()
        } else {
            OnboardingView()
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
}
