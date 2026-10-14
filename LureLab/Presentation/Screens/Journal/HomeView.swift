import SwiftUI

/// Screens 04 (My Workbench) and 05 (First Visit). Coordinates follow the SVGs, measured from the
/// safe-area top (content y = mockup y − 47).
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    hero(width: width, height: model.lures.isEmpty ? 380 : 338)
                    if model.lures.isEmpty {
                        firstVisit
                    } else {
                        workbench
                    }
                    TabBarClearance()
                }
            }
            .background(Palette.background.ignoresSafeArea())
        }
    }

    // MARK: Hero (BG01 0…450, band 0…105, logo, title, otter)

    private func hero(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ArtImage(art: .bg01, mode: .fill)
                .frame(width: width, height: 450)
                .offset(y: -47)
                .frame(width: width, height: 403, alignment: .top)
                .clipped()
            Palette.background
                .frame(width: width, height: 58)
            ArtImage(art: .s02)
                .frame(width: 42, height: 34)
                .offset(x: 19, y: 10)
            Text("Lure Lab")
                .font(.avenir(28, .heavy))
                .foregroundColor(Palette.ink)
                .lineLimit(1)
                .offset(x: 70, y: 10)
                .accessibilityAddTraits(.isHeader)
            IconButton(icon: "icon_settings", size: 31, label: "Settings") {
                router.push(.settings)
            }
            .offset(x: width - 60.5, y: 6.5)
            Text("My Workbench")
                .font(.avenir(29, .heavy))
                .foregroundColor(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .offset(x: 22, y: 59)
                .accessibilityAddTraits(.isHeader)
            ArtImage(art: .c01)
                .frame(width: 292, height: 252)
                .offset(x: width / 2 - 195 + 64, y: 113)
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    // MARK: 05 First Visit

    private var firstVisit: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Your workbench is ready")
                    .font(.avenir(24, .heavy))
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                Text("Add a lure, then save what happened on the water.")
                    .font(.avenir(17, .medium))
                    .foregroundColor(Palette.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 250)
                    .padding(.top, 10.2)
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 178)
            .lureCard()
            .padding(.horizontal, Metrics.margin)

            GoldButton(title: "+ Add Your First Lure") {
                router.push(.lureEditor(nil))
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 21)

            Text("Saved on this device")
                .font(.avenir(14, .medium))
                .foregroundColor(Palette.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 15)
        }
    }

    // MARK: 04 My Workbench

    private var workbench: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lure = model.benchLure {
                benchCard(lure)
            }
            GoldButton(title: "+ Log a Test") {
                router.push(.testEditor(.new(lureID: nil)))
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, model.benchLure == nil ? 79 : 11)

            Text("Latest test")
                .font(.avenir(23, .heavy))
                .foregroundColor(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 22)
                .padding(.trailing, 110)
                .padding(.top, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    if !model.tests.isEmpty {
                        Button { router.push(.journal(TestFilter())) } label: {
                            Text("View all ›")
                                .font(.avenir(15, .bold))
                                .foregroundColor(Palette.sea)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.trailing, 24)
                        .padding(.top, 3.3)
                        .accessibilityLabel(Text("View all tests"))
                    }
                }

            latestCard
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 10.6)

            workshopDrop
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 17)
        }
    }

    private func benchCard(_ lure: Lure) -> some View {
        Button { router.push(.lureDetail(lure.id)) } label: {
            VStack(alignment: .leading, spacing: -2) {
                Text("ON THE BENCH")
                    .font(.avenir(11, .bold))
                    .foregroundColor(Palette.secondary)
                Text(lure.name)
                    .font(.avenir(23, .heavy))
                    .foregroundColor(Palette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 11)
            .padding(.bottom, 12.6)
            .padding(.horizontal, 14)
            .frame(width: 262, alignment: .leading)
            .frame(minHeight: 68)
            .lureCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.leading, Metrics.margin)
        .accessibilityLabel(Text("On the bench: \(lure.name)"))
        .accessibilityHint(Text("Opens lure details"))
    }

    @ViewBuilder
    private var latestCard: some View {
        if let test = model.latestTest {
            Button { router.push(.testDetail(test.id)) } label: {
                HStack(alignment: .top, spacing: 14) {
                    PhotoThumb(path: model.lure(test.lureID)?.photoPath, size: 62)
                        .padding(.top, 9)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(test.placeName)
                            .font(.avenir(18, .heavy))
                            .foregroundColor(Palette.ink)
                            .lineLimit(1)
                            .padding(.top, 7)
                        Text([test.retrieve?.listTitle, Format.shortDate(test.occurredAt)].compactMap { $0 }.joined(separator: " · "))
                            .font(.avenir(13, .demiBold))
                            .foregroundColor(Palette.secondary)
                            .padding(.top, 3.4)
                        Text(Format.durationAndCounts(test))
                            .font(.avenir(13, .demiBold))
                            .foregroundColor(Palette.secondary)
                            .padding(.top, 3.2)
                            .padding(.bottom, 7)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 9)
                .frame(maxWidth: .infinity, minHeight: 81, alignment: .topLeading)
                .lureCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Latest test: \(test.placeName), \(Format.mediumDate(test.occurredAt)). \(Format.durationAndCounts(test))"))
            .accessibilityAddTraits(.isButton)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text("No tests yet")
                    .font(.avenir(18, .heavy))
                    .foregroundColor(Palette.ink)
                Text("Your first observation starts the journal.")
                    .font(.avenir(13, .demiBold))
                    .foregroundColor(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 81, alignment: .leading)
            .lureCard()
        }
    }

    private var workshopDropSubtitle: String {
        let state = model.capsuleState
        if model.workshop.pendingReceipt != nil { return "Result ready to view" }
        if state.capsules > 0 { return "\(Format.capsules(state.capsules)) ready" }
        if let next = state.nextEligibleAt, next > model.now { return "Next after \(Format.shortDateAndTime(next))" }
        return "Save a test to earn one"
    }

    private var workshopDrop: some View {
        HStack(spacing: 0) {
            ArtImage(art: .s03)
                .frame(width: 64, height: 51)
                .padding(.leading, 11)
            VStack(alignment: .leading, spacing: 2.8) {
                Text("Workshop Drop")
                    .font(.avenir(17, .heavy))
                    .foregroundColor(Palette.ink)
                Text(workshopDropSubtitle)
                    .font(.avenir(14, .demiBold))
                    .foregroundColor(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 11)
            .padding(.vertical, 8)
            Spacer(minLength: 8)
            PillButton(title: "Open") {
                coordinator.open(.workshop, stack: [.luckyCast])
            }
            .padding(.trailing, 16)
            .accessibilityLabel(Text("Open Lucky Cast"))
        }
        .frame(maxWidth: .infinity, minHeight: 65)
        .lureCard()
    }
}
