import SwiftUI

// MARK: - Placeholder Exercise Animations
//
// Animações temporárias (boneco de palito estilizado) em SwiftUI puro para
// exercícios sem vídeo demonstrativo ainda (ver `LoopingVideoView` para os
// que já têm). Não são anatomicamente literais — só sugerem o movimento até
// o vídeo de verdade ser gerado e integrado.
//
// Técnica: cada "membro" é um grupo (Capsule + conteúdo aninhado) girado com
// `.rotationEffect(anchor:)`, que anima suavemente com `withAnimation` — ao
// contrário de um `Path` cru com pontos recalculados, que não interpola.

/// Figura simples: cabeça + tronco como um único grupo rígido que gira em
/// torno de uma âncora (base do tronco), oscilando entre dois ângulos.
private struct RockingTorsoFigure: View {
    let fromAngle: Double
    let toAngle: Double
    let anchor: UnitPoint
    let duration: Double
    let color: Color

    @State private var isAtTo = false

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(color)
                .frame(width: 34, height: 34)
            Capsule()
                .fill(color)
                .frame(width: 20, height: 90)
        }
        .rotationEffect(.degrees(isAtTo ? toAngle : fromAngle), anchor: anchor)
        .onAppear {
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                isAtTo = true
            }
        }
    }
}

/// Base decorativa (assento/chão), puramente estética.
private struct GroundLine: View {
    let color: Color
    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 130, height: 8)
    }
}

// MARK: - Piriformis Stretch

/// Tronco inclinando pra frente a partir do quadril, como no hinge do alongamento.
struct PiriformisAnimationView: View {
    var body: some View {
        VStack(spacing: 10) {
            RockingTorsoFigure(
                fromAngle: -6,
                toAngle: 34,
                anchor: .bottom,
                duration: 1.8,
                color: .white.opacity(0.9)
            )
            GroundLine(color: .white.opacity(0.35))
        }
    }
}

// MARK: - Lumbar Rotation

/// Figura deitada — tronco fixo, "pernas" (grupo inferior) balançam de um
/// lado pro outro, como ao rolar a bola de um lado a outro.
struct LumbarRotationAnimationView: View {
    @State private var swung = false

    var body: some View {
        ZStack {
            // Tronco + cabeça, deitados, fixos.
            HStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 90, height: 20)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 34, height: 34)
            }
            .offset(x: -30)

            // "Pernas" — grupo que gira em torno do quadril (borda esquerda).
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: 70, height: 18)
                .offset(x: 35)
                .rotationEffect(.degrees(swung ? 22 : -22), anchor: .leading)
                .offset(x: -60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                swung = true
            }
        }
    }
}
