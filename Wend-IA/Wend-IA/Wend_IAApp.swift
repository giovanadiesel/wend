//
//  Wend_IAApp.swift
//  Wend-IA
//
//  Created by Giovana on 23/07/26.
//

import SwiftUI
import SwiftData

@main
struct Wend_IAApp: App {
    
    /// Container SwiftData compartilhado com os modelos persistidos do app.
    ///
    /// `SessionRecord` armazena o histórico de sessões de exercício.
    /// `UserProfile` armazena as configurações e preferências do usuário.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SessionRecord.self,
            UserProfile.self,
            DailyTipCache.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Wend: Falha ao criar o ModelContainer — \(error.localizedDescription)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(Wend_IAApp.sharedModelContainer)
    }
}
