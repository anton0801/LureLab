import SwiftUI

/// Screen 10: parameters and history of one lure. Archived lures open read-only with Restore.
struct LureDetailView: View {
    let lureID: UUID
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @Environment(\.haptics) private var haptics
    @State private var showArchiveOptions = false
    @State private var showDelete = false
    @State private var errorMessage: String?

    var body: some View {
        if let lure = model.lure(lureID) {
            content(lure)
        } else {
            LightScreen {
                ScreenHeader(title: "Lure", onBack: { router.pop() })
                Text("This lure is no longer in your catalogue.")
                    .font(.avenir(16, .medium))
                    .foregroundColor(Palette.secondary)
                    .padding(22)
            }
        }
    }

    private func content(_ lure: Lure) -> some View {
        let tests = model.tests(for: lure.id)
        let minutes = tests.reduce(0) { $0 + $1.durationMinutes }
        let units = model.settings.units
        return LightScreen(bottomPadding: 14) {
            ScreenHeader(title: lure.name, onBack: { router.pop() })

            PhotoThumb(path: lure.photoPath, size: 150)
                .frame(maxWidth: .infinity)
                .padding(.top, 39)
            if lure.photoPath == nil {
                Text("Your photo appears here")
                    .font(.avenir(13, .medium))
                    .foregroundColor(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            if lure.isArchived {
                Text("Archived \(Format.mediumDate(lure.archivedAt ?? model.now)) · read only")
                    .font(.avenir(13, .bold))
                    .foregroundColor(Palette.sea)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }

            HStack(spacing: 10) {
                ChipLabel(title: lure.type.title, selected: true, fillWidth: true)
                ChipLabel(title: lure.lengthCm.map { Format.length($0, units: units) } ?? "No length", fillWidth: true)
                ChipLabel(title: lure.weightG.map { Format.weight($0, units: units) } ?? "No weight", fillWidth: true)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 14.2)
            .accessibilityElement(children: .combine)

            historyCard(count: tests.count, minutes: minutes)
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 19)

            VStack(spacing: 13) {
                ForEach(tests) { test in
                    NavRow(icon: "icon_pin", title: test.placeName, value: Format.shortDate(test.occurredAt)) {
                        router.push(.testDetail(test.id))
                    }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, tests.isEmpty ? 0 : 20)

            actionLinks(lure, testCount: tests.count)
                .padding(.top, tests.isEmpty ? 12 : 19.6)

            detailsCard(lure, tests: tests)
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 12)
        } bottom: {
            if lure.isArchived {
                GoldButton(title: "Restore Lure") { restore(lure) }
            } else {
                GoldButton(title: "Log a Test") { router.push(.testEditor(.new(lureID: lure.id))) }
            }
        }
        .confirmationDialog("Archive \(lure.name)?", isPresented: $showArchiveOptions, titleVisibility: .visible) {
            Button("Archive Lure") { archive(lure) }
            if tests.isEmpty {
                Button("Delete Lure", role: .destructive) { showDelete = true }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(tests.isEmpty
                 ? "Archived lures are hidden when choosing a lure. A lure without tests can also be deleted."
                 : "Archived lures keep their test history and are hidden when choosing a lure.")
        }
        .dialog(isPresented: showDelete) {
            ActionDialog(icon: "icon_warning", title: "Delete \(lure.name)?",
                         message: "This lure has no tests. It and its photo will be removed from this device.",
                         actions: [
                            DialogAction(title: "Delete Lure", style: .danger) { delete(lure) },
                            DialogAction(title: "Cancel") { showDelete = false }
                         ], messageToActions: 45)
        }
        .alert(item: Binding(get: { errorMessage.map(AlertText.init) }, set: { errorMessage = $0?.text })) { message in
            Alert(title: Text("Something went wrong"), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    private func historyCard(count: Int, minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Test history")
                .font(.avenir(21, .heavy))
                .foregroundColor(Palette.ink)
                .padding(.top, 10)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Format.count(count, "test", "tests"))
                    .font(.avenir(27, .heavy))
                    .foregroundColor(Palette.ink)
                    .frame(minWidth: 145, alignment: .leading)
                Text(count == 0 ? "No tests yet" : "\(minutes) min recorded")
                    .font(.avenir(16, .demiBold))
                    .foregroundColor(Palette.secondary)
                    .offset(y: -2)
            }
            .padding(.top, 4.3)
            .padding(.bottom, 25)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
        .lureCard()
        .accessibilityElement(children: .combine)
    }

    private func actionLinks(_ lure: Lure, testCount: Int) -> some View {
        HStack {
            if lure.isArchived {
                if testCount == 0 {
                    LinkButton(title: "Delete", weight: .demiBold, color: Palette.error) { showDelete = true }
                }
                Spacer()
            } else {
                LinkButton(title: "Edit Lure") { router.push(.lureEditor(lure.id)) }
                Spacer()
                LinkButton(title: "Archive", weight: .demiBold, color: Palette.secondary) { showArchiveOptions = true }
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 25)
    }

    @ViewBuilder
    private func detailsCard(_ lure: Lure, tests: [TestEntry]) -> some View {
        let bites = RateCalculator.summarize(tests, metric: .bites)
        let catches = RateCalculator.summarize(tests, metric: .catches)
        let rows: [(String, String)] = [
            ("Color", lure.color ?? ""),
            ("Brand", lure.brand ?? ""),
            ("Bites recorded", bites.includedTests == 0 ? "" : "\(bites.totalCount) in \(bites.totalMinutes) min"),
            ("Catches recorded", catches.includedTests == 0 ? "" : "\(catches.totalCount) in \(catches.totalMinutes) min")
        ].filter { !$0.1.isEmpty }
        if !rows.isEmpty || !lure.notes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Details")
                    .font(.avenir(21, .heavy))
                    .foregroundColor(Palette.ink)
                ForEach(rows, id: \.0) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.0)
                            .font(.avenir(16, .demiBold))
                            .foregroundColor(Palette.ink)
                        Spacer(minLength: 12)
                        Text(row.1)
                            .font(.avenir(15, .demiBold))
                            .foregroundColor(Palette.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
                if !lure.notes.isEmpty {
                    Text(lure.notes)
                        .font(.avenir(16, .medium))
                        .foregroundColor(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lureCard()
        }
    }

    // MARK: Actions

    private func archive(_ lure: Lure) {
        do {
            try model.archiveLure(lure.id)
            haptics.success()
            router.replaceTop(with: .archived)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ lure: Lure) {
        do {
            try model.restoreLure(lure.id)
            haptics.success()
            Accessibility.announce("\(lure.name) restored")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ lure: Lure) {
        showDelete = false
        do {
            try model.deleteLure(lure.id)
            haptics.success()
            router.pop()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
