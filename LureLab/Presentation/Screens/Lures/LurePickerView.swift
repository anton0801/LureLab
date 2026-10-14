import SwiftUI

/// Screen 39: choose one active lure for a test, or up to two for Compare. Returns IDs to the caller.
struct LurePickerView: View {
    enum Mode {
        case single
        case pair
    }

    let mode: Mode
    let onDone: ([UUID]) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var model: AppModel
    @Environment(\.haptics) private var haptics
    @State private var selection: [UUID]
    @State private var query = ""
    @State private var showAddLure = false
    @State private var limitMessage = false

    init(mode: Mode, selected: [UUID], onDone: @escaping ([UUID]) -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onDone = onDone
        self.onCancel = onCancel
        _selection = State(initialValue: selected)
    }

    private var lures: [Lure] {
        model.activeLures.filter { lureMatches($0, query: query) }
    }

    var body: some View {
        LightScreen {
            ScreenHeader(title: "Choose Lure",
                         subtitle: mode == .single ? "Choose a lure for this test." : "Choose two lures to compare.",
                         onBack: onCancel) {
                IconButton(icon: "icon_plus", size: 30, label: "Add Lure") { showAddLure = true }
                    .padding(.trailing, 17)
                    .padding(.top, 1)
            }
            FieldTextInput(label: "SEARCH", placeholder: "Search lures", text: $query, submitLabel: .search)
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 20.5)

            if model.activeLures.isEmpty {
                VStack(spacing: 14) {
                    Text("No active lures yet")
                        .font(.avenir(21, .heavy))
                        .foregroundColor(Palette.ink)
                    Text("Add a lure to use it in a test.")
                        .font(.avenir(16, .medium))
                        .foregroundColor(Palette.secondary)
                    LinkButton(title: "+ Add Lure") { showAddLure = true }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if lures.isEmpty {
                Text("No matching lures. Try a different name.")
                    .font(.avenir(16, .medium))
                    .foregroundColor(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            } else {
                VStack(spacing: 15) {
                    ForEach(lures) { lure in
                        let isSelected = selection.contains(lure.id)
                        Button { toggle(lure.id) } label: {
                            LureCardRow(lure: lure,
                                        meta: Format.lureMeta(lure, units: model.settings.units),
                                        status: isSelected ? "Selected" : Format.tests(model.testCount(for: lure.id))) {
                                UIIcon(name: isSelected ? "icon_check" : "icon_chevron", size: 23)
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 25)
            }
            if limitMessage {
                Text("You can compare two lures at a time. Deselect one first.")
                    .font(.avenir(13, .bold))
                    .foregroundColor(Palette.error)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
            }
        } bottom: {
            GoldButton(title: "Done", isEnabled: !selection.isEmpty) { onDone(selection) }
        }
        .localPush(isPresented: showAddLure) {
            LureEditorScreen(lureID: nil) { lure in
                showAddLure = false
                if let lure { add(lure.id) }
            }
        }
    }

    private func toggle(_ id: UUID) {
        haptics.tap()
        limitMessage = false
        switch mode {
        case .single:
            selection = [id]
        case .pair:
            if let index = selection.firstIndex(of: id) {
                selection.remove(at: index)
            } else if selection.count < 2 {
                selection.append(id)
            } else {
                limitMessage = true
                Accessibility.announce("You can compare two lures at a time.")
            }
        }
    }

    private func add(_ id: UUID) {
        switch mode {
        case .single: selection = [id]
        case .pair: if selection.count < 2 { selection.append(id) }
        }
    }
}

/// Screen 36: archived lures keep their history; Restore returns the selected lure to the catalogue.
struct ArchivedLuresView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @Environment(\.haptics) private var haptics
    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var errorMessage: String?

    private var lures: [Lure] { model.archivedLures.filter { lureMatches($0, query: query) } }

    private var selected: Lure? {
        if let selectedID, let lure = lures.first(where: { $0.id == selectedID }) { return lure }
        return lures.first
    }

    var body: some View {
        LightScreen {
            ScreenHeader(title: "Archived Lures", subtitle: "Archived items keep their test history.", onBack: { router.pop() })
            if model.archivedLures.isEmpty {
                VStack(spacing: 12) {
                    ArtImage(art: .p01).frame(width: 140, height: 148)
                    Text("Nothing archived")
                        .font(.avenir(24, .heavy))
                        .foregroundColor(Palette.ink)
                    Text("Archive a lure from its detail page to hide it from new tests.")
                        .font(.avenir(16, .medium))
                        .foregroundColor(Palette.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 290)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                FieldTextInput(label: "SEARCH", placeholder: "Search lures", text: $query, submitLabel: .search)
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 20.5)
                VStack(spacing: 15) {
                    ForEach(lures) { lure in
                        let count = model.testCount(for: lure.id)
                        HStack(spacing: 0) {
                            Button { selectedID = lure.id } label: {
                                LureCardRow(lure: lure,
                                            meta: Format.lureMeta(lure, units: model.settings.units),
                                            status: "Archived · \(Format.count(count, "test", "tests"))") {
                                    Color.clear.frame(width: 23, height: 23)
                                }
                            }
                            .buttonStyle(PressableButtonStyle())
                            .accessibilityAddTraits(selected?.id == lure.id ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint(Text("Selects this lure to restore"))
                        }
                        .overlay(alignment: .topTrailing) {
                            IconButton(icon: "icon_chevron", size: 23, label: "Open \(lure.name)") {
                                router.push(.lureDetail(lure.id))
                            }
                            .padding(.top, 25)
                            .padding(.trailing, 2)
                        }
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 25)
            }
        } bottom: {
            if let selected {
                GoldButton(title: "Restore \(selected.name)") { restore(selected) }
            }
        }
        .alert(item: Binding(get: { errorMessage.map(AlertText.init) }, set: { errorMessage = $0?.text })) { message in
            Alert(title: Text("Could not restore"), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    private func restore(_ lure: Lure) {
        do {
            try model.restoreLure(lure.id)
            haptics.success()
            Accessibility.announce("\(lure.name) restored to My Lures")
            selectedID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
