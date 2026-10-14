import SwiftUI
import UIKit

@main
struct LureLabApp: App {
    @StateObject private var bootstrap = AppBootstrap()

    init() {
        UIScrollView.appearance().keyboardDismissMode = .interactive
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap.state {
            case let .ready(model):
                AppShell()
                    .environmentObject(model)
                    .environmentObject(model.photos)
            case let .failed(message):
                StartupErrorView(message: message) { bootstrap.start() }
            }
        }
    }
}

/// Composition root: wires Data implementations into Domain use cases.
@MainActor
final class AppBootstrap: ObservableObject {
    enum State {
        case ready(AppModel)
        case failed(String)
    }

    @Published private(set) var state: State = .failed("")

    init() {
        start()
    }

    func start() {
        do {
            let rules = WorkshopRules.load()
            #if DEBUG
            if let debugModel = try DebugScenario.makeModel(rules: rules) {
                state = .ready(debugModel)
                return
            }
            #endif
            let stack = try CoreDataStack(store: .onDisk(CoreDataStack.defaultStoreURL()))
            let store = CoreDataStore(stack: stack, rules: rules)
            let photos = FilePhotoStore()
            let clock = SystemClock()
            let backup = BackupService(snapshots: store, workshop: store, photos: photos, rules: rules, clock: clock)
            let model = AppModel(rules: rules, photoStore: photos, lures: store, tests: store, workshop: store,
                                 drafts: store, settings: store, backup: backup, clock: clock)
            state = .ready(model)
        } catch {
            state = .failed("Your journal could not be opened. Restart the app or free some storage, then try again.")
        }
    }
}

struct StartupErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            UIIcon(name: "icon_warning", size: 42)
            Text("Lure Lab")
                .font(.avenir(26, .heavy))
                .foregroundColor(Palette.ink)
            Text(message)
                .font(.avenir(16, .medium))
                .foregroundColor(Palette.secondary)
                .multilineTextAlignment(.center)
            GoldButton(title: "Try Again", action: retry)
        }
        .padding(Metrics.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}
