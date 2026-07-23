import SwiftUI
import Vision

/// Tela de debug para validar captura de câmera, detecção de pose e cálculo de ângulo.
///
/// **Não faz parte do design final do Wend.** Deve ser removida antes do release.
///
/// Exibe:
/// - Preview em tela cheia da câmera frontal via `CameraManager`
/// - Círculos ciano sobrepostos em cada articulação detectada pela `PoseAnalyzer`
/// - HUD com o ângulo calculado para a regra `ombro → quadril → joelho (direito)`
///   e indicação visual se está dentro ou fora da faixa aceitável
struct PoseTestView: View {

    // MARK: - State

    @StateObject private var camera = CameraManager()
    @StateObject private var analyzer = PoseAnalyzer()
    @Environment(\.dismiss) private var dismiss

    // MARK: - Regra de Teste Fixa

    /// Ombro direito → Quadril direito (vértice) → Joelho direito.
    /// Faixa 150–180°: postura ereta lateral esperada durante exercícios lombares.
    private let testRule = JointAngleRule(
        jointA: .rightShoulder,
        jointB: .rightHip,
        jointC: .rightKnee,
        acceptableRange: 150.0...180.0,
        mistakeHint: "Endireite a postura: quadril deve estar alinhado com ombro e joelho."
    )

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // ── 1. Preview da câmera em tela cheia ─────────────────────────
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()

                // ── 2. Overlay de pontos de pose ────────────────────────────────
                Canvas { context, size in
                    for (_, point) in analyzer.detectedJoints {
                        // VNRecognizedPoint: origem bottom-left, normalizado [0,1].
                        // Câmera frontal tem display espelhado (isVideoMirrored = true),
                        // mas o Vision processa o buffer original → invertemos X para alinhar.
                        let x = (1.0 - point.location.x) * size.width
                        let y = (1.0 - point.location.y) * size.height
                        let diameter: CGFloat = 12
                        let rect = CGRect(
                            x: x - diameter / 2,
                            y: y - diameter / 2,
                            width: diameter,
                            height: diameter
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.cyan.opacity(0.85))
                        )
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false) // Transparente para gestos

                // ── 3. HUD de ângulo e status ───────────────────────────────────
                VStack(spacing: 0) {
                    dismissButton
                    Spacer()
                    angleHUD
                        .padding(.horizontal, 16)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            // Inicia captura e análise quando a view aparece
            camera.requestAuthorization()
            analyzer.connect(to: camera)
            camera.start()
        }
        .onDisappear {
            camera.stop()
            analyzer.disconnect()
        }
    }

    // MARK: - Subviews

    private var dismissButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white, Color.black.opacity(0.5))
                    .padding(.top, 56)
                    .padding(.leading, 16)
            }
            Spacer()

            // Indicador de autorização
            if let error = camera.authorizationError {
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.top, 56)
                    .padding(.trailing, 16)
            }
        }
    }

    @ViewBuilder
    private var angleHUD: some View {
        let evaluation = analyzer.evaluateAngle(rule: testRule)

        VStack(alignment: .leading, spacing: 10) {

            // Título
            Label("Debug — Pose Engine", systemImage: "figure.flexibility")
                .font(.headline)
                .foregroundColor(.white)

            Text("Regra: ombro → quadril → joelho (direito)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))

            Divider().background(Color.white.opacity(0.25))

            if let eval = evaluation {
                // Ângulo e status
                HStack {
                    Text(String(format: "Ângulo: %.1f°", eval.degrees))
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Text(eval.isWithinRange ? "✅ Dentro da faixa" : "❌ Fora da faixa")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundColor(eval.isWithinRange ? .green : .red)
                }

                // Faixa aceitável
                Text(
                    "Faixa: \(Int(testRule.acceptableRange.lowerBound))°–\(Int(testRule.acceptableRange.upperBound))°"
                )
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))

                // Dica de erro (só quando fora da faixa)
                if !eval.isWithinRange {
                    Text("⚠️ \(testRule.mistakeHint)")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(
                    analyzer.isDetecting
                    ? "Pose detectada, mas as articulações alvo não estão visíveis."
                    : "Aguardando detecção de pose…"
                )
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .italic()
            }

            Divider().background(Color.white.opacity(0.25))

            // Contadores de diagnóstico
            HStack {
                Label(
                    "\(analyzer.detectedJoints.count) pontos",
                    systemImage: "dot.radiowaves.left.and.right"
                )
                Spacer()
                Label(
                    camera.isRunning ? "Câmera ativa" : "Câmera inativa",
                    systemImage: camera.isRunning ? "camera.fill" : "camera.slash"
                )
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    PoseTestView()
}
