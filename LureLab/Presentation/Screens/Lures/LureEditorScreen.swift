import SwiftUI
import UIKit

/// Form state for Add / Edit Lure (11, 12). One UUID per creation keeps Save/Retry idempotent.
@MainActor
final class LureFormModel: ObservableObject {
    @Published var name = ""
    @Published var type: LureType?
    @Published var lengthText = ""
    @Published var weightText = ""
    @Published var color = ""
    @Published var brand = ""
    @Published var notes = ""
    @Published var photo: PhotoChange = .unchanged
    @Published var previewImage: UIImage?
    @Published var issues: [ValidationIssue] = []
    @Published var isSaving = false
    @Published var saveFailed = false

    private(set) var id = UUID()
    private(set) var existing: Lure?
    private(set) var loaded = false
    private var initial = LureDraftPayload(isEditing: false, name: "", type: nil, lengthText: "", weightText: "", color: "", brand: "", notes: "")
    private var lengthInitialText = ""
    private var weightInitialText = ""
    private(set) var units: UnitSystem = .metric

    var isEditing: Bool { existing != nil }

    var payload: LureDraftPayload {
        LureDraftPayload(units: units, isEditing: isEditing, name: name, type: type, lengthText: lengthText, weightText: weightText,
                         color: color, brand: brand, notes: notes)
    }

    var isDirty: Bool { payload != initial || photo != .unchanged }

    var currentPhotoPath: String? {
        switch photo {
        case .unchanged: return existing?.photoPath
        case .removed, .replaced: return nil
        }
    }

    var hasPhoto: Bool {
        if case .replaced = photo { return true }
        return currentPhotoPath != nil
    }

    func load(lureID: UUID?, model: AppModel) {
        guard !loaded else { return }
        loaded = true
        units = model.settings.units
        if let lureID, let lure = model.lure(lureID) {
            existing = lure
            id = lure.id
            name = lure.name
            type = lure.type
            lengthText = lure.lengthCm.map { UnitMath.lengthText($0, units: units) } ?? ""
            weightText = lure.weightG.map { UnitMath.weightText($0, units: units) } ?? ""
            color = lure.color ?? ""
            brand = lure.brand ?? ""
            notes = lure.notes
        }
        lengthInitialText = lengthText
        weightInitialText = weightText
        initial = payload
        // Restore a saved draft for this lure (or for a new lure).
        let draft = model.drafts
            .filter { $0.kind == .lure }
            // A new-lure draft whose lure was meanwhile saved is stale and must not overwrite it.
            .filter { existing == nil ? model.lure($0.id) == nil : $0.id == id }
            .max { $0.updatedAt < $1.updatedAt }
        if let draft, let saved = try? JSONDecoder().decode(LureDraftPayload.self, from: draft.payload), saved.isEditing == isEditing {
            id = draft.id
            name = saved.name
            type = saved.type
            let savedUnits = saved.units ?? units
            lengthText = Self.convert(saved.lengthText, from: savedUnits, to: units, toCanonical: UnitMath.lengthToCentimetres,
                                      display: { UnitMath.lengthText($0, units: $1) })
            weightText = Self.convert(saved.weightText, from: savedUnits, to: units, toCanonical: UnitMath.weightToGrams,
                                      display: { UnitMath.weightText($0, units: $1) })
            color = saved.color
            brand = saved.brand
            notes = saved.notes
        }
    }

    /// Re-expresses a draft measurement typed in other units; unparseable text is kept for validation.
    private static func convert(_ text: String, from: UnitSystem, to: UnitSystem,
                                toCanonical: (Decimal, UnitSystem) -> Decimal,
                                display: (Decimal, UnitSystem) -> String) -> String {
        guard from != to, case let .value(value) = DecimalInput.parse(text) else { return text }
        return display(toCanonical(value, from), to)
    }

    func issue(_ field: FormField) -> String? { issues.first { $0.field == field }?.message }

