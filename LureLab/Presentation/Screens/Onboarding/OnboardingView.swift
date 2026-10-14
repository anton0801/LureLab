import SwiftUI

/// Screens 01–03. No permissions are requested and no data is created.
struct OnboardingView: View {
    let onFinish: () -> Void

    private struct Page {
        let art: Art
        let title: String
        let body: String
    }

    private let pages = [
        Page(art: .ob01, title: "Test your tackle", body: "Keep the details that matter. Your lures and observations, together."),
        Page(art: .ob02, title: "Every test tells a story", body: "Save conditions, bites and catches. A quiet day is worth recording too."),
        Page(art: .ob03, title: "Build your collection", body: "Free workshop parts unlock collectible lures for your showcase.")
    ]

    @State private var index = 0
    @State private var dragOffset: CGFloat = 0
    @Environment(\.windowSafeArea) private var safeArea
    @Environment(\.lureReduceMotion) private var reduceMotion
    @Environment(\.haptics) private var haptics

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { page in
                        pageView(pages[page], number: page)
                            .frame(width: width)
                    }
                }
                .frame(width: width, alignment: .leading)
                .offset(x: -CGFloat(index) * width + dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let atEdge = (index == 0 && value.translation.width > 0) || (index == pages.count - 1 && value.translation.width < 0)
                            dragOffset = atEdge ? value.translation.width / 4 : value.translation.width
                        }
                        .onEnded { value in
                            let threshold = width / 4
                            var target = index
                            if value.translation.width < -threshold || value.predictedEndTranslation.width < -width / 2 { target += 1 }
                            if value.translation.width > threshold || value.predictedEndTranslation.width > width / 2 { target -= 1 }
                            go(to: min(max(target, 0), pages.count - 1))
                        }
                )

                if index < pages.count - 1 {
                    Button {
                        haptics.tap()
                        onFinish()
                    } label: {
                        Text("Skip")
                            .font(.avenir(16, .bold))
                            .foregroundColor(Palette.ink)
                            .padding(.horizontal, 14)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, safeArea.top + 7)
                    .padding(.trailing, 19)
                    .accessibilityHint(Text("Skips the introduction"))
                }
            }
            .frame(width: width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .ignoresSafeArea()
        .background(Palette.deepOcean.ignoresSafeArea())
        .onAppear {
            #if DEBUG
            if let scenario = DebugScenario.name, let page = Int(scenario), (2...3).contains(page) { index = page - 1 }
            #endif
        }
    }

    private func go(to page: Int) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.4, dampingFraction: 0.88)) {
            index = page
            dragOffset = 0
        }
    }

    private func pageView(_ page: Page, number: Int) -> some View {
        ZStack(alignment: .bottom) {
            ArtImage(art: page.art, mode: .fill)
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Text(page.title)
                        .font(.avenir(26, .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.body)
                        .font(.avenir(16, .medium))
                        .foregroundColor(Palette.onboardingBody)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2.1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 250)
                        .padding(.top, 12.5)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 133, alignment: .top)

                HStack(spacing: 10) {
                    ForEach(pages.indices, id: \.self) { dot in
                        Circle()
                            .fill(dot == number ? Palette.gold : Palette.dotInactive)
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("Page \(number + 1) of \(pages.count)"))

                GoldButton(title: number == pages.count - 1 ? "Get Started" : "Next") {
                    if number == pages.count - 1 { onFinish() } else { go(to: number + 1) }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 19)
                .padding(.bottom, max(safeArea.bottom + 1, 16))
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
            .background(Palette.deepOcean)
        }
        .clipped()
    }
}
