import SwiftData
import SwiftUI

/// Aba "Profile" — identidade do usuário e preferências de prática.
///
/// Nomeada `WendProfileView` para seguir a mesma convenção de
/// `WendProgressView` (evita ambiguidade com nomes genéricos).
struct WendProfileView: View {

    // MARK: - SwiftData

    @Query private var profiles: [UserProfile]

    // MARK: - State Local

    @State private var showReminderSheet = false
    @State private var showEditProfileSheet = false

    private var profile: UserProfile? { profiles.first }

    // MARK: - Body

    var body: some View {
        BlurTopScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                if let profile {
                    preferencesCard(profile: profile)
                    routineSelectionCard(profile: profile)
                }

                privacyCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .sheet(isPresented: $showReminderSheet) {
            if let profile {
                ReminderTimesSheet(profile: profile)
            }
        }
        .sheet(isPresented: $showEditProfileSheet) {
            if let profile {
                EditProfileSheet(profile: profile)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        // Mesma estrutura de ícone + título + subtítulo de `HeaderView`/`WendProgressView`,
        // pra manter a posição do título consistente entre as três abas.
        HStack(alignment: .center, spacing: 14) {
            avatarCircle

            VStack(alignment: .leading, spacing: 3) {
                Text(profile?.name ?? "—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(WendTheme.Colors.coffee)

                if let profile {
                    Text("Focus: \(profile.painArea) · \(profile.inTreatment ? "In treatment" : "Maintenance")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WendTheme.Colors.greenBasic)
                }
            }

            Spacer()

            Button {
                showEditProfileSheet = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(WendTheme.Colors.greenDark)
                    .frame(width: 32, height: 32)
                    .background(WendTheme.Colors.greenLight)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(WendTheme.Colors.greenLight)
                .frame(width: 60, height: 60)
            Text(initials)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(WendTheme.Colors.greenDark)
        }
    }

    private var initials: String {
        guard let name = profile?.name, !name.isEmpty else { return "?" }
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    // MARK: - Preferences Card

    private func preferencesCard(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice preferences")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)

            VStack(spacing: 0) {
                reminderRow(profile: profile)

                Divider()
                    .background(WendTheme.Colors.coffee.opacity(0.1))
                    .padding(.leading, 52)

                toggleRow(
                    icon: "camera.fill",
                    label: "Camera usage",
                    isOn: Binding(
                        get: { profile.cameraEnabled },
                        set: { newValue in
                            profile.cameraEnabled = newValue
                            // Sem câmera, o app não guia a sessão em tempo real — não faz
                            // sentido manter lembretes agendados pra tocar um exercício
                            // que a pessoa desativou o jeito principal de fazer.
                            Task { await NotificationService.shared.rescheduleReminders(for: profile) }
                        }
                    )
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(WendTheme.Colors.creamLight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func reminderRow(profile: UserProfile) -> some View {
        Button {
            showReminderSheet = true
        } label: {
            HStack(spacing: 14) {
                rowIcon("bell.fill")

                Text("Reminders")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee)

                Spacer()

                Text(reminderSummary(profile.reminderTimes))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.5))
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WendTheme.Colors.coffee.opacity(0.3))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggleRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            rowIcon(icon)

            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(WendTheme.Colors.coffee)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(WendTheme.Colors.greenBasic)
        }
        .padding(.vertical, 10)
    }

    private func rowIcon(_ systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(WendTheme.Colors.greenLight)
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WendTheme.Colors.greenBasic)
        }
    }

    private func reminderSummary(_ times: [DateComponents]) -> String {
        guard !times.isEmpty else { return "Not set" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let calendar = Calendar.current
        let labels = times.compactMap { comps -> String? in
            guard let date = calendar.date(from: comps) else { return nil }
            return formatter.string(from: date)
        }
        return labels.joined(separator: ", ")
    }

    // MARK: - Routine Selection Card

    /// Lista todos os exercícios do plano — marcados os que estão em
    /// `profile.selectedExerciseIDs`, tocáveis pra incluir/excluir da rotina.
    private func routineSelectionCard(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("My routine")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(WendTheme.Colors.coffee)

            VStack(spacing: 0) {
                ForEach(Array(StretchDefinition.sampleStretches.enumerated()), id: \.element.id) { index, stretch in
                    routineToggleRow(for: stretch, profile: profile)

                    if index < StretchDefinition.sampleStretches.count - 1 {
                        Divider()
                            .background(WendTheme.Colors.coffee.opacity(0.1))
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(WendTheme.Colors.creamLight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func routineToggleRow(for stretch: StretchDefinition, profile: UserProfile) -> some View {
        let isActive = profile.selectedExerciseIDs.contains(stretch.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isActive {
                    profile.deselectExercise(stretch.id)
                } else {
                    profile.selectExercise(stretch.id)
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(isActive ? WendTheme.Colors.greenBasic : WendTheme.Colors.coffee.opacity(0.25))

                Text(stretch.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isActive ? WendTheme.Colors.coffee : WendTheme.Colors.coffee.opacity(0.4))

                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Privacy Card

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(WendTheme.Colors.greenDark)

            Text("No video is recorded or uploaded. Wend only processes movement data locally, on your device, to guide you.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(WendTheme.Colors.coffee.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WendTheme.Colors.creamDark)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Edit Profile Sheet

/// Sheet simples para editar nome, área de dor e status de tratamento.
private struct EditProfileSheet: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WendTheme.Colors.creamBasic.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Name", text: $profile.name)
                        TextField("Focus area (e.g. Lower Back)", text: $profile.painArea)
                    }

                    Section {
                        Toggle("Currently in treatment", isOn: $profile.inTreatment)
                            .tint(WendTheme.Colors.greenBasic)
                    } footer: {
                        Text("Off shows as \"Maintenance\" on your profile.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    DismissGlassButton(
                        systemImage: "checkmark",
                        iconColor: WendTheme.Colors.creamLight,
                        backgroundColor: WendTheme.Colors.greenDark
                    ) {
                        dismiss()
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }
}

// MARK: - Reminder Times Sheet

/// Sheet simples para adicionar/remover horários de lembrete — sem tela
/// dedicada por enquanto, como um `DatePicker` + lista.
private struct ReminderTimesSheet: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var newTime = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                WendTheme.Colors.creamBasic.ignoresSafeArea()

                List {
                    Section {
                        HStack(spacing: 14) {
                            DatePicker("Time", selection: $newTime, displayedComponents: .hourAndMinute)
                                .tint(WendTheme.Colors.greenDark)

                            addReminderButton
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    } header: {
                        Text("Add a reminder")
                    }

                    if !profile.reminderTimes.isEmpty {
                        Section {
                            ForEach(Array(profile.reminderTimes.enumerated()), id: \.offset) { _, comps in
                                Text(formatted(comps))
                                    .font(.system(size: 15))
                                    .foregroundColor(WendTheme.Colors.coffee)
                            }
                            .onDelete { offsets in
                                profile.reminderTimes.remove(atOffsets: offsets)
                                Task { await NotificationService.shared.rescheduleReminders(for: profile) }
                            }
                        } header: {
                            Text("Your reminders")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    DismissGlassButton(
                        systemImage: "checkmark",
                        iconColor: WendTheme.Colors.creamLight,
                        backgroundColor: WendTheme.Colors.greenDark
                    ) {
                        dismiss()
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    // MARK: - Add Reminder Button

    /// Botão circular verde sólido inspirado no app Alarms da Apple — usado no
    /// lugar de um link de texto pra dar mais destaque à ação principal da sheet.
    private var addReminderButton: some View {
        Button {
            addReminder()
        } label: {
            ZStack {
                Circle()
                    .fill(WendTheme.Colors.greenDark)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WendTheme.Colors.creamLight)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func addReminder() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
        profile.reminderTimes.append(comps)
        // Primeira vez configurando um lembrete é o gatilho natural pra pedir
        // permissão de notificação — sem passo dedicado no onboarding.
        Task { await NotificationService.shared.rescheduleReminders(for: profile) }
    }

    private func formatted(_ comps: DateComponents) -> String {
        guard let date = Calendar.current.date(from: comps) else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    WendProfileView()
        .background(WendTheme.Colors.creamBasic)
        .modelContainer(for: [SessionRecord.self, UserProfile.self, DailyTipCache.self], inMemory: true)
}
