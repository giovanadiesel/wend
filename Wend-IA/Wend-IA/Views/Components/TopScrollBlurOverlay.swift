import SwiftUI

/// `ScrollView` vertical com um blur fixo no topo que só aparece depois que o
/// conteúdo é rolado — como se o conteúdo passasse por baixo de um vidro
/// fosco. Implementação manual (rastreando o offset de rolagem via
/// `PreferenceKey`) porque `.scrollEdgeEffectStyle` depende de uma barra de
/// sistema real (nav bar/toolbar) pra ancorar, e as telas com cabeçalho
/// customizado do Wend não têm uma.
struct BlurTopScrollView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @State private var isScrolled = false
    private let coordinateSpaceName = "BlurTopScrollView"

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named(coordinateSpaceName)).minY
                    )
            }
            .frame(height: 0)

            content()
        }
        .coordinateSpace(name: coordinateSpaceName)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            let scrolled = offset < -4
            if scrolled != isScrolled {
                withAnimation(.easeOut(duration: 0.15)) {
                    isScrolled = scrolled
                }
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 56)
                .mask(
                    LinearGradient(
                        colors: [.black, .black.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .top)
                .opacity(isScrolled ? 1 : 0)
                .allowsHitTesting(false)
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
