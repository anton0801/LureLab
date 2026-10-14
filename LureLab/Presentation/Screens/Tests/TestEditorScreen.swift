import SwiftUI
import UIKit

/// Screens 13 (Log a Test), 40 (Form Validation), 39 (Choose Lure), 14 (Conditions), 38 and 35 dialogs.
struct TestEditorScreen: View {
    let mode: TestEditorMode
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @StateObject private var form = TestFormModel()
    @FocusState private var focused: FormField?
    @Environment(\.haptics) private var haptics
    @Environment(\.lureReduceMotion) private var reduceMotion

    @State private var showPicker = false
    @State private var showConditions = false
    @State private var showDiscard = false
    @State private var showDatePicker = false
    @State private var editingCount: CountMetric?

    private var lure: Lure? { model.lure(form.lureID) }

    var body: some View {
        ScrollViewReader { scroll in
            LightScreen {
                ScreenHeader(title: form.isEditing ? "Edit Test" : "Log a Test", onBack: back) {
                    DraftChip(title: form.isEditing ? "Editing" : "Draft")
                }
                formBody
            } bottom: {
                GoldButton(title: "Save Test", isLoading: form.isSaving) { save(scroll: scroll) }
            }
        }
        .onAppear {
            form.load(mode: mode, model: model)
            #if DEBUG
            switch DebugScenario.name {
            case "14": showConditions = true
            case "39": showPicker = true
            case "38": showDiscard = true
            case "35": form.saveFailed = true
            case "40": _ = form.validate(model: model)
            default: break
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if form.isDirty, let draft = form.draft(now: model.now) { model.saveDraft(draft) }
        }
        .onChange(of: form.bites) { _ in form.revalidateCounts() }
        .onChange(of: form.catches) { _ in form.revalidateCounts() }
        .localPush(isPresented: showPicker) {
            LurePickerView(mode: .single, selected: form.lureID.map { [$0] } ?? [], onDone: { ids in
                form.lureID = ids.first
                form.issues.removeAll { $0.field == .lure }
                showPicker = false
            }, onCancel: { showPicker = false })
        }
        .localPush(isPresented: showConditions) {
            TestConditionsView(form: form) { showConditions = false }
        }
        .dialog(isPresented: editingCount != nil) {
            if let metric = editingCount {
                CountInputDialog(metric: metric, value: metric == .bites ? form.bites : form.catches) { result in
                    if let result {
                        if metric == .bites { form.bites = result.value } else { form.catches = result.value }
                    }
                    editingCount = nil
                }
            }
        }
        .dialog(isPresented: showDiscard) { discardDialog }
        .dialog(isPresented: form.saveFailed) { saveErrorDialog }
    }

    // MARK: Form

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            lureCard
                .id(FormField.lure)
                .padding(.top, 23)
            inlineError(.lure)

            FieldTextInput(label: "PLACE *", placeholder: "Where did you fish?", text: $form.placeName,
                           isError: form.issue(.place) != nil, characterLimit: TestEntry.Limits.place.upperBound)
                .focused($focused, equals: .place)
                .id(FormField.place)
                .padding(.top, 18)
            inlineError(.place)

            dateField
                .id(FormField.date)
                .padding(.top, 11)
            inlineError(.date)

            FieldTextInput(label: "DURATION · MINUTES *", placeholder: "Enter duration", text: $form.durationText,
                           keyboard: .numberPad, isError: form.issue(.duration) != nil, characterLimit: 4)
                .focused($focused, equals: .duration)
                .id(FormField.duration)
                .padding(.top, 11)

            if let message = form.issue(.duration) {
                ErrorText(message: message)
                    .padding(.leading, 2)
                    .padding(.top, 18)
            } else {
                Text("What happened?")
                    .font(.avenir(21, .bold))
                    .foregroundColor(Palette.ink)
                    .padding(.leading, 2)
                    .padding(.top, 10)
                    .accessibilityAddTraits(.isHeader)
            }

            CountStepperRow(metric: .bites, value: form.bites,
                            onDecrement: { form.bites = CountStepper.decrement(form.bites) },
                            onIncrement: { form.bites = CountStepper.increment(form.bites) },
                            onEditValue: { Keyboard.dismiss(); editingCount = .bites })
                .id(FormField.bites)
                .padding(.top, form.issue(.duration) == nil ? 9.3 : 12.2)
            CountStepperRow(metric: .catches, value: form.catches,
                            onDecrement: { form.catches = CountStepper.decrement(form.catches) },
                            onIncrement: { form.catches = CountStepper.increment(form.catches) },
                            onEditValue: { Keyboard.dismiss(); editingCount = .catches })
                .id(FormField.catches)
                .padding(.top, 7)

            Group {
                if let message = form.issue(.catches) ?? form.issue(.bites) {
                    ErrorText(message: message, weight: .demiBold)
                } else {
                    Text("Unknown? Leave counts empty. Zero is valid.")
                        .font(.avenir(13, .demiBold))
                        .foregroundColor(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, 2)
            .padding(.top, 13)

            NavRow(icon: "icon_water", title: "Conditions & Notes") {
                Keyboard.dismiss()
                showConditions = true
            }
            .padding(.top, 14.2)
            if let message = form.issue(.weatherNote) ?? form.issue(.testNotes) {
                ErrorText(message: message).padding(.top, 6).padding(.leading, 2)
            }
        }
        .padding(.horizontal, Metrics.margin)
    }

    private var lureCard: some View {
        Button {
            Keyboard.dismiss()
            showPicker = true
        } label: {
            HStack(alignment: .top, spacing: 0) {
                PhotoThumb(path: lure?.photoPath, size: 54)
                    .padding(.leading, 11)
                    .padding(.top, 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(lure?.name ?? "Choose a lure")
                        .font(.avenir(18, .heavy))
                        .foregroundColor(lure == nil ? Palette.secondary : Palette.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let lure, lure.isArchived {
                        Text("Archived lure")
                            .font(.avenir(13, .bold))
                            .foregroundColor(Palette.secondary)
                    }
                    Text(lure == nil ? "Choose ›" : "Change ›")
                        .font(.avenir(14, .bold))
                        .foregroundColor(Palette.sea)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 6.4)
                        .padding(.bottom, 14.9)
                }
                .padding(.leading, 13)
                .padding(.trailing, 23)
                .padding(.top, 13)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .lureCard(stroke: form.issue(.lure) != nil ? Palette.error : Palette.cardStroke, lineWidth: form.issue(.lure) != nil ? 2 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(lure.map { "Lure: \($0.name)" } ?? "No lure chosen"))
        .accessibilityHint(Text("Opens the lure list"))
    }

    private var dateField: some View {
        VStack(spacing: 8) {
            Button {
                Keyboard.dismiss()
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showDatePicker.toggle() }
            } label: {
                FieldBox(label: "DATE *", isError: form.issue(.date) != nil) {
                    Text(Format.dateAndTime(form.occurredAt))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Date, \(Format.dateAndTime(form.occurredAt))"))
            .accessibilityHint(Text(showDatePicker ? "Hides the calendar" : "Shows a calendar"))

            if showDatePicker {
                VStack(spacing: 6) {
                    DatePicker("Date and time", selection: Binding(get: { form.occurredAt }, set: { form.occurredAt = TestFormModel.minute($0) }),
                               in: ...model.now, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .tint(Palette.sea)
                        .labelsHidden()
                    LinkButton(title: "Done", size: 16) {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showDatePicker = false }
                        form.issues.removeAll { $0.field == .date }
                    }
                }
                .padding(12)
                .lureCard()
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func inlineError(_ field: FormField) -> some View {
        if let message = form.issue(field) {
            ErrorText(message: message).padding(.top, 6).padding(.leading, 2)
        }
    }

    // MARK: Dialogs

    private var discardDialog: some View {
        ActionDialog(icon: "icon_journal", title: "Keep This Draft?", message: "You have changes that have not been saved.", actions: [
            DialogAction(title: "Keep Editing", style: .primary) { showDiscard = false },
            DialogAction(title: "Save Draft and Leave") {
                if let draft = form.draft(now: model.now) { model.saveDraft(draft) }
                showDiscard = false
                router.pop()
            },
            DialogAction(title: "Discard Changes") {
                model.deleteDraft(form.id)
                showDiscard = false
                router.pop()
            }
        ], messageToActions: 45, bottomPadding: 42)
    }

    private var saveErrorDialog: some View {
        ActionDialog(icon: "icon_warning", title: "Could Not Save", message: "Your draft is still here. Free some storage and try again.", actions: [
            DialogAction(title: "Try Again", style: .primary) {
                form.saveFailed = false
                save(scroll: nil)
            },
            DialogAction(title: "Keep Editing") { form.saveFailed = false }
        ], messageToActions: 45)
    }

    // MARK: Actions

    private func back() {
        Keyboard.dismiss()
        if form.isDirty { showDiscard = true } else { router.pop() }
    }

    private func save(scroll: ScrollViewProxy?) {
        guard !form.isSaving else { return }
        Keyboard.dismiss()
        guard let fields = form.validate(model: model) else {
            haptics.warning()
            if let first = form.issues.first {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { scroll?.scrollTo(first.field, anchor: .center) }
                if [.place, .duration].contains(first.field) { focused = first.field }
                Accessibility.announce(first.message)
            }
            return
        }
        form.isSaving = true
        do {
            let result = try model.saveTest(id: form.id, fields: fields)
            // Stays "saving" while the screen leaves, so a second tap cannot resubmit.
            haptics.success()
            if form.isEditing {
                router.pop()
            } else {
                router.replaceTop(with: .testSaved(TestSavedSummary(testID: result.test.id, capsule: result.capsule)))
            }
        } catch {
            form.isSaving = false
            if let draft = form.draft(now: model.now) { model.saveDraft(draft) }
            haptics.warning()
            form.saveFailed = true
        }
    }
}

/// Numeric entry for Bites / Catches with an explicit "Not Recorded".
struct CountInputDialog: View {
    struct Result { let value: Int? }

    let metric: CountMetric
    let onFinish: (Result?) -> Void
    @State private var text: String
    @State private var error: String?
    @FocusState private var focused: Bool

    init(metric: CountMetric, value: Int?, onFinish: @escaping (Result?) -> Void) {
        self.metric = metric
        self.onFinish = onFinish
        _text = State(initialValue: value.map(String.init) ?? "")
    }

    var body: some View {
        ModalDialog(icon: "icon_fish", title: metric.title, message: "Type a whole number from 0 to 9999, or mark it as not recorded.", messageToActions: 18, bottomPadding: 29) {
            FieldTextInput(label: metric.title.uppercased(), placeholder: "Not recorded", text: $text, keyboard: .numberPad,
                           isError: error != nil, characterLimit: 4, submitLabel: .done)
                .focused($focused)
            if let error {
                ErrorText(message: error).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
            }
            GoldButton(title: "Save") {
                switch DecimalInput.parseInt(text) {
                case let .some(.some(value)) where TestEntry.Limits.count.contains(value):
                    onFinish(Result(value: value))
                case .some(.none):
                    onFinish(Result(value: nil))
                default:
                    error = "Enter a whole number from 0 to 9999."
                }
            }
            .padding(.top, 14)
            SurfaceButton(title: "Not Recorded") { onFinish(Result(value: nil)) }
                .padding(.top, 2)
            SurfaceButton(title: "Cancel") { onFinish(nil) }
                .padding(.top, 6)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { focused = true } }
    }
}

/// Screen 14: optional manual observations. Done applies to the form; Back leaves the form unchanged.
struct TestConditionsView: View {
    @ObservedObject var form: TestFormModel
    let onClose: () -> Void
    @State private var waterType: WaterType?
    @State private var clarity: WaterClarity?
    @State private var retrieve: RetrieveStyle?
    @State private var weatherNote: String
    @State private var notes: String

    init(form: TestFormModel, onClose: @escaping () -> Void) {
        self.form = form
        self.onClose = onClose
        _waterType = State(initialValue: form.waterType)
        _clarity = State(initialValue: form.clarity)
        _retrieve = State(initialValue: form.retrieve)
        _weatherNote = State(initialValue: form.weatherNote)
        _notes = State(initialValue: form.notes)
    }

    var body: some View {
        LightScreen {
            ScreenHeader(title: "Conditions & Notes", subtitle: "Optional observations from this test.") {
                Keyboard.dismiss()
                onClose()
            }
            VStack(alignment: .leading, spacing: 0) {
                OptionField(label: "WATER TYPE", value: $waterType, options: WaterType.allCases, title: \.title)
                    .padding(.top, 21.5)
                OptionField(label: "WATER CLARITY", value: $clarity, options: WaterClarity.allCases, title: \.title)
                    .padding(.top, 12)
                OptionField(label: "RETRIEVE", value: $retrieve, options: RetrieveStyle.allCases, title: \.listTitle)
                    .padding(.top, 12)
                FieldTextInput(label: "WEATHER NOTE", placeholder: "Not recorded", text: $weatherNote,
                               characterLimit: TestEntry.Limits.weatherNote)
                    .padding(.top, 12)
                NotesCard(label: "NOTES", placeholder: "What did you notice?", text: $notes, limit: TestEntry.Limits.notes, minHeight: 185)
                    .padding(.top, 12)
                HStack {
                    Spacer()
                    LinkButton(title: "Clear", size: 16, weight: .demiBold) {
                        waterType = nil
                        clarity = nil
                        retrieve = nil
                        weatherNote = ""
                        Accessibility.announce("Conditions cleared")
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 17)
            }
            .padding(.horizontal, Metrics.margin)
        } bottom: {
            GoldButton(title: "Done") {
                Keyboard.dismiss()
                form.waterType = waterType
                form.clarity = clarity
                form.retrieve = retrieve
                form.weatherNote = weatherNote
                form.notes = notes
                onClose()
            }
        }
    }
}

/// Field that opens a menu of enum options plus "Not recorded" (stored as nil).
struct OptionField<Option: Hashable>: View {
    let label: String
    @Binding var value: Option?
    let options: [Option]
    let title: KeyPath<Option, String>

    var body: some View {
        Menu {
            Button { value = nil } label: {
                if value == nil { Label("Not recorded", systemImage: "checkmark") } else { Text("Not recorded") }
            }
            ForEach(options, id: \.self) { option in
                Button { value = option } label: {
                    if value == option { Label(option[keyPath: title], systemImage: "checkmark") } else { Text(option[keyPath: title]) }
                }
            }
        } label: {
            FieldBox(label: label) {
                Text(value.map { $0[keyPath: title] } ?? "Not recorded")
                    .foregroundColor(value == nil ? Palette.secondary : Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityLabel(Text("\(label.capitalized), \(value.map { $0[keyPath: title] } ?? "not recorded")"))
    }
}
