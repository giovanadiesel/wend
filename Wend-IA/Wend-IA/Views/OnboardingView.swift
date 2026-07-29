import AVFoundation
import SwiftData
import SwiftUI

/// Fluxo de onboarding em 5 passos — mostrado uma única vez, até
/// `UserProfile.hasCompletedOnboarding` virar `true` (ver `RootView`).
struct OnboardingView: View {

    // MARK: - SwiftData

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var currentStep = 0
    @State private var name = ""
    @State private var inTreatment = true
    @State private var focusArea = "Lower Back"
    @State private var selectedExerciseIDs: Set<String> = Set(StretchDefinition.sampleStretches.map(\.id))

    private let totalSteps = 5

    // MARK: - Body

    var body: some View {
        ZStack {
            WendTheme.Colors.creamBasic.ignoresSafeArea()

            VStack(spacing: 0) {
                progressIndicator
                    .padding(.top, 20)
                    .padding(.horizontal, 32)

                Spacer(minLength: 12)

                stepContent
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))

                Spacer(minLength: 12)

                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: purposeStep
        case 1: physioRoleStep
        case 2: personalDataStep
        case 3: exerciseSelectionStep
        default: cameraPermissionStep
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? WendTheme.Colors.greenBasic : WendTheme.Colors.coffee.opacity(0.12))
                    .frame(height: 5)
            }
        }
    }

    // MARK: - Step 1 — Purpose

    private var purposeStep: some View {
        stepLayout(
            icon: "figure.flexibility",
            title: "Your journey to a healthier spine starts here",
            body: "Wend guides you through gentle, camera-tracked stretches designed to relieve lower back tension — a few minutes a day, right from your phone."
        )
    }

    // MARK: - Step 2 — Physiotherapist's Role

    private var physioRoleStep: some View {
        stepLayout(
            icon: "cross.case.fill",
            title: "Wend is complementary — it doesn't replace treatment",
            body: "If you're working with a physical therapist, keep following their guidance. Wend is here to support the exercises they prescribe, not to diagnose or treat any condition."
        )
    }

    // MARK: - Step 3 — Personal Data

    private var personalDataStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tell us about you")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(WendTheme.Colors.coffee)
                Text("We'll use this to personalize your experience.")
                    .font(.system(size: 14))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Your name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
                TextField("Name", text: $name)
                    .font(.system(size: 16, weight: .medium))
                    .padding(14)
                    .background(WendTheme.Colors.creamLight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .textInputAutocapitalization(.words)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Where are you in your treatment?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))

                statusButton(
                    title: "In active treatment",
                    subtitle: "Currently working with a physical therapist",
                    isSelected: inTreatment
                ) {
                    inTreatment = true
                }
                statusButton(
                    title: "Maintenance",
                    subtitle: "Keeping up with exercises on my own",
                    isSelected: !inTreatment
                ) {
                    inTreatment = false
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Focus area (optional)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
                TextField("Focus area", text: $focusArea)
                    .font(.system(size: 16, weight: .medium))
                    .padding(14)
                    .background(WendTheme.Colors.creamLight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 24)
    }

    private func statusButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(isSelected ? WendTheme.Colors.greenBasic : WendTheme.Colors.coffee.opacity(0.25))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(WendTheme.Colors.coffee)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(WendTheme.Colors.coffee.opacity(0.55))
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? WendTheme.Colors.greenLight : WendTheme.Colors.creamLight)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? WendTheme.Colors.greenBasic.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Step 4 — Exercise Selection

    private var exerciseSelectionStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Build your routine")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(WendTheme.Colors.coffee)
                Text("All exercises are selected by default — tap to remove any you don't need.")
                    .font(.system(size: 14))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.6))
                Text("You're in control of the pace: hold time for each exercise can be adjusted anytime to match your comfort.")
                    .font(.system(size: 13))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.5))
            }
            .padding(.horizontal, 24)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(StretchDefinition.sampleStretches) { stretch in
                        exerciseCard(for: stretch)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    private func exerciseCard(for stretch: StretchDefinition) -> some View {
        let isSelected = selectedExerciseIDs.contains(stretch.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedExerciseIDs.remove(stretch.id)
                } else {
                    selectedExerciseIDs.insert(stretch.id)
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(isSelected ? WendTheme.Colors.greenBasic : WendTheme.Colors.coffee.opacity(0.25))

                VStack(alignment: .leading, spacing: 2) {
                    Text(stretch.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isSelected ? WendTheme.Colors.coffee : WendTheme.Colors.coffee.opacity(0.4))
                    Text("\(Int(stretch.holdDuration))s hold")
                        .font(.system(size: 12))
                        .foregroundColor(WendTheme.Colors.coffee.opacity(0.45))
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? WendTheme.Colors.greenLight : WendTheme.Colors.creamLight)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Step 5 — Camera Permission

    private var cameraPermissionStep: some View {
        stepLayout(
            icon: "lock.shield.fill",
            title: "Your safety and privacy come first",
            body: "Wend uses your front camera to check your posture in real time, right on your device. Nothing is ever recorded or sent anywhere — no video leaves your phone."
        )
    }

    // MARK: - Shared Step Layout

    private func stepLayout(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(WendTheme.Colors.greenLight)
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(WendTheme.Colors.greenDark)
            }

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(WendTheme.Colors.coffee)

            Text(body)
                .font(.system(size: 15, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.7))
                .lineSpacing(3)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(WendTheme.Colors.coffee)
                        .frame(width: 54, height: 54)
                        .background(WendTheme.Colors.creamLight)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button {
                advance()
            } label: {
                Text(currentStep == totalSteps - 1 ? "Get Started" : "Next")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WendTheme.Colors.creamLight)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(canAdvance ? WendTheme.Colors.greenDark : WendTheme.Colors.greenDark.opacity(0.35))
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canAdvance)
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 2:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            return !selectedExerciseIDs.isEmpty
        default:
            return true
        }
    }

    private func advance() {
        if currentStep == totalSteps - 1 {
            completeOnboarding()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep += 1
            }
        }
    }

    // MARK: - Completion

    private func completeOnboarding() {
        // Dispara o prompt de permissão de câmera — a app não bloqueia o
        // onboarding no resultado, já que `CameraManager` trata o estado
        // "não autorizado" de novo quando o usuário abrir um exercício.
        AVCaptureDevice.requestAccess(for: .video) { _ in }

        let profile = profiles.first ?? {
            let created = UserProfile(name: name)
            modelContext.insert(created)
            return created
        }()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFocus = focusArea.trimmingCharacters(in: .whitespacesAndNewlines)

        profile.name = trimmedName.isEmpty ? "Friend" : trimmedName
        profile.inTreatment = inTreatment
        profile.painArea = trimmedFocus.isEmpty ? "Lower Back" : trimmedFocus
        profile.selectedExerciseIDs = Array(selectedExerciseIDs)
        profile.hasCompletedOnboarding = true
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
}
