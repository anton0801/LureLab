import SwiftUI

/// Screens 06 (Test Journal) and 07 (Journal Empty). Accepts a filter so Compare opens exactly its source tests.
struct JournalView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @State private var filter: TestFilter

    init(initialFilter: TestFilter) {
        _filter = State(initialValue: initialFilter)
    }

    private var results: [TestEntry] { filter.apply(to: model.tests, now: model.now) }

    private var groups: [(day: Date, tests: [TestEntry])] {
        let calendar = Calendar.current
        var order: [Date] = []
        var buckets: [Date: [TestEntry]] = [:]
        for test in results {
            let day = calendar.startOfDay(for: test.occurredAt)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(test)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        if model.tests.isEmpty {
            LightScreen {
                ScreenHeader(title: "Test Journal", onBack: { router.pop() })
                EmptyStateView(art: .p02, title: "No tests yet", message: "Your first observation starts the journal.",
                               artTop: 110, buttonTitle: "Log a Test", action: logTest)
            }
        } else {
            LightScreen(bottomPadding: 50) {
                ScreenHeader(title: "Test Journal", subtitle: "Your observations, in your own words.", onBack: { router.pop() })
                FieldTextInput(label: "SEARCH", placeholder: "Search place or notes", text: $filter.searchText, submitLabel: .search)
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 19.5)
                filterBar
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 13 - 5)
                if let metric = filter.requiredMetric {
                    Text("Showing tests with a recorded \(metric.singular) count.")
                        .font(.avenir(13, .demiBold))
                        .foregroundColor(Palette.secondary)
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                }
                if groups.isEmpty {
                    VStack(spacing: 6) {
                        Text("No tests match these filters")
                            .font(.avenir(18, .heavy))
                            .foregroundColor(Palette.ink)
                        LinkButton(title: "Clear Filters", size: 16) { filter = TestFilter() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groups, id: \.day) { group in
                            Text(Format.groupHeader(group.day))
                                .font(.avenir(12, .heavy))
                                .foregroundColor(Palette.secondary)
                                .padding(.leading, 3)
                                .padding(.top, group.day == groups.first?.day ? 12 : 10)
                                .accessibilityAddTraits(.isHeader)
                            VStack(spacing: 10) {
                                ForEach(group.tests) { test in
                                    Button { router.push(.testDetail(test.id)) } label: {
                                        TestRow(test: test, lureName: model.displayLureName(for: test))
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
                            }
                            .padding(.top, 8.6)
                        }
                    }
                    .padding(.horizontal, Metrics.margin)
                }
            } bottom: {
                GoldButton(title: "+ Log a Test", action: logTest)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(ComparePeriod.allCases) { period in
                    Button { filter.period = period } label: {
                        if filter.period == period { Label(period.title, systemImage: "checkmark") } else { Text(period.title) }
                    }
                }
            } label: {
                ChipLabel(title: filter.period.title, selected: true, minWidth: 108)
                    .frame(minHeight: 44)
            }
            .accessibilityLabel(Text("Period, \(filter.period.title)"))

            Menu {
                Button { filter.lureIDs = [] } label: {
                    if filter.lureIDs.isEmpty { Label("All lures", systemImage: "checkmark") } else { Text("All lures") }
                }
                ForEach(model.lures.sorted { $0.name < $1.name }) { lure in
                    Button { filter.lureIDs = [lure.id] } label: {
                        if filter.lureIDs == [lure.id] { Label(lure.name, systemImage: "checkmark") } else { Text(lure.isArchived ? "\(lure.name) (archived)" : lure.name) }
                    }
                }
            } label: {
                ChipLabel(title: lureFilterTitle, selected: !filter.lureIDs.isEmpty, minWidth: 108)
                    .frame(maxWidth: 170)
                    .frame(minHeight: 44)
            }
            .accessibilityLabel(Text("Lures, \(lureFilterTitle)"))

            Spacer(minLength: 4)

            Menu {
                ConditionMenuContent(filter: $filter)
            } label: {
                UIIcon(name: "icon_filter", size: 29, color: filter.hasConditionFilter ? Palette.sea : Palette.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 10)
            .accessibilityLabel(Text(filter.hasConditionFilter ? "Conditions filter, active" : "Conditions filter"))
        }
    }

    private var lureFilterTitle: String {
        switch filter.lureIDs.count {
        case 0: return "All lures"
        case 1: return model.lure(filter.lureIDs.first)?.name ?? "1 lure"
        default: return "\(filter.lureIDs.count) lures"
        }
    }

    private func logTest() {
        if model.activeLures.isEmpty {
            router.push(.lureEditor(nil))
        } else {
            router.push(.testEditor(.new(lureID: nil)))
        }
    }
}

/// Water type / clarity / retrieve filter menu shared by Journal and Compare.
struct ConditionMenuContent: View {
    @Binding var filter: TestFilter

    var body: some View {
        Menu("Water type") {
            Button { filter.waterType = nil } label: { checked("Any", filter.waterType == nil) }
            ForEach(WaterType.allCases) { item in
                Button { filter.waterType = item } label: { checked(item.title, filter.waterType == item) }
            }
        }
        Menu("Water clarity") {
            Button { filter.clarity = nil } label: { checked("Any", filter.clarity == nil) }
            ForEach(WaterClarity.allCases) { item in
                Button { filter.clarity = item } label: { checked(item.title, filter.clarity == item) }
            }
        }
        Menu("Retrieve") {
            Button { filter.retrieve = nil } label: { checked("Any", filter.retrieve == nil) }
            ForEach(RetrieveStyle.allCases) { item in
                Button { filter.retrieve = item } label: { checked(item.title, filter.retrieve == item) }
            }
        }
        if filter.hasConditionFilter {
            Button("Clear conditions") {
                filter.waterType = nil
                filter.clarity = nil
                filter.retrieve = nil
            }
        }
    }

    @ViewBuilder
    private func checked(_ title: String, _ isOn: Bool) -> some View {
        if isOn { Label(title, systemImage: "checkmark") } else { Text(title) }
    }
}