    func validate() -> ValidatedLureFields? {
        let input = LureInput(
            name: name,
            type: type,
            length: MeasurementInput(text: lengthText, initialText: lengthInitialText, initialCanonical: existing?.lengthCm),
            weight: MeasurementInput(text: weightText, initialText: weightInitialText, initialCanonical: existing?.weightG),
            color: color, brand: brand, notes: notes, units: units)
        let result = LureValidator.validate(input)
        issues = result.issues
        return result.value
    }

    func draft(now: Date) -> Draft? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return Draft(id: id, kind: .lure, payload: data, updatedAt: now)
    }
}

/// Screens 11 (Add Lure), 12 (More Details, local push), 41 (Photo Source), 38 (Unsaved), 35 (Save Error).
struct LureEditorScreen: View {
    let lureID: UUID?
    /// When presented from another form (Choose Lure → Add Lure), results are returned here instead of navigating.
    var onFinished: ((Lure?) -> Void)?

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @StateObject private var form = LureFormModel()
    @FocusState private var focused: FormField?
    @Environment(\.haptics) private var haptics

    @State private var showMore = false
    @State private var showPhotoDialog = false
    @State private var showDiscard = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var cameraMessage: String?

    var body: some View {
        LightScreen {
            ScreenHeader(title: form.isEditing ? "Edit Lure" : "Add Lure", subtitle: "A photo is optional.", onBack: back)
            photoRow
                .padding(.leading, Metrics.margin)
                .padding(.top, 17.5)
            fields
        } bottom: {
            GoldButton(title: "Save Lure", isLoading: form.isSaving, action: save)
        }
        .onAppear {
            form.load(lureID: lureID, model: model)
            #if DEBUG
            switch DebugScenario.name {
            case "12": showMore = true
            case "41": showPhotoDialog = true
            default: break
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if form.isDirty, let draft = form.draft(now: model.now) { model.saveDraft(draft) }
        }
        .localPush(isPresented: showMore) {
            LureMoreDetailsView(form: form) { showMore = false }
        }
        .dialog(isPresented: showPhotoDialog) { photoDialog }
        .dialog(isPresented: showDiscard) { discardDialog }
        .dialog(isPresented: form.saveFailed) { saveErrorDialog }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker { data in
                showLibrary = false
                if let data { applyPhoto(data) }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                if let data { applyPhoto(data) }
            }
            .ignoresSafeArea()
        }
        .alert(item: Binding(get: { cameraMessage.map(AlertText.init) }, set: { cameraMessage = $0?.text })) { message in
            Alert(title: Text("Camera unavailable"), message: Text(message.text),
                  primaryButton: .default(Text("Choose Photo")) { showLibrary = true },
                  secondaryButton: .cancel())
        }
    }

    // MARK: Sections

