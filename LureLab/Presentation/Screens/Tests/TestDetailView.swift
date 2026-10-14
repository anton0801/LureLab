import SwiftUI

/// Screen 15: read, edit, repeat or delete one test.
struct TestDetailView: View {
    let testID: UUID
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.haptics) private var haptics
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var showDelete = false
    @State private var errorMessage: String?

    var body: some View {
        if let test = model.test(testID) {
            content(test)
        } else {
            LightScreen {
                ScreenHeader(title: "Test", onBack: { router.pop() })
                Text("This test was deleted.")
                    .font(.avenir(16, .medium))
                    .foregroundColor(Palette.secondary)
                    .padding(22)
            }
        }
    }

    private func subtitle(_ test: TestEntry) -> String {
        var text = "\(Format.mediumDate(test.occurredAt)) · \(test.lureNameSnapshot)"
        if let live = model.lure(test.lureID) {
            if live.name != test.lureNameSnapshot { text += " (now \(live.name))" }
            if live.isArchived { text += " · archived" }
        }
        return text
    }

    private func content(_ test: TestEntry) -> some View {
        LightScreen(bottomPadding: 15) {
            ScreenHeader(title: test.placeName, subtitle: subtitle(test), onBack: { router.pop() })
            statsCard(test)
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 27.5)
            VStack(spacing: 13) {
                ListRow(icon: "icon_water", title: "Water",
                        value: [test.waterType?.title, test.clarity?.title].compactMap { $0 }.joined(separator: " · ").nonEmpty ?? "Not recorded")
                ListRow(icon: "icon_lure", title: "Retrieve", value: test.retrieve?.title ?? "Not recorded")
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 24)
            notesCard(test)
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 15)
            HStack {
                LinkButton(title: "Edit Test") { router.push(.testEditor(.edit(test.id))) }
                Spacer()
                LinkButton(title: "Delete", weight: .demiBold, color: Palette.error) { showDelete = true }
            }
            .padding(.leading, 22)
            .padding(.trailing, 24)
            .padding(.top, 23.6)
        } bottom: {
            GoldButton(title: "Repeat This Test") { router.push(.testEditor(.repeatTest(test.id))) }
            SurfaceButton(title: "Back to Journal") {
                if router.popTo(where: { if case .journal = $0 { return true } else { return false } }) { return }
                if coordinator.tab == .journal {
                    router.popToRoot()
                } else {
                    router.popToRoot()
                    coordinator.open(.journal, stack: [.journal(TestFilter())])
                }
            }
            .padding(.top, 16)
        }
        .dialog(isPresented: showDelete) {
            ActionDialog(icon: "icon_warning", title: "Delete This Test?",
                         message: "\(test.placeName) on \(Format.mediumDate(test.occurredAt)) will be removed. Workshop rewards already given stay.",
                         actions: [
                            DialogAction(title: "Delete Test", style: .danger) { delete(test) },
                            DialogAction(title: "Cancel") { showDelete = false }
                         ], messageToActions: 26)
        }
        .alert(item: Binding(get: { errorMessage.map(AlertText.init) }, set: { errorMessage = $0?.text })) { message in
            Alert(title: Text("Could not delete"), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private func statsCard(_ test: TestEntry) -> some View {
        if sizeCategory.isAccessibilityCategory {
            // Large text: each value sits above its label, one per row.
            VStack(alignment: .leading, spacing: 14) {
                stat(value: "\(test.durationMinutes) min", label: "Duration", accessibility: "Duration \(test.durationMinutes) minutes")
                stat(value: test.bites.map(String.init) ?? "—", label: "Bites", accessibility: "Bites \(test.bites.map(String.init) ?? "not recorded")")
                stat(value: test.catches.map(String.init) ?? "—", label: "Catches", accessibility: "Catches \(test.catches.map(String.init) ?? "not recorded")")
            }
            .padding(21)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lureCard()
        } else {
            regularStatsCard(test)
        }
    }

    private func regularStatsCard(_ test: TestEntry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            stat(value: "\(test.durationMinutes) min", label: "Duration", accessibility: "Duration \(test.durationMinutes) minutes")
                .frame(width: 166, alignment: .leading)
            stat(value: test.bites.map(String.init) ?? "—", label: "Bites",
                 accessibility: "Bites \(test.bites.map(String.init) ?? "not recorded")")
                .frame(width: 85, alignment: .leading)
            stat(value: test.catches.map(String.init) ?? "—", label: "Catches",
                 accessibility: "Catches \(test.catches.map(String.init) ?? "not recorded")")
            Spacer(minLength: 0)
        }
        .padding(.leading, 21)
        .padding(.top, 15)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .lureCard()
    }

    private func stat(value: String, label: String, accessibility: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.avenir(30, .heavy))
                .foregroundColor(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.avenir(14, .demiBold))
                .foregroundColor(Palette.secondary)
                .padding(.top, 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibility))
    }

    private func notesCard(_ test: TestEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Field notes")
                .font(.avenir(21, .heavy))
                .foregroundColor(Palette.ink)
                .padding(.top, 14)
            Text(test.notes.isEmpty && test.weatherNote.isEmpty ? "No notes for this test." : test.notes)
                .font(.avenir(16, .medium))
                .foregroundColor(Palette.secondary)
                .lineSpacing(1.1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 240, alignment: .leading)
                .padding(.top, 12.3)
                .padding(.bottom, test.weatherNote.isEmpty ? 20 : 0)
            if !test.weatherNote.isEmpty {
                Text("Weather: \(test.weatherNote)")
                    .font(.avenir(16, .medium))
                    .foregroundColor(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, test.notes.isEmpty ? 0 : 6)
                    .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 143, alignment: .topLeading)
        .lureCard()
    }

    private func delete(_ test: TestEntry) {
        showDelete = false
        do {
            try model.deleteTest(test.id)
            haptics.success()
            Accessibility.announce("Test deleted")
            router.pop()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

/// Screen 16: confirms the commit and, only after it, reports the capsule outcome.
struct TestSavedView: View {
    let summary: TestSavedSummary
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var announced = false

    var body: some View {
        let test = model.test(summary.testID)
        LightScreen(bottomPadding: 17) {
            Text("Test Saved")
                .font(.avenir(27, .heavy))
                .foregroundColor(Palette.ink)
                .padding(.leading, 22)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)
            ArtImage(art: .c03)
                .frame(width: 170, height: 199)
                .frame(maxWidth: .infinity)
                .offset(x: 16)
                .padding(.top, 57.1)
            VStack(spacing: 0) {
                Text(test?.placeName ?? "Saved")
                    .font(.avenir(25, .heavy))
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 15)
                if let test {
                    Text(Format.durationAndCounts(test))
                        .font(.avenir(16, .medium))
                        .foregroundColor(Palette.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 9.9)
                        .padding(.bottom, 18)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 105, alignment: .top)
            .lureCard()
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 30)
            capsuleRow
                .padding(.horizontal, 30)
                .padding(.top, 32)
        } bottom: {
            GoldButton(title: "Back to Journal") {
                router.popToRoot()
                coordinator.open(.journal, stack: [])
            }
            SurfaceButton(title: "Open Workshop") {
                router.popToRoot()
                coordinator.open(.workshop, stack: [])
            }
            .padding(.top, 16)
        }
        .onAppear {
            guard !announced else { return }
            announced = true
            Accessibility.announce("Test saved. \(capsuleTitle).")
        }
    }

    private var capsuleTitle: String {
        switch summary.capsule {
        case .earned: return "1 capsule earned"
        case .notEligible: return "Next capsule available later"
        case .shelfFull: return "Capsule shelf is full"
        case .notApplicable: return ""
        }
    }

    private var capsuleSubtitle: String {
        switch summary.capsule {
        case .earned: return "Ready in your workshop"
        case let .notEligible(next):
            if let next { return "After \(Format.shortDateAndTime(next))" }
            return "Keep logging tests"
        case .shelfFull: return "Open Lucky Cast to use your \(Format.capsules(model.capsuleState.capsules))"
        case .notApplicable: return ""
        }
    }

    @ViewBuilder
    private var capsuleRow: some View {
        if summary.capsule != .notApplicable {
            HStack(alignment: .top, spacing: 20) {
                ArtImage(art: .s03)
                    .frame(width: 71, height: 65)
                    .opacity(summary.capsule == .earned ? 1 : 0.45)
                VStack(alignment: .leading, spacing: 0) {
                    Text(capsuleTitle)
                        .font(.avenir(20, .heavy))
                        .foregroundColor(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(capsuleSubtitle)
                        .font(.avenir(14, .demiBold))
                        .foregroundColor(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4.7)
                }
                .padding(.top, 6)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
