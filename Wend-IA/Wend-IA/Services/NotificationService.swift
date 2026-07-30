import Foundation
import SwiftData
import UserNotifications

/// Agenda/cancela as notificações locais de lembrete de alongamento com base
/// em `UserProfile.reminderTimes`.
///
/// Estratégia: sempre reagenda do zero (cancela tudo, recria) em vez de
/// tentar diffar horário por horário — mais simples e evita notificações
/// órfãs quando um horário é removido ou editado.
///
/// ### Limitação conhecida
/// O conteúdo da notificação (nome do próximo exercício pendente) é fixado
/// no momento em que a notificação é agendada, não no momento em que ela
/// dispara — `UNCalendarNotificationTrigger` com `repeats: true` reusa o
/// mesmo `UNNotificationContent` em toda repetição diária. Sem uma
/// Notification Service Extension não dá pra recalcular o texto a cada
/// disparo, então o texto reflete "o próximo exercício pendente de hoje,
/// no momento em que o lembrete foi configurado".
@Observable
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let reminderIdentifierPrefix = "wend.reminder."

    private init() {}

    // MARK: - Permissão

    /// Solicita autorização de notificação, caso o usuário ainda não tenha decidido.
    /// Seguro pra chamar múltiplas vezes — não reexibe o prompt se já houver decisão.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Agendamento

    /// Cancela todos os lembretes agendados e recria um por horário em
    /// `profile.reminderTimes`, repetindo diariamente. Não agenda nada se a
    /// câmera estiver desativada (`cameraEnabled == false`) ou se não houver
    /// horários configurados — nesses casos o efeito é só cancelar.
    func rescheduleReminders(for profile: UserProfile) async {
        cancelAllReminders()

        guard profile.cameraEnabled, !profile.reminderTimes.isEmpty else { return }

        await requestAuthorizationIfNeeded()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let exerciseName = nextPendingExerciseName(for: profile)

        for (index, comps) in profile.reminderTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Time for your stretch"
            content.body = exerciseName.map { "Let's do \($0) — just a few minutes for your back." }
                ?? "A gentle reminder to stretch your lower back today."
            content.sound = .default

            var trigger = DateComponents()
            trigger.hour = comps.hour
            trigger.minute = comps.minute

            let calendarTrigger = UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(reminderIdentifierPrefix)\(index)",
                content: content,
                trigger: calendarTrigger
            )
            try? await center.add(request)
        }
    }

    /// Cancela todos os lembretes agendados pelo Wend.
    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Próximo Exercício

    /// Nome do próximo exercício pendente da rotina de hoje — mesma lógica de
    /// `SessionStore.nextExercise(in:)` já usada por `StartStretchIntent`, sem
    /// duplicar o cálculo.
    private func nextPendingExerciseName(for profile: UserProfile) -> String? {
        let routine = profile.todaysRoutine()
        guard !routine.isEmpty else { return nil }

        let context = Wend_IAApp.sharedModelContainer.mainContext
        let records = (try? context.fetch(FetchDescriptor<SessionRecord>())) ?? []
        let store = SessionStore(records: records)

        let chosen = store.nextExercise(in: routine) ?? routine.first
        return chosen?.name
    }
}
