import SwiftUI

/// Screen title block. Positions follow the mockups: back icon 30 pt at (17, 61), title 27 pt heavy
/// with its top at 61, subtitle 15 pt at 108 — measured from a 47 pt safe-area top.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                if let onBack {
                    IconButton(icon: "icon_back", size: 30, label: "Back", action: onBack)
                        .padding(.leading, 10)
                        .padding(.trailing, 3)
                    titleText.padding(.top, 7)
                } else {
                    titleText
                        .padding(.leading, 22)
                        .padding(.top, 7)
                }
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.top, 7)
            .frame(minHeight: 51, alignment: .top)
            if let subtitle {
                Text(subtitle)
                    .font(.avenir(15, .medium))
                    .foregroundColor(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.avenir(27, .heavy))
            .foregroundColor(Palette.ink)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, onBack: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.trailing = { EmptyView() }
    }
}

/// "Draft" status chip (70 × 29) shown on the test form.
struct DraftChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.avenir(13, .bold))
            .foregroundColor(Palette.ink)
            .offset(y: 1)
            .padding(.horizontal, 16)
            .frame(minWidth: 70, minHeight: 29)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.draftChip))
            .padding(.top, 8)
            .padding(.trailing, 21)
    }
}

/// Standard light screen: background, scrollable header + content, optional pinned bottom actions.
struct LightScreen<Content: View, Bottom: View>: View {
    var bottomPadding: CGFloat = 12
    var showsBottom: Bool = true
    @ViewBuilder let content: () -> Content
    @ViewBuilder let bottom: () -> Bottom

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
        }
        .background(Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsBottom {
                VStack(spacing: 0) { bottom() }
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 10)
                    .padding(.bottom, bottomPadding)
                    .background(Palette.background.ignoresSafeArea(edges: .bottom))
            }
        }
    }
}

extension LightScreen where Bottom == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.showsBottom = false
        self.content = content
        self.bottom = { EmptyView() }
    }
}

/// Empty state block (art 180 × 190, title 26 heavy, message 17 medium, CTA).
struct EmptyStateView: View {
    let art: Art
    let title: String
    let message: String
    var detail: String? = nil
    var artTop: CGFloat = 157
    var buttonTitle: String?
    var buttonGap: CGFloat = 146.8
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ArtImage(art: art)
                .frame(width: 180, height: 190)
                .padding(.top, artTop)
            Text(title)
                .font(.avenir(26, .heavy))
                .foregroundColor(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.avenir(17, .medium))
                .foregroundColor(Palette.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 235)
                .padding(.top, 12.5)
            if let detail {
                Text(detail)
                    .font(.avenir(14, .bold))
                    .foregroundColor(Palette.sea)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            if let buttonTitle, let action {
                GoldButton(title: buttonTitle, action: action)
                    .padding(.top, detail == nil ? buttonGap : max(buttonGap - 27, 24))
            }
        }
        .padding(.horizontal, Metrics.margin)
        .frame(maxWidth: .infinity)
    }
}

/// Modal card over a dimmed screen (dialogs 32, 33, 35, 38, 41).
struct ModalDialog<Actions: View>: View {
    let icon: String
    let title: String
    let message: String
    var messageToActions: CGFloat = 22
    var bottomPadding: CGFloat = 29
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea()
                .accessibilityHidden(true)
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 16)
                        card
                        Spacer(minLength: 16)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height - 36)
                    .padding(.top, 36)
                }
            }
        }
        .accessibilityAddTraits(.isModal)
        .transition(.opacity)
    }

    private var card: some View {
                VStack(spacing: 0) {
                    UIIcon(name: icon, size: 42)
                        .padding(.top, 21)
                    Text(title)
                        .font(.avenir(24, .heavy))
                        .foregroundColor(Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.avenir(16, .medium))
                        .foregroundColor(Palette.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1.1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 235)
                        .padding(.horizontal, 22)
                        .padding(.top, 9.2)
                    VStack(spacing: 0) { actions() }
                        .padding(.horizontal, 19)
                        .padding(.top, messageToActions)
                        .padding(.bottom, bottomPadding)
                }
                .frame(maxWidth: .infinity)
                .lureCard()
                .padding(.horizontal, Metrics.margin)
    }
}

/// Bottom tab bar (tab_bar 390 × 90 with icons 30 pt and a 44 × 4 indicator).
enum AppTab: Int, CaseIterable, Identifiable {
    case journal, lures, compare, workshop
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .journal: return "Journal"
        case .lures: return "Lures"
        case .compare: return "Compare"
        case .workshop: return "Workshop"
        }
    }

    var icon: String {
        switch self {
        case .journal: return "icon_journal"
        case .lures: return "icon_lure"
        case .compare: return "icon_compare"
        case .workshop: return "icon_workshop"
        }
    }
}

struct LureTabBar: View {
    let selected: AppTab
    let onSelect: (AppTab) -> Void
    @Environment(\.windowSafeArea) private var safeArea

    static func height(safeBottom: CGFloat) -> CGFloat { 71 + max(safeBottom - 15, 4) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button { onSelect(tab) } label: {
                    VStack(spacing: 0) {
                        UIIcon(name: tab.icon, size: 30)
                            .padding(.top, 11)
                        Text(tab.title)
                            .font(.avenirFixed(12, tab == selected ? .bold : .medium))
                            .foregroundColor(tab == selected ? Palette.sea : Palette.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(height: 16.4)
                            .padding(.top, 8)
                        Capsule()
                            .fill(tab == selected ? Palette.sea : .clear)
                            .frame(width: 44, height: 4)
                            .padding(.top, 1.6)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tab.title))
                .accessibilityAddTraits(tab == selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(height: Self.height(safeBottom: safeArea.bottom), alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.panel)
                .shadow(color: Palette.ink.opacity(0.04), radius: 6, x: 0, y: -1)
        )
    }
}
