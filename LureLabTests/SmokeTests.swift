import XCTest
@testable import LureLab

final class SmokeTests: XCTestCase {
    func testRulesLoadFromBundle() {
        let rules = WorkshopRules.load(bundle: Bundle(for: AppBootstrap.self))
        XCTAssertEqual(rules, WorkshopRules.fallback)
    }
}
