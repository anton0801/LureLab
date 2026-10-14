import XCTest
@testable import LureLab

final class RateCalculatorTests: XCTestCase {
    private func test(minutes: Int, bites: Int?, catches: Int?) -> TestEntry {
        TestEntry(id: UUID(), lureID: UUID(), lureNameSnapshot: "L", lureTypeSnapshot: .minnow, placeName: "P",
                  occurredAt: Date(), durationMinutes: minutes, bites: bites, catches: catches, waterType: nil, clarity: nil,
                  retrieve: nil, weatherNote: "", notes: "", createdAt: Date(), updatedAt: Date())
    }

    func testRateIsNotRecordedWhenNoTestHasTheCount() {
        let summary = RateCalculator.summarize([test(minutes: 60, bites: nil, catches: nil)], metric: .catches)
        XCTAssertNil(summary.ratePerHour, "nil counts must stay Not recorded, never 0")
        XCTAssertEqual(summary.includedTests, 0)
        XCTAssertEqual(summary.totalMinutes, 0)
    }

    func testZeroIsARealMeasuredRate() {
        let summary = RateCalculator.summarize([test(minutes: 30, bites: 0, catches: 0)], metric: .catches)
        XCTAssertEqual(summary.ratePerHour, 0)
        XCTAssertEqual(summary.includedTests, 1)
    }

    func testRateUsesSumOverSumOnlyForRecordedTests() {
        // 2 catches in 45 min + 0 in 30 min + unknown in 60 min → 2 / 75 min × 60.
        let tests = [test(minutes: 45, bites: 6, catches: 2), test(minutes: 30, bites: 0, catches: 0), test(minutes: 60, bites: nil, catches: nil)]
        let catches = RateCalculator.summarize(tests, metric: .catches)
        XCTAssertEqual(catches.includedTests, 2)
        XCTAssertEqual(catches.totalMinutes, 75)
        XCTAssertEqual(catches.ratePerHour!, 1.6, accuracy: 1e-9)
        // Not the mean of individual rates (which would be (2.667 + 0) / 2 = 1.333).
        XCTAssertNotEqual(catches.ratePerHour!, (60.0 * 2 / 45 + 0) / 2, accuracy: 1e-6)
    }

    func testFilterAppliesPeriodLureConditionsAndMetric() {
        let lure = UUID()
        var recent = test(minutes: 30, bites: 1, catches: nil)
        recent = TestEntry(id: recent.id, lureID: lure, lureNameSnapshot: "L", lureTypeSnapshot: .minnow, placeName: "Pier",
                           occurredAt: Date().addingTimeInterval(-86_400), durationMinutes: 30, bites: 1, catches: nil,
                           waterType: .lake, clarity: nil, retrieve: nil, weatherNote: "", notes: "", createdAt: Date(), updatedAt: Date())
        var filter = TestFilter(period: .last7, lureIDs: [lure], waterType: .lake)
        XCTAssertEqual(filter.apply(to: [recent]).count, 1)
        filter.requiredMetric = .catches
        XCTAssertEqual(filter.apply(to: [recent]).count, 0)
        filter.requiredMetric = .bites
        filter.waterType = .river
        XCTAssertEqual(filter.apply(to: [recent]).count, 0)
    }
}

final class CastEngineTests: XCTestCase {
    let engine = CastEngine(rules: .fallback)

    func testFullTableOf7776RowsMatchesPublishedOdds() {
        let distribution = engine.exhaustiveDistribution()
        XCTAssertEqual(distribution.values.reduce(0, +), 7776)
        XCTAssertEqual(distribution[1], 7200)
        XCTAssertEqual(distribution[2], 570)
        XCTAssertEqual(distribution[3], 6)
        XCTAssertEqual(distribution.mapKeys(String.init), WorkshopRules.fallback.rewardCountsOver7776)
    }

    func testOnlyMiddleRowIsEvaluated() {
        let matrix: [[CastSymbol]] = [
            [.s01, .s01, .s01, .s01, .s01],
            [.s01, .s02, .s03, .s04, .s05],
            [.s06, .s06, .s06, .s06, .s06]
        ]
        XCTAssertEqual(engine.evaluate(matrix: matrix).parts, 1)
    }

