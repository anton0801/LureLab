import SwiftUI
import UIKit

/// Four tabs, each with its own navigation stack, plus the onboarding overlay.
struct AppShell: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var replayOnboarding = false
    /// Window insets without the keyboard (the tab bar must not grow when a field is focused).
    @State private var windowInsets = EdgeInsets(top: Metrics.mockupSafeTop, leading: 0, bottom: Metrics.mockupSafeBottom, trailing: 0)

    private var reduceMotion: Bool { systemReduceMotion || model.settings.reduceMotion }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == coordinator.tab
                StackHost(router: coordinator.router(for: tab), root: TabRoot(tab: tab))
                    .environmentObject(coordinator.router(for: tab))
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(isSelected)
                    .accessibilityHidden(!isSelected)
                    .zIndex(isSelected ? 1 : 0)
            }
            if !model.settings.onboardingCompleted || replayOnboarding {
                OnboardingView {
                    model.updateSettings { $0.onboardingCompleted = true }
                    coordinator.resetAll()
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { replayOnboarding = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .onAppear { windowInsets = WindowMetrics.safeAreaInsets() ?? windowInsets }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            windowInsets = WindowMetrics.safeAreaInsets() ?? windowInsets
        }
        .modifier(KeyboardDoneBar())
        .environment(\.windowSafeArea, windowInsets)
        .environmentObject(coordinator)
        .environment(\.lureReduceMotion, reduceMotion)
        .environment(\.haptics, HapticsClient(isEnabled: model.settings.hapticsEnabled))
        .onReceive(NotificationCenter.default.publisher(for: .replayOnboarding)) { _ in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { replayOnboarding = true }
        }
        .onAppear {
            #if DEBUG
            if let scenario = DebugScenario.name {
                if scenario == "31", let url = try? model.backup.exportBackup() {
                    model.preparedImport = try? model.backup.prepareImport(from: url)
                    coordinator.open(.journal, stack: [.settings, .data, .importPreview])
                    return
                }
                let target = DebugScenario.navigation(for: scenario)
                coordinator.open(target.0, stack: target.1)
            }
            #endif
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                model.recordClock()
                model.reload()
            }
        }
    }
}

/// One "Done" bar above the keyboard for the whole app (number pads have no return key).
/// iOS 16+: SwiftUI keyboard toolbar. iOS 15 (which shows it only inside a NavigationView): a UIKit input accessory.
struct KeyboardDoneBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { Keyboard.dismiss() }
                        .font(.avenir(17, .bold))
                        .foregroundColor(Palette.sea)
                }
            }
        } else {
            content.onAppear { LegacyKeyboardAccessory.install() }
        }
    }
}

enum LegacyKeyboardAccessory {
    private static var observers: [NSObjectProtocol] = []

    static func install() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { note in
            guard let field = note.object as? UITextField, field.inputAccessoryView == nil else { return }
            field.inputAccessoryView = makeBar(target: field)
            field.reloadInputViews()
        })
        observers.append(center.addObserver(forName: UITextView.textDidBeginEditingNotification, object: nil, queue: .main) { note in
            guard let view = note.object as? UITextView, view.inputAccessoryView == nil else { return }
            view.inputAccessoryView = makeBar(target: view)
            view.reloadInputViews()
        })
    }

    private static func makeBar(target: UIResponder) -> UIToolbar {
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let done = UIBarButtonItem(title: "Done", style: .done, target: target, action: #selector(UIResponder.resignFirstResponder))
        done.tintColor = UIColor(red: 0, green: 0x8D / 255.0, blue: 0xCE / 255.0, alpha: 1)
        bar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done]
        bar.sizeToFit()
        return bar
    }
}

/// The key window's safe area (status bar / home indicator). Unlike SwiftUI insets it never includes the keyboard.
enum WindowMetrics {
    static func safeAreaInsets() -> EdgeInsets? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first
        guard let insets = window?.safeAreaInsets else { return nil }
        return EdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)
    }
}

extension Notification.Name {
    static let replayOnboarding = Notification.Name("LureLab.replayOnboarding")
}

/// Root screen of a tab, with the tab bar drawn on top (pushed screens cover it).
struct TabRoot: View {
    let tab: AppTab
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.windowSafeArea) private var safeArea
    @State private var coveredBySubscreen = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .journal: HomeView()
                case .lures: LuresView()
                case .compare: CompareView()
                case .workshop: WorkshopView()
                }
            }
            .onPreferenceChange(HidesTabBarKey.self) { coveredBySubscreen = $0 }
            if !coveredBySubscreen {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LureTabBar(selected: coordinator.tab) { selected in
                        if selected == coordinator.tab {
                            coordinator.router(for: selected).popToRoot()
                        } else {
                            coordinator.tab = selected
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .ignoresSafeArea(.keyboard)
            }
        }
    }
}

/// Set by a tab root while a local push (e.g. Choose Lure in Compare) covers it, like a pushed screen.
struct HidesTabBarKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// Bottom padding for scroll content on tab roots so the last card clears the tab bar.
struct TabBarClearance: View {
    @Environment(\.windowSafeArea) private var safeArea
    var extra: CGFloat = 14

    var body: some View {
        Color.clear.frame(height: LureTabBar.height(safeBottom: safeArea.bottom) - safeArea.bottom + extra)
    }
}

/// Resolves a route to its screen.
struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case let .journal(filter): JournalView(initialFilter: filter)
        case .settings: SettingsView()
        case let .lureDetail(id): LureDetailView(lureID: id)
        case let .lureEditor(id): LureEditorScreen(lureID: id)
        case let .testEditor(mode): TestEditorScreen(mode: mode)
        case let .testDetail(id): TestDetailView(testID: id)
        case let .testSaved(summary): TestSavedView(summary: summary)
        case .luckyCast: LuckyCastView()
        case .showcase: ShowcaseView()
        case let .collectible(id): CollectibleDetailView(collectibleID: id)
        case .workshopGuide: WorkshopGuideView()
        case .rewardDetails: RewardDetailsView()
        case .data: DataBackupView()
        case .importPreview: ImportPreviewView()
        case .archived: ArchivedLuresView()
        case .units: UnitsView()
        case .about: AboutView()
        }
    }
}