    private var photoRow: some View {
        HStack(spacing: 16) {
            Group {
                if let preview = form.previewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 86.5, height: 86.5)
                        .clipShape(RoundedRectangle(cornerRadius: 13.2, style: .continuous))
                        .frame(width: 88, height: 88)
                } else {
                    PhotoThumb(path: form.currentPhotoPath, size: 88)
                }
            }
            .accessibilityLabel(Text(form.hasPhoto ? "Lure photo" : "No photo"))
            Button {
                Keyboard.dismiss()
                showPhotoDialog = true
            } label: {
                Text(form.hasPhoto ? "Change Photo" : "Add Photo")
                    .font(.avenir(17, .bold))
                    .foregroundColor(Palette.sea)
                    .padding(.horizontal, 18)
                    .frame(minWidth: 179, minHeight: 43)
                    .background(Capsule().fill(Palette.photoChip))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldTextInput(label: "NAME *", placeholder: "Lure name", text: $form.name,
                           isError: form.issue(.name) != nil, characterLimit: Lure.Limits.name.upperBound)
                .focused($focused, equals: .name)
                .padding(.top, 19)
            fieldError(.name)

            Menu {
                ForEach(LureType.allCases) { item in
                    Button {
                        form.type = item
                    } label: {
                        if form.type == item { Label(item.title, systemImage: "checkmark") } else { Text(item.title) }
                    }
                }
            } label: {
                FieldBox(label: "TYPE *", isError: form.issue(.type) != nil) {
                    Text(form.type?.title ?? "Choose a type")
                        .foregroundColor(form.type == nil ? Palette.secondary.opacity(0.85) : Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .accessibilityLabel(Text("Type, \(form.type?.title ?? "not chosen")"))
            .padding(.top, 15)
            fieldError(.type)

            FieldTextInput(label: "LENGTH · \(UnitMath.lengthUnit(form.units).uppercased())", placeholder: "Optional",
                           text: $form.lengthText, keyboard: .decimalPad, isError: form.issue(.length) != nil, characterLimit: 8)
                .focused($focused, equals: .length)
                .padding(.top, 15)
            fieldError(.length)

            FieldTextInput(label: "WEIGHT · \(UnitMath.weightUnit(form.units).uppercased())", placeholder: "Optional",
                           text: $form.weightText, keyboard: .decimalPad, isError: form.issue(.weight) != nil, characterLimit: 8)
                .focused($focused, equals: .weight)
                .padding(.top, 15)
            fieldError(.weight)

            NavRow(icon: "icon_edit", title: "More Details") {
                Keyboard.dismiss()
                showMore = true
            }
            .padding(.top, 20)
            if let message = form.issue(.color) ?? form.issue(.brand) ?? form.issue(.lureNotes) {
                ErrorText(message: message).padding(.top, 6).padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, Metrics.margin)
    }

    @ViewBuilder
    private func fieldError(_ field: FormField) -> some View {
        if let message = form.issue(field) {
            ErrorText(message: message)
                .padding(.top, 6)
                .padding(.horizontal, 2)
        }
    }

    // MARK: Dialogs

    private var photoDialog: some View {
        var actions = [
            DialogAction(title: "Choose Photo", style: .primary) {
                showPhotoDialog = false
                showLibrary = true
            },
            DialogAction(title: "Take Photo") {
                showPhotoDialog = false
                CameraPicker.requestAccess { access in
                    switch access {
                    case .granted: showCamera = true
                    case .denied: cameraMessage = "Camera access is turned off for Lure Lab. You can choose a photo from your library instead, or allow the camera in Settings."
                    case .unavailable: cameraMessage = "This device has no available camera. You can choose a photo from your library instead."
                    }
                }
            }
        ]
        if form.hasPhoto {
            actions.append(DialogAction(title: "Remove Photo") {
                form.photo = .removed
                form.previewImage = nil
                showPhotoDialog = false
            })
        }
        actions.append(DialogAction(title: "Cancel") { showPhotoDialog = false })
        return ActionDialog(icon: "icon_photo", title: "Lure Photo", message: "Add a photo of your own tackle.",
                            actions: actions, messageToActions: 45, bottomPadding: 42)
    }

    private var discardDialog: some View {
        ActionDialog(icon: "icon_journal", title: "Keep This Draft?", message: "You have changes that have not been saved.", actions: [
            DialogAction(title: "Keep Editing", style: .primary) { showDiscard = false },
            DialogAction(title: "Save Draft and Leave") {
                if let draft = form.draft(now: model.now) { model.saveDraft(draft) }
                showDiscard = false
                exit(nil)
            },
            DialogAction(title: "Discard Changes") {
                model.deleteDraft(form.id)
                showDiscard = false
                exit(nil)
            }
        ], messageToActions: 45, bottomPadding: 42)
    }

    private var saveErrorDialog: some View {
        ActionDialog(icon: "icon_warning", title: "Could Not Save", message: "Your draft is still here. Free some storage and try again.", actions: [
            DialogAction(title: "Try Again", style: .primary) {
                form.saveFailed = false
                save()
            },
            DialogAction(title: "Keep Editing") { form.saveFailed = false }
        ], messageToActions: 45)
    }

    // MARK: Actions

    private func applyPhoto(_ data: Data) {
        guard let image = UIImage(data: data) else {
            cameraMessage = "This photo could not be read. Choose another photo."
            return
        }
        form.photo = .replaced(data)
        form.previewImage = image
    }

    private func back() {
        Keyboard.dismiss()
        if form.isDirty {
            showDiscard = true
        } else {
            exit(nil)
        }
    }

    private func exit(_ lure: Lure?) {
        if let onFinished {
            onFinished(lure)
        } else {
            router.pop()
        }
    }

    private func save() {
        guard !form.isSaving else { return }
        Keyboard.dismiss()
        guard let fields = form.validate() else {
            haptics.warning()
            focused = form.issues.first?.field
            if let first = form.issues.first { Accessibility.announce(first.message) }
            return
        }
        form.isSaving = true
        do {
            let lure = try model.saveLure(id: form.id, fields: fields, photo: form.photo)
            model.deleteDraft(form.id)
            form.isSaving = false
            haptics.success()
            if let onFinished {
                onFinished(lure)
            } else if lureID == nil {
                router.replaceTop(with: .lureDetail(lure.id))
            } else {
                router.pop()
            }
        } catch {
            form.isSaving = false
            if let draft = form.draft(now: model.now) { model.saveDraft(draft) }
            haptics.warning()
            form.saveFailed = true
        }
    }
}

struct AlertText: Identifiable {
    let text: String
    var id: String { text }
}

/// Screen 12: color, brand and notes. Done copies into the parent form; Back leaves it unchanged.
struct LureMoreDetailsView: View {
    @ObservedObject var form: LureFormModel
    let onClose: () -> Void
    @State private var color: String
    @State private var brand: String
    @State private var notes: String

    init(form: LureFormModel, onClose: @escaping () -> Void) {
        self.form = form
        self.onClose = onClose
        _color = State(initialValue: form.color)
        _brand = State(initialValue: form.brand)
        _notes = State(initialValue: form.notes)
    }

    var body: some View {
        LightScreen {
            ScreenHeader(title: "More Details", subtitle: "Optional notes for your own reference.") {
                Keyboard.dismiss()
                onClose()
            }
            VStack(alignment: .leading, spacing: 0) {
                FieldTextInput(label: "COLOR", placeholder: "Not recorded", text: $color, characterLimit: Lure.Limits.shortText)
                    .padding(.top, 34.5)
                FieldTextInput(label: "BRAND", placeholder: "Not recorded", text: $brand, characterLimit: Lure.Limits.shortText)
                    .padding(.top, 17)
                NotesCard(label: "NOTES", placeholder: "Anything worth remembering about this lure.", text: $notes,
                          limit: Lure.Limits.notes, minHeight: 224)
                    .padding(.top, 19)
            }
            .padding(.horizontal, Metrics.margin)
        } bottom: {
            GoldButton(title: "Done") {
                Keyboard.dismiss()
                form.color = color
                form.brand = brand
                form.notes = notes
                onClose()
            }
        }
    }
}

/// Multi-line notes card (label 12 pt, text 17 pt medium) with a character limit.
struct NotesCard: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let limit: Int
    var minHeight: CGFloat = 185

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label)
                    .font(.avenir(12, .bold))
                    .foregroundColor(Palette.secondary)
                Spacer()
                if text.count > limit - 200 {
                    Text("\(text.count)/\(limit)")
                        .font(.avenir(12, .bold))
                        .foregroundColor(text.count > limit ? Palette.error : Palette.secondary)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 15)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.avenir(17, .medium))
                    .foregroundColor(Palette.secondary)
                    .frame(minHeight: max(minHeight - 52, 80))
                    .accessibilityLabel(Text(label.capitalized))
                    .onChange(of: text) { newValue in
                        if newValue.count > limit { text = String(newValue.prefix(limit)) }
                    }
                if text.isEmpty {
                    Text(placeholder)
                        .font(.avenir(17, .medium))
                        .foregroundColor(Palette.secondary.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .lureCard()
    }
}
