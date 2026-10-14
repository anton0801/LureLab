import SwiftUI

/// Screens 17 (Compare) and 18 (Compare Empty). Describes recorded observations; never ranks or predicts.
struct CompareView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var period: ComparePeriod = .last30
    @State private var conditions = TestFilter()
    @State private var chosen: [UUID] = []
    @State private var showPicker = false

    /// Lures with at least one completed test (archived ones keep their history).
    private var luresWithTests: [Lure] {
        let ids = Set(model.tests.filter(\.completed).map(\.lureID))
        return model.lures.filter { ids.contains($0.id) }
    }

    /// Selected pair; defaults to the two most recently tested lures, active ones first.
    private var pair: [Lure] {
        let valid = chosen.compactMap { model.lure($0) }
        if valid.count == 2 { return valid }
        var result = valid
        for preferActive in [true, false] {
            for test in model.tests where result.count < 2 {
                guard !result.contains(where: { $0.id == test.lureID }), let lure = model.lure(test.lureID),
                      lure.isArchived != preferActive else { continue }
                result.append(lure)
            }
        }
        return result
    }

    private func filter(for lureIDs: Set<UUID>, metric: CountMetric?) -> TestFilter {
        var filter = conditions
        filter.period = period
        filter.lureIDs = lureIDs
        filter.requiredMetric = metric
        filter.searchText = ""
        return filter
    }

    private func summary(_ lure: Lure, _ metric: CountMetric) -> RateSummary {
        RateCalculator.summarize(filter(for: [lure.id], metric: nil).apply(to: model.tests, now: model.now), metric: metric)
    }

    var body: some View {
        Group {
            if luresWithTests.count < 2 {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ScreenHeader(title: "Compare")
                        EmptyStateView(art: .p02, title: "A little more to compare",
                                       message: "Save tests for two lures to compare your observations.",
                                       artTop: 110, buttonTitle: "Log a Test") {
                            if model.activeLures.isEmpty {
                                coordinator.open(.journal, stack: [.lureEditor(nil)])
                            } else {
                                coordinator.open(.journal, stack: [.testEditor(.new(lureID: nil))])
                            }
                        }
                        TabBarClearance()
                    }
                }
                .background(Palette.background.ignoresSafeArea())
            } else {
                comparison
            }
        }
        .preference(key: HidesTabBarKey.self, value: showPicker)
        .localPush(isPresented: showPicker) {
            // The picker lists active lures, so only those can be pre-selected (and deselected).
            LurePickerView(mode: .pair, selected: pair.filter { !$0.isArchived }.map(\.id), onDone: { ids in
                chosen = ids
                showPicker = false
            }, onCancel: { showPicker = false })
        }
    }

    private var comparison: some View {
        let lures = pair
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Compare", subtitle: "Your observations. Different conditions matter.")
                filterChips
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 16.5 - 5)
                luresCard(lures)
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 20 - 5)
                metricSection(.catches, lures: lures)
                    .padding(.top, 23)
                Text("Tap a metric to view its source tests.")
                    .font(.avenir(13, .demiBold))
                    .foregroundColor(Palette.secondary)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                metricSection(.bites, lures: lures)
                    .padding(.top, 24)
                TabBarClearance()
            }
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var filterChips: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(ComparePeriod.allCases) { item in
                    Button { period = item } label: {
                        if period == item { Label(item.title, systemImage: "checkmark") } else { Text(item.title) }
                    }
                }
            } label: {
                ChipLabel(title: period.title, selected: true, fillWidth: true)
                    .frame(minHeight: 44)
            }
            .frame(width: 153)
            .accessibilityLabel(Text("Period, \(period.title)"))

            Menu {
                ConditionMenuContent(filter: $conditions)
            } label: {
                ChipLabel(title: conditionsTitle, selected: conditions.hasConditionFilter, fillWidth: true)
                    .frame(minHeight: 44)
            }
            .accessibilityLabel(Text("Conditions, \(conditionsTitle)"))
        }
    }

    private var conditionsTitle: String {
        let parts = [conditions.waterType?.title, conditions.clarity?.title, conditions.retrieve?.title].compactMap { $0 }
        return parts.isEmpty ? "All conditions" : parts.joined(separator: " · ")
    }

    private func luresCard(_ lures: [Lure]) -> some View {
        Button { showPicker = true } label: {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4.4) {
                    ForEach(lures) { lure in
                        Text(lure.name)
                            .font(.avenir(18, .heavy))
                            .foregroundColor(Palette.ink)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 14)
                Spacer(minLength: 0)
                Text("Change ›")
                    .font(.avenir(14, .bold))
                    .foregroundColor(Palette.sea)
            }
            .padding(.leading, 15)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, minHeight: 87)
            .lureCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Comparing \(lures.map(\.name).joined(separator: " and "))"))
        .accessibilityHint(Text("Change lures"))
    }

    private func metricSection(_ metric: CountMetric, lures: [Lure]) -> some View {
        let summaries = lures.map { summary($0, metric) }
        let maxRate = summaries.compactMap(\.ratePerHour).max() ?? 0
        let colors = [Palette.sea, Palette.compareGold]
        let allIDs = Set(lures.map(\.id))
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(metric.perHourTitle)
                    .font(.avenir(23, .heavy))
                    .foregroundColor(Palette.ink)
                    .padding(.top, 14)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(zip(lures, summaries).enumerated()), id: \.element.0.id) { index, item in
                    Button {
                        router.push(.journal(filter(for: [item.0.id], metric: metric)))
                    } label: {
                        rateRow(lure: item.0, summary: item.1, maxRate: maxRate, color: colors[index % 2])
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, index == 0 ? 7.6 : 18)
                    .accessibilityHint(Text("Shows the source tests"))
                }
                Text("Includes tests with a recorded \(metric.singular) count.")
                    .font(.avenir(12, .demiBold))
                    .foregroundColor(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 28)
                    .padding(.bottom, 17.6)
            }
            .padding(.horizontal, 17)
            .frame(maxWidth: .infinity, minHeight: 235, alignment: .topLeading)
            .lureCard()

            Button { router.push(.journal(filter(for: allIDs, metric: metric))) } label: {
                ListRow(icon: "icon_journal", title: "Tests included",
                        value: summaries.map { String($0.includedTests) }.joined(separator: " / "))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 24)
            .accessibilityHint(Text("Shows the source tests"))

            Button { router.push(.journal(filter(for: allIDs, metric: metric))) } label: {
                ListRow(icon: "icon_clock", title: "Minutes included",
                        value: summaries.map { String($0.totalMinutes) }.joined(separator: " / "))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 12)
        }
        .padding(.horizontal, Metrics.margin)
    }

    private func rateRow(lure: Lure, summary: RateSummary, maxRate: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lure.name)
                .font(.avenir(14, .demiBold))
                .foregroundColor(Palette.secondary)
                .lineLimit(1)
            HStack(spacing: 8) {
                GeometryReader { proxy in
                    let fraction = maxRate > 0 ? (summary.ratePerHour ?? 0) / maxRate : 0
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color)
                        .frame(width: summary.ratePerHour == nil ? 0 : max(CGFloat(fraction) * proxy.size.width, summary.ratePerHour == 0 ? 0 : 8),
                               height: 19)
                }
                .frame(width: 190, height: 19)
                Spacer(minLength: 0)
                Text(Format.rate(summary.ratePerHour))
                    .font(summary.ratePerHour == nil ? .avenir(14, .demiBold) : .avenir(19, .heavy))
                    .foregroundColor(summary.ratePerHour == nil ? Palette.secondary : Palette.ink)
                    .lineLimit(1)
                    .padding(.trailing, 16)
            }
            .padding(.top, 5.9)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText(lure: lure, summary: summary)))
    }

    private func accessibilityText(lure: Lure, summary: RateSummary) -> String {
        guard let rate = summary.ratePerHour else { return "\(lure.name): not recorded" }
        return "\(lure.name): \(Format.rate(rate)) \(summary.metric.plural) per hour from \(Format.count(summary.includedTests, "test", "tests")), \(summary.totalMinutes) minutes"
    }
}
