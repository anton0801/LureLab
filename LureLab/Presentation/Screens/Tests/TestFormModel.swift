import SwiftUI

/// Form state for Log a Test (13), Conditions (14) and validation (40).
@MainActor
final class TestFormModel: ObservableObject {
    @Published var lureID: UUID?
    @Published var placeName = ""
    @Published var occurredAt = Date()
    @Published var durationText = ""
    @Published var bites: Int?
    @Published var catches: Int?
    @Published var waterType: WaterType?
    @Published var clarity: WaterClarity?
    @Published var retrieve: RetrieveStyle?
    @Published var weatherNote = ""
    @Published var notes = ""
    @Published var issues: [ValidationIssue] = []
    @Published var isSaving = false
    @Published var saveFailed = false

    /// Stable id for this creation/edit: retries and double taps reuse it.
    private(set) var id = UUID()
    private(set) var isEditing = false
    private(set) var restoredFromDraft = false
    private(set) var loaded = false
    private var initial: TestDraftPayload?

    var payload: TestDraftPayload {
        TestDraftPayload(isEditing: isEditing, lureID: lureID, placeName: placeName, occurredAt: occurredAt,
                         durationText: durationText, bites: bites, catches: catches, waterType: waterType,
                         clarity: clarity, retrieve: retrieve, weatherNote: weatherNote, notes: notes)
    }

    var isDirty: Bool {
        guard let initial else { return false }
        return restoredFromDraft || payload != initial
    }

    func load(mode: TestEditorMode, model: AppModel) {
        guard !loaded else { return }
        loaded = true
        let now = model.now
        occurredAt = Self.minute(now)
        switch mode {
        case let .new(lureID):
            let active = model.lure(lureID).flatMap { $0.isArchived ? nil : $0 }
            self.lureID = active?.id ?? model.benchLure?.id
            initial = payload
            if let draft = model.drafts.filter({ $0.kind == .test }).max(by: { $0.updatedAt < $1.updatedAt }),
               let saved = try? JSONDecoder().decode(TestDraftPayload.self, from: draft.payload), !saved.isEditing,
               model.test(draft.id) == nil {
                id = draft.id
                apply(saved, model: model)
                // A lure chosen explicitly (e.g. from Lure Detail) wins over the draft's lure.
                if let explicit = active?.id { self.lureID = explicit }
                if self.lureID == nil { self.lureID = model.benchLure?.id }
                restoredFromDraft = true
            }
        case let .edit(testID):
            isEditing = true
            if let test = model.test(testID) {
                id = test.id
                lureID = test.lureID
                placeName = test.placeName
                occurredAt = test.occurredAt
                durationText = String(test.durationMinutes)
                bites = test.bites
                catches = test.catches
                waterType = test.waterType
                clarity = test.clarity
                retrieve = test.retrieve
                weatherNote = test.weatherNote
                notes = test.notes
            }
            initial = payload
            if let draft = model.drafts.first(where: { $0.id == testID && $0.kind == .test }),
               let saved = try? JSONDecoder().decode(TestDraftPayload.self, from: draft.payload), saved.isEditing {
                apply(saved, model: model)
                restoredFromDraft = true
            }
        case let .repeatTest(testID):
            if let source = model.test(testID) {
                let lure = model.lure(source.lureID)
                lureID = (lure?.isArchived ?? true) ? nil : lure?.id
                placeName = source.placeName
            }
            // An untouched repeat can be left without the "Keep this draft?" prompt.
            initial = payload
        }
    }

    private func apply(_ saved: TestDraftPayload, model: AppModel) {
        if let savedLure = saved.lureID, let lure = model.lure(savedLure), !lure.isArchived || isEditing {
            lureID = savedLure
        }
        placeName = saved.placeName
        occurredAt = min(saved.occurredAt, model.now)
        durationText = saved.durationText
        bites = saved.bites
        catches = saved.catches
        waterType = saved.waterType
        clarity = saved.clarity
        retrieve = saved.retrieve
        weatherNote = saved.weatherNote
        notes = saved.notes
    }

    static func minute(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date
    }

    func issue(_ field: FormField) -> String? { issues.first { $0.field == field }?.message }

    func validate(model: AppModel) -> ValidatedTestFields? {
        let input = TestInput(lure: model.lure(lureID), placeName: placeName, occurredAt: occurredAt, durationText: durationText,
                              bites: bites, catches: catches, waterType: waterType, clarity: clarity, retrieve: retrieve,
                              weatherNote: weatherNote, notes: notes)
        let result = TestValidator.validate(input, now: model.now)
        issues = result.issues
        return result.value
    }

    /// Re-checks catches ≤ bites live once the user has seen errors.
    func revalidateCounts() {
        guard !issues.isEmpty else { return }
        issues.removeAll { $0.field == .catches || $0.field == .bites }
        if let bites, let catches, catches > bites {
            issues.append(ValidationIssue(field: .catches, message: TestValidator.catchesMessage))
        }
    }

    func draft(now: Date) -> Draft? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return Draft(id: id, kind: .test, payload: data, updatedAt: now)
    }
}
