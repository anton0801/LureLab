import SwiftUI

enum TestEditorMode: Hashable {
    case new(lureID: UUID?)
    case edit(UUID)
    case repeatTest(UUID)
}

struct TestSavedSummary: Hashable {
    let testID: UUID
    let capsule: CapsuleOutcome
}

extension CapsuleOutcome: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .earned: hasher.combine(0)
        case let .notEligible(date): hasher.combine(1); hasher.combine(date)
        case .shelfFull: hasher.combine(2)
        case .notApplicable: hasher.combine(3)
        }
    }
}

/// Every pushed destination. Each tab keeps its own stack of these.
enum Route: Hashable {
    case journal(TestFilter)
    case settings
    case lureDetail(UUID)
    case lureEditor(UUID?)
    case testEditor(TestEditorMode)
    case testDetail(UUID)
    case testSaved(TestSavedSummary)
    case luckyCast
    case showcase
    case collectible(String)
    case workshopGuide
    case rewardDetails
    case data
    case importPreview
    case archived
    case units
    case about

    /// Forms handle their own back (unsaved-changes dialog), so edge swipe is off there.
    var allowsSwipeBack: Bool {
        switch self {
        case .lureEditor, .testEditor, .testSaved, .importPreview: return false
        default: return true
        }
    }
}

final class Router: ObservableObject {
    struct Entry: Identifiable, Equatable {
        let id = UUID()
        let route: Route
    }

    @Published private(set) var stack: [Entry] = []

    var isAtRoot: Bool { stack.isEmpty }

    func push(_ route: Route) { stack.append(Entry(route: route)) }

    func pop() {
        guard !stack.isEmpty else { return }
        stack.removeLast()
    }

    func popToRoot() { stack.removeAll() }

    /// Replaces the top screen (e.g. form → "Test Saved") so Back never returns to a submitted form.
    func replaceTop(with route: Route) {
        if stack.isEmpty {
            push(route)
        } else {
            stack[stack.count - 1] = Entry(route: route)
        }
    }

    /// Pops back to an existing screen matching `predicate`; returns false when none is in the stack.
    @discardableResult
    func popTo(where predicate: (Route) -> Bool) -> Bool {
        guard let index = stack.lastIndex(where: { predicate($0.route) }) else { return false }
        stack.removeSubrange((index + 1)...)
        return true
    }

    func setStack(_ routes: [Route]) {
        stack = routes.map { Entry(route: $0) }
    }
}

/// Owns the four tab stacks and cross-tab jumps.
final class AppCoordinator: ObservableObject {
    @Published var tab: AppTab = .journal
    let journal = Router()
    let lures = Router()
    let compare = Router()
    let workshop = Router()

    func router(for tab: AppTab) -> Router {
        switch tab {
        case .journal: return journal
        case .lures: return lures
        case .compare: return compare
        case .workshop: return workshop
        }
    }

    /// Switches tab and replaces that tab's stack.
    func open(_ tab: AppTab, stack routes: [Route]) {
        router(for: tab).setStack(routes)
        self.tab = tab
    }

    func resetAll() {
        AppTab.allCases.forEach { router(for: $0).popToRoot() }
        tab = .journal
    }
}

/// Renders a tab root with its pushed screens stacked above it. Lower screens stay alive,
/// so forms keep their state while a picker or sub-form is on top.
struct StackHost<Root: View>: View {
    @ObservedObject var router: Router
    let root: Root
    @Environment(\.lureReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            root
                .zIndex(0)
                .allowsHitTesting(router.isAtRoot)
                .accessibilityHidden(!router.isAtRoot)
            ForEach(Array(router.stack.enumerated()), id: \.element.id) { index, entry in
                let isTop = index == router.stack.count - 1
                SwipeBackContainer(enabled: isTop && entry.route.allowsSwipeBack, onBack: { router.pop() }) {
                    RouteDestination(route: entry.route)
                }
                .zIndex(Double(index + 1))
                .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                .allowsHitTesting(isTop)
                .accessibilityHidden(!isTop)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.3), value: router.stack.map(\.id))
    }
}

/// Interactive edge-swipe back for pushed screens.
struct SwipeBackContainer<Content: View>: View {
    let enabled: Bool
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var offset: CGFloat = 0
    @Environment(\.lureReduceMotion) private var reduceMotion

    var body: some View {
        content()
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .global)
                    .onChanged { value in
                        guard enabled, value.startLocation.x < 24, value.translation.width > 0 else { return }
                        offset = reduceMotion ? 0 : value.translation.width
                    }
                    .onEnded { value in
                        guard enabled, value.startLocation.x < 24 else { offset = 0; return }
                        if value.translation.width > 90 || value.predictedEndTranslation.width > 200 {
                            onBack()
                        }
                        withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                    }
            )
    }
}
