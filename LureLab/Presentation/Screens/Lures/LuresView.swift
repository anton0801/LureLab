import SwiftUI

enum LureCategory: String, CaseIterable, Identifiable {
    case all, minnow, spinner, softBait
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .minnow: return "Minnow"
        case .spinner: return "Spinner"
        case .softBait: return "Soft bait"
        }
    }

    func matches(_ lure: Lure) -> Bool {
        switch self {
        case .all: return true
        case .minnow: return lure.type == .minnow
        case .spinner: return lure.type == .spinner
        case .softBait: return lure.type == .softBait
        }
    }
}

func lureMatches(_ lure: Lure, query: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }
    return [lure.name, lure.brand ?? "", lure.color ?? "", lure.type.title, lure.notes]
        .joined(separator: " ")
        .localizedCaseInsensitiveContains(trimmed)
}

/// Screens 08 (My Lures), 09 (Lures Empty) and 37 (No Search Results).
struct LuresView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @State private var query = ""
    @State private var category: LureCategory = .all
    @FocusState private var searchFocused: Bool
    @Environment(\.sizeCategory) private var sizeCategory

    private var filtered: [Lure] {
        model.activeLures.filter { category.matches($0) && lureMatches($0, query: query) }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if model.activeLures.isEmpty {
                        ScreenHeader(title: "My Lures")
                        EmptyStateView(art: .p01, title: "Your tackle starts here",
                                       message: "Add a lure with a name and optional photo.",
                                       artTop: 110, buttonTitle: "+ Add Lure") {
                            router.push(.lureEditor(nil))
                        }
                    } else if filtered.isEmpty && !searchFocused {
                        // Screen 37: filters hide every lure (not an empty catalogue).
                        ScreenHeader(title: "My Lures") {
                            IconButton(icon: "icon_plus", size: 30, label: "Add Lure") { router.push(.lureEditor(nil)) }
                                .padding(.trailing, 17)
                                .padding(.top, 1)
                        }
                        EmptyStateView(art: .p01, title: "No matching lures",
                                       message: "Try a different name or clear the filters.",
                                       detail: activeFilterSummary,
                                       artTop: 110, buttonTitle: "Clear Filters") {
                            query = ""
                            category = .all
                        }
                    } else {
                        hero(width: proxy.size.width)
                        searchAndFilters
                        if filtered.isEmpty {
                            noResults
                        } else {
                            VStack(spacing: 13) {
                                ForEach(filtered) { lure in
                                    Button { router.push(.lureDetail(lure.id)) } label: {
                                        LureCardRow(lure: lure,
                                                    meta: Format.lureMeta(lure, units: model.settings.units),
                                                    status: Format.tests(model.testCount(for: lure.id))) {
                                            UIIcon(name: "icon_chevron", size: 23)
                                        }
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                    .accessibilityHint(Text("Opens lure details"))
                                }
                            }
                            .padding(.horizontal, Metrics.margin)
                            .padding(.top, 14)
                        }
                    }
                    TabBarClearance()
                }
            }
            .background(Palette.background.ignoresSafeArea())
        }
        .onAppear {
            #if DEBUG
            if DebugScenario.name == "37" { query = "Golden" }
            #endif
        }
    }

    /// BG01 0…262 with the band 0…107, tackle box and "Your tackle, tested."
    private func hero(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ArtImage(art: .bg01, mode: .fill)
                .frame(width: width, height: 262)
                .offset(y: -47)
                .frame(width: width, height: 215, alignment: .top)
                .clipped()
            Palette.background.frame(width: width, height: 60)
            Text("My Lures")
                .font(.avenir(27, .heavy))
                .foregroundColor(Palette.ink)
                .offset(x: 22, y: 14)
                .accessibilityAddTraits(.isHeader)
            IconButton(icon: "icon_plus", size: 30, label: "Add Lure") {
                router.push(.lureEditor(nil))
            }
            .offset(x: width - 61, y: 8)
            ArtImage(art: .p01)
                .frame(width: 141, height: 138)
                .offset(x: width - 161, y: 60)
            VStack(alignment: .leading, spacing: -3.8) {
                Text("Your tackle,")
                Text("tested.")
            }
            .font(.avenir(24, .heavy))
            .foregroundColor(Palette.ink)
            .offset(x: 23, y: 81)
            .accessibilityElement(children: .combine)
        }
        .frame(width: width, height: 212, alignment: .topLeading)
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldTextInput(label: "SEARCH", placeholder: "Search lures", text: $query, submitLabel: .search)
                .focused($searchFocused)
                .padding(.horizontal, Metrics.margin)
            Group {
                if sizeCategory.isAccessibilityCategory {
                    // Large text: chips keep their full labels and scroll sideways.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) { categoryChips(spaced: false) }
                            .padding(.horizontal, Metrics.margin)
                    }
                } else {
                    HStack(spacing: 0) { categoryChips(spaced: true) }
                        .padding(.horizontal, Metrics.margin)
                }
            }
            .padding(.top, 13 - 5)
            .padding(.bottom, -5)
        }
    }

    @ViewBuilder
    private func categoryChips(spaced: Bool) -> some View {
        ForEach(Array(LureCategory.allCases.enumerated()), id: \.element.id) { index, item in
            if spaced && index > 0 { Spacer(minLength: 6) }
            Button { category = item } label: {
                ChipLabel(title: item.title, selected: category == item)
                    .fixedSize()
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityAddTraits(category == item ? [.isButton, .isSelected] : .isButton)
        }
    }

    /// Shown while the search field is focused so typing is never interrupted.
    private var noResults: some View {
        VStack(spacing: 6) {
            Text("No matching lures")
                .font(.avenir(18, .heavy))
                .foregroundColor(Palette.ink)
            Text("Try a different name or clear the filters.")
                .font(.avenir(15, .medium))
                .foregroundColor(Palette.secondary)
                .multilineTextAlignment(.center)
            LinkButton(title: "Clear Filters", size: 16) {
                query = ""
                category = .all
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.margin)
        .padding(.top, 24)
    }

    private var activeFilterSummary: String? {
        var active: [String] = []
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { active.append("“\(trimmed)”") }
        if category != .all { active.append(category.title) }
        return active.isEmpty ? nil : "Search: " + active.joined(separator: " · ")
    }
}
