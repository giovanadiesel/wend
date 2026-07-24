import SwiftUI
import UIKit

/// Card em destaque de rotina (Morning Stretch / Night Unwind) com banner, badge e botão Start.
public struct FeaturedRoutineCardView: View {
    public var title: String
    public var description: String
    public var durationText: String
    public var bannerImageName: String
    public var timeOfDay: RoutineTimeOfDay
    public var onStart: () -> Void

    public init(
        title: String = "Morning Stretch",
        description: String = "Wake up your body with gentle movements focused on the lower back.",
        durationText: String = "10 min",
        bannerImageName: String = "morning_stretch_banner",
        timeOfDay: RoutineTimeOfDay = .morning,
        onStart: @escaping () -> Void = {}
    ) {
        self.title = title
        self.description = description
        self.durationText = durationText
        self.bannerImageName = bannerImageName
        self.timeOfDay = timeOfDay
        self.onStart = onStart
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Banner Image Section
            ZStack(alignment: .topLeading) {
                bannerImageView
                    .frame(height: 180)
                    .clipped()

                // Badges no topo
                HStack(spacing: 8) {
                    // Tag Período (Sun / Moon)
                    HStack(spacing: 5) {
                        Image(systemName: timeOfDay.iconSymbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(tagIconColor)

                        Text(timeOfDay.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WendTheme.Colors.coffee)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(WendTheme.Colors.creamLight)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)

                    // Tag Duração
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
                }
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
                    .background(buttonBackgroundColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(18)
            .background(cardBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var bannerImageView: some View {
        if let uiImage = UIImage(named: bannerImageName) {
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
                colors: timeOfDay == .morning
                    ? [Color(hex: "#E8D8C8"), Color(hex: "#C5B29D")]
                    : [Color(hex: "#3D3860"), Color(hex: "#1F1B38")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: timeOfDay.iconSymbol)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.2))
        }
    }

    private var tagIconColor: Color {
        timeOfDay == .morning ? Color(hex: "#D4832A") : Color(hex: "#6B5B95")
    }

    private var cardBackgroundColor: Color {
        timeOfDay == .morning ? WendTheme.Colors.greenLight : Color(hex: "#EAE6F2")
    }

    private var buttonBackgroundColor: Color {
        timeOfDay == .morning ? WendTheme.Colors.greenDark : Color(hex: "#3D3860")
    }
}

#Preview {
    FeaturedRoutineCardView()
        .padding()
        .background(WendTheme.Colors.creamBasic)
}
