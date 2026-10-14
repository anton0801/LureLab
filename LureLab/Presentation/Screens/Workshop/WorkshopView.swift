import SwiftUI

/// Fills the status-bar strip with the light header colour on art-backed screens.
struct StatusBarCover: View {
    var body: some View {
        Color.clear
            .frame(height: 0)
            .background(Palette.background.ignoresSafeArea(edges: .top))
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }
}

/// Screen 19: capsules, Parts, Lucky Cast, showcase and the guide. No store, ads or real-value exchange.
struct WorkshopView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .top) {
                ArtImage(art: .bg03, mode: .fill)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(width: width)
                        balanceCard
                            .padding(.horizontal, Metrics.margin)
                        GoldButton(title: "Lucky Cast") { router.push(.luckyCast) }
                            .padding(.horizontal, Metrics.margin)
                            .padding(.top, 29)
                        SurfaceButton(title: "My Showcase") { router.push(.showcase) }
                            .padding(.horizontal, Metrics.margin)
                            .padding(.top, 17)
                        infoCard
                            .padding(.horizontal, Metrics.margin)
                            .padding(.top, 34)
                        TabBarClearance()
                    }
                }
                StatusBarCover()
            }
        }
    }

    private func hero(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Palette.background.frame(width: width, height: 62)
            Text("Workshop")
                .font(.avenir(27, .heavy))
                .foregroundColor(Palette.ink)
                .offset(x: 22, y: 14)
                .accessibilityAddTraits(.isHeader)
            ZStack {
                ArtImage(art: .f02)
                VStack(spacing: 0) {
                    Text("MAKE IT")
                        .font(.avenirFixed(26, .heavy))
                    Text("YOUR OWN")
                        .font(.avenirFixed(24, .heavy))
                        .padding(.top, -1.5)
                }
                .foregroundColor(Palette.gold)
                .padding(.top, 26)
                .frame(width: 200, height: 137, alignment: .top)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Make it your own"))
            }
            .frame(width: 200, height: 137)
            .offset(x: 22, y: 104)
            ArtImage(art: .c03)
                .frame(width: 142, height: 171)
                .offset(x: width - 168, y: 85)
        }
        .frame(width: width, height: 280, alignment: .topLeading)
    }

    @ViewBuilder
    private var balanceCard: some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ArtImage(art: .s03).frame(width: 64, height: 61)
                    Text(Format.capsules(model.capsuleState.capsules))
                        .font(.avenir(19, .heavy))
                        .foregroundColor(Palette.ink)
                }
                HStack(spacing: 10) {
                    ArtImage(art: .p03).frame(width: 64, height: 47)
                    Text(Format.parts(model.capsuleState.parts))
                        .font(.avenir(18, .heavy))
                        .foregroundColor(Palette.ink)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lureCard()
            .accessibilityElement(children: .combine)
        } else {
            regularBalanceCard
        }
    }

    private var regularBalanceCard: some View {
        GeometryReader { proxy in
            HStack(alignment: .top, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    ArtImage(art: .s03).frame(width: 64, height: 61)
                    Text(Format.capsules(model.capsuleState.capsules))
                        .font(.avenir(19, .heavy))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 3)
                }
                .padding(.leading, 15)
                .padding(.top, 12)
                .frame(width: proxy.size.width / 2 + 22, alignment: .leading)
                HStack(alignment: .top, spacing: 9) {
                    ArtImage(art: .p03).frame(width: 44, height: 47)
                    Text(Format.parts(model.capsuleState.parts))
                        .font(.avenir(18, .heavy))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 9)
                }
                .padding(.top, 17)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 89)
        .lureCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Format.capsules(model.capsuleState.capsules)), \(Format.parts(model.capsuleState.parts))"))
    }

    private var infoCard: some View {
        Button { router.push(.workshopGuide) } label: {
            VStack(spacing: 0) {
                Text("A little extra after the outing")
                    .font(.avenir(19, .heavy))
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                Text("Free capsules. Collectible lures.")
                    .font(.avenir(15, .medium))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                Text("How it works ›")
                    .font(.avenir(14, .bold))
                    .foregroundColor(Palette.sea)
                    .padding(.top, 5.5)
                    .padding(.bottom, 8.9)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 102)
            .lureCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint(Text("Opens the workshop guide"))
    }
}