    func testRunLengths() {
        XCTAssertEqual(engine.evaluate(row: [.s06, .s06, .s06, .s01, .s02]).parts, 2)
        XCTAssertEqual(engine.evaluate(row: [.s01, .s06, .s06, .s06, .s06]).parts, 2)
        XCTAssertEqual(engine.evaluate(row: [.s04, .s04, .s04, .s04, .s04]).parts, 3)
        XCTAssertEqual(engine.evaluate(row: [.s01, .s01, .s02, .s02, .s01]).parts, 1)
        let evaluation = engine.evaluate(row: [.s02, .s03, .s03, .s03, .s01])
        XCTAssertEqual(evaluation.highlightedColumns, 1..<4)
        XCTAssertEqual(engine.evaluate(row: [.s01, .s02, .s01, .s02, .s01]).highlightedColumns, 0..<0)
    }

    func testSpinProducesFiveByThreeOfKnownSymbols() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let matrix = engine.spin(using: &generator)
            XCTAssertEqual(matrix.count, 3)
            XCTAssertTrue(matrix.allSatisfy { $0.count == 5 })
        }
    }

    func testBundledRulesMatchDesignPackage() {
        let rules = WorkshopRules.load(bundle: Bundle(for: AppBootstrap.self))
        XCTAssertEqual(rules, WorkshopRules.fallback)
        XCTAssertEqual(rules.collectibles.map(\.name), ["Coral Comet", "Emerald Drift", "Midnight Fin", "Sunrise Spinner"])
    }
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}

final class CapsulePolicyTests: XCTestCase {
    let policy = CapsulePolicy(rules: .fallback)
    let now = Date(timeIntervalSince1970: 1_791_000_000)

    func testFirstTestGrantsAndStartsCooldown() {
        var state = WorkshopState()
        let decision = policy.evaluate(state: state, now: now)
        XCTAssertEqual(decision, .grant(nextEligibleAt: now.addingTimeInterval(86_400)))
        XCTAssertTrue(policy.apply(decision, to: &state, now: now))
        XCTAssertEqual(state.capsules, 1)
    }

    func testCooldownBlocksUntilNextEligible() {
        let state = WorkshopState(capsules: 1, parts: 0, nextEligibleAt: now.addingTimeInterval(100), lastSeenAt: now)
        XCTAssertEqual(policy.evaluate(state: state, now: now), .coolingDown(until: now.addingTimeInterval(100)))
        XCTAssertEqual(policy.evaluate(state: state, now: now.addingTimeInterval(100)), .grant(nextEligibleAt: now.addingTimeInterval(100 + 86_400)))
    }

    func testBalanceCapDoesNotAccrueOrExtendTimer() {
        var state = WorkshopState(capsules: 7, parts: 0, nextEligibleAt: now.addingTimeInterval(-10), lastSeenAt: now)
        let decision = policy.evaluate(state: state, now: now)
        XCTAssertEqual(decision, .capped)
        XCTAssertFalse(policy.apply(decision, to: &state, now: now))
        XCTAssertEqual(state.capsules, 7)
        XCTAssertEqual(state.nextEligibleAt, now.addingTimeInterval(-10))
    }

    func testClockRollbackKeepsCooldown() {
        let state = WorkshopState(capsules: 0, parts: 0, nextEligibleAt: now.addingTimeInterval(3600), lastSeenAt: now)
        let earlier = now.addingTimeInterval(-7200)
        XCTAssertEqual(policy.evaluate(state: state, now: earlier), .clockRolledBack(until: now.addingTimeInterval(3600)))
    }
}

final class ValidationTests: XCTestCase {
    private func lureInput(length: String = "", weight: String = "", units: UnitSystem = .metric, name: String = "Minnow A") -> LureInput {
        LureInput(name: name, type: .minnow, length: MeasurementInput(text: length), weight: MeasurementInput(text: weight),
                  color: "", brand: "", notes: "", units: units)
    }

    func testEmptyMeasurementsStayUnknown() {
        let value = LureValidator.validate(lureInput()).value
        XCTAssertNotNil(value)
        XCTAssertNil(value?.lengthCm)
        XCTAssertNil(value?.weightG)
    }

    func testMeasurementRanges() {
        XCTAssertNotNil(LureValidator.validate(lureInput(length: "0.1", weight: "10000")).value)
        XCTAssertEqual(LureValidator.validate(lureInput(length: "0")).issues.first?.field, .length)
        XCTAssertEqual(LureValidator.validate(lureInput(weight: "10000.5")).issues.first?.field, .weight)
        XCTAssertEqual(LureValidator.validate(lureInput(length: "abc")).issues.first?.field, .length)
        XCTAssertEqual(LureValidator.validate(lureInput(name: "  ")).issues.first?.field, .name)
        XCTAssertEqual(LureValidator.validate(lureInput(name: String(repeating: "x", count: 81))).issues.first?.field, .name)
    }

