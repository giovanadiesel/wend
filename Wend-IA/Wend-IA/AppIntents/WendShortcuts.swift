import AppIntents

/// Expõe os App Shortcuts do Wend pra Siri e pro app Atalhos.
struct WendShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStretchIntent(),
            phrases: [
                "Start stretching in \(.applicationName)",
                "Begin my stretch in \(.applicationName)",
            ],
            shortTitle: "Start Stretch",
            systemImageName: "figure.flexibility"
        )
    }
}
