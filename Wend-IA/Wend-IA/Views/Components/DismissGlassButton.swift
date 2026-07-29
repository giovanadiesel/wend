import SwiftUI

/// Botão de fechar ("X") padrão do app — círculo com efeito de vidro fosco
/// (`.ultraThinMaterial`) sobre um tom Cream Basic translúcido, usado tanto
/// na tela de exercício (`ExercisingView`) quanto nas sheets de detalhe.
/// Centraliza o estilo pra manter os dois visualmente idênticos.
struct DismissGlassButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    WendTheme.Colors.creamBasic.opacity(0.75)
                }
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )

                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(WendTheme.Colors.coffee)
            }
            .frame(width: 44, height: 44)
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        WendTheme.Colors.greenBasic.ignoresSafeArea()
        DismissGlassButton(action: {})
    }
}
