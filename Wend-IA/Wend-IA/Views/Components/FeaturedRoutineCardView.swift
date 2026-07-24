import SwiftUI
import UIKit

/// Card em destaque da rotina "Morning Stretch" com banner, badge e botão de Start.
public struct FeaturedRoutineCardView: View {
    public var title: String
    public var description: String
    public var durationText: String
    public var onStart: () -> Void

    public init(
        title: String = "Morning Stretch",
        description: String = "Wake up your body with gentle movements focused on the lower back.",
        durationText: String = "10 min",
        onStart: @escaping () -> Void = {}
    ) {
        self.title = title
        self.description = description
        self.durationText = durationText
        self.onStart = onStart
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Banner Image Section
            ZStack(alignment: .topLeading) {
                bannerImageView
                    .frame(height: 180)
                    .clipped()

                // Tag "10 min": Fundo Cream Light, Ícone Green Basic, Texto Coffee
                HStack(spacing: 5) {
                    Image(systemName: WendSymbols.durationClock)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WendTheme.Colors.greenBasic)

                    Text(durationText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WendTheme.Colors.coffee)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(WendTheme.Colors.creamLight)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                .padding(14)
            }

            // Bottom Info & Button Section
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(WendTheme.Colors.coffee)

                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(WendTheme.Colors.coffee.opacity(0.85))
                        .lineSpacing(2)
                }

                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Image(systemName: WendSymbols.playStart)
                            .font(.system(size: 14, weight: .bold))
                        Text("Start")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(WendTheme.Colors.creamLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(WendTheme.Colors.greenDark)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(18)
            .background(WendTheme.Colors.greenLight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    @ViewBuilder
    private var bannerImageView: some View {
        // Usa o asset catalog — funciona no device, simulator e preview.
        // O arquivo morning_stretch_banner.jpg deve estar em Assets.xcassets.
        if let uiImage = UIImage(named: "morning_stretch_banner") {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            fallbackBannerGradient
        }
    }
    
    private var fallbackBannerGradient: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E8D8C8"), Color(hex: "#C5B29D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "figure.stretching")
                .font(.system(size: 60))
                .foregroundColor(WendTheme.Colors.greenDark.opacity(0.3))
        }
    }
}

#Preview {
    FeaturedRoutineCardView()
        .padding()
        .background(WendTheme.Colors.creamBasic)
}