    func testImperialInputConvertsWithoutRoundingDrift() {
        let value = LureValidator.validate(lureInput(length: "3.5", weight: "1", units: .imperial)).value
        XCTAssertEqual(value?.lengthCm, Decimal(string: "8.89"))
        XCTAssertEqual(value?.weightG, Decimal(string: "28.349523125"))
        // Untouched field keeps the stored canonical value exactly.
        var input = lureInput(units: .imperial)
        input.length = MeasurementInput(text: "3.54", initialText: "3.54", initialCanonical: 9)
        XCTAssertEqual(LureValidator.validate(input).value?.lengthCm, 9)
    }

    private func testInput(lure: Lure?, duration: String = "45", bites: Int? = nil, catches: Int? = nil, date: Date = Date()) -> TestInput {
        TestInput(lure: lure, placeName: "North Pier", occurredAt: date, durationText: duration, bites: bites, catches: catches,
                  waterType: nil, clarity: nil, retrieve: nil, weatherNote: "", notes: "")
    }

    func testTestValidation() {
        let lure = Lure(id: UUID(), name: "A", type: .minnow, lengthCm: nil, weightG: nil, color: nil, brand: nil, notes: "",
                        photoPath: nil, createdAt: Date(), updatedAt: Date(), archivedAt: nil)
        let now = Date()
        XCTAssertNotNil(TestValidator.validate(testInput(lure: lure), now: now).value)
        XCTAssertEqual(TestValidator.validate(testInput(lure: nil), now: now).issues.first?.field, .lure)
        XCTAssertEqual(TestValidator.validate(testInput(lure: lure, duration: ""), now: now).issues.first?.message, TestValidator.durationMessage)
        XCTAssertEqual(TestValidator.validate(testInput(lure: lure, duration: "1441"), now: now).issues.first?.field, .duration)
        XCTAssertEqual(TestValidator.validate(testInput(lure: lure, bites: 6, catches: 8), now: now).issues.first?.message, TestValidator.catchesMessage)
        XCTAssertNotNil(TestValidator.validate(testInput(lure: lure, bites: nil, catches: 8), now: now).value, "unknown bites never limit catches")
        XCTAssertNotNil(TestValidator.validate(testInput(lure: lure, bites: 0, catches: 0), now: now).value, "zero catch is valid")
        XCTAssertEqual(TestValidator.validate(testInput(lure: lure, date: now.addingTimeInterval(3600)), now: now).issues.first?.field, .date)
    }

    func testStepperFromUnknown() {
        XCTAssertEqual(CountStepper.increment(nil), 1)
        XCTAssertEqual(CountStepper.decrement(nil), 0)
        XCTAssertEqual(CountStepper.decrement(0), 0)
        XCTAssertEqual(CountStepper.increment(9999), 9999)
    }
}

final class CSVTests: XCTestCase {
    func testEscapingAndFormulaNeutralization() {
        XCTAssertEqual(CSVExporter.escape(userText: "=SUM(A1)"), "'=SUM(A1)")
        XCTAssertEqual(CSVExporter.escape(userText: "-5"), "'-5")
        XCTAssertEqual(CSVExporter.escape(userText: "a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExporter.escape(userText: "say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExporter.escape(userText: "line\nbreak"), "\"line\nbreak\"")
    }

    func testMissingCountsAreEmptyNotZero() {
        let test = TestEntry(id: UUID(), lureID: UUID(), lureNameSnapshot: "L", lureTypeSnapshot: .minnow, placeName: "P",
                             occurredAt: Date(timeIntervalSince1970: 0), durationMinutes: 30, bites: nil, catches: 0, waterType: nil,
                             clarity: nil, retrieve: nil, weatherNote: "", notes: "", createdAt: Date(), updatedAt: Date())
        let csv = CSVExporter.csv(tests: [test], lures: [])
        let row = csv.components(separatedBy: "\r\n")[1].components(separatedBy: ",")
        XCTAssertEqual(row[6], "30")
        XCTAssertEqual(row[7], "")
        XCTAssertEqual(row[8], "0")
        XCTAssertEqual(row[1], "1970-01-01T00:00:00Z")
    }
}
